import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:palito_3_0/core/utils/app_log.dart';

import 'auth_service.dart';
import 'household_service.dart';

/// ===========================================================================
/// ACCOUNT DELETION SERVICE
/// ===========================================================================
///
/// Cumple el requisito de Apple (App Store Guideline 5.1.1(v)): toda cuenta
/// creada dentro de la app debe poder eliminarse desde dentro de la app.
///
/// ORDEN DE OPERACIONES — la versión anterior borraba primero los datos y
/// reautenticaba después, solo si Firebase lo exigía. Eso abría un agujero
/// real: si el usuario cancelaba la hoja de Apple en ese segundo paso, sus
/// recuerdos y sus grupos ya estaban borrados y la cuenta seguía viva; al
/// reabrir la app se le creaba un perfil nuevo y vacío, y el mensaje que
/// había visto era "no se pudo eliminar la cuenta".
///
/// Ahora se reautentica SIEMPRE al principio. Si el usuario cancela, no se ha
/// tocado nada. El orden es:
///   1. Reautenticar con el proveedor con el que esta cuenta entra de verdad
///      —Apple o Google—, y si es Apple quedarse el authorizationCode.
///   2. Salir de todos los grupos / borrarlos si se es el último miembro.
///   3. Borrar `users/{uid}`.
///   4. Revocar el token de Apple  ← exigido por Apple desde junio de 2022
///      para las apps que usan Sign in with Apple.
///   5. Borrar la cuenta de Firebase Auth.
///
/// Los pasos 2 y 3 dependen de que `request.auth.uid` siga existiendo (ver
/// `firestore.rules`), así que tienen que ir antes del 5.
/// ===========================================================================

class AccountDeletionService {
  AccountDeletionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _authService = authService ?? AuthService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuthService _authService;

  /// Elimina por completo la cuenta del usuario actual.
  ///
  /// Lanza [AccountDeletionCancelled] si el usuario cancela la hoja de Apple o
  /// cierra la ventana de Google — en ese caso NO se ha borrado nada y la
  /// pantalla debe decirlo así, no mostrar un error.
  Future<void> deleteAccount() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    final String uid = user.uid;

    // ----- 1. Reautenticación (antes de tocar ningún dato) -----
    //
    // ══ CON QUÉ PROVEEDOR ══
    //
    // Esto pedía SIEMPRE la hoja de Apple. Mientras la app solo existió en
    // iPhone y solo se entraba con Apple, daba igual. Desde que también se
    // entra con Google, a un usuario de Google le abría una hoja de Apple
    // que no puede resolver —y si tenía Apple ID, Firebase contestaba
    // `user-mismatch` porque la credencial es de OTRA cuenta—. Traducido:
    // no podía borrar su cuenta. Poder borrarla es requisito explícito de
    // las dos tiendas (Apple 5.1.1(v), Play "eliminación de cuenta"), así
    // que esto no era un detalle: era un motivo de rechazo.
    //
    // Se mira con qué ha entrado de verdad —`providerData`—, no en qué
    // sistema operativo está: alguien que se hizo la cuenta con Apple en el
    // iPhone y ahora usa un Android sigue teniendo que reautenticar con
    // Apple, porque es lo que Firebase le va a pedir.
    final Set<String> proveedores = <String>{
      for (final UserInfo info in user.providerData) info.providerId,
    };

    // `authorizationCode` no es nulable en el credential de Apple; la
    // cadena vacía es el único caso a comprobar. Solo se rellena si se ha
    // reautenticado con Apple, porque solo entonces hay token que revocar.
    String appleAuthorizationCode = '';

    if (proveedores.contains('apple.com')) {
      appleAuthorizationCode = await _reautenticarConApple(user);
    } else if (proveedores.contains('google.com')) {
      await _reautenticarConGoogle(user);
    } else {
      // Ni Apple ni Google. No hay forma de demostrar que la cuenta es suya,
      // así que no se toca nada: `user.delete()` acabaría contestando
      // `requires-recent-login`, pero para entonces los recuerdos ya
      // estarían borrados.
      throw StateError(
        'Esta cuenta no tiene ninguna forma de entrar reconocida.',
      );
    }

    // ----- 2. Salir de todos sus grupos -----
    List<String> groupIds = const <String>[];

    try {
      final DocumentSnapshot<Map<String, dynamic>> userSnap = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      groupIds =
          (userSnap.data()?['groupIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
    } on FirebaseException catch (e) {
      AppLog.w('No se pudo leer la lista de grupos al borrar: ${e.code}');
    }

    final HouseholdService householdService = HouseholdService(
      firestore: _firestore,
    );

    for (final String groupId in groupIds) {
      try {
        await householdService.leaveGroup(groupId: groupId, uid: uid);
      } on FirebaseException catch (e) {
        // Un `groupId` obsoleto (grupo ya borrado, o del que ya nos
        // expulsaron) no puede impedir que alguien borre su cuenta: antes,
        // un solo `not-found` abortaba todo el proceso para siempre, lo que
        // incumple directamente la 5.1.1(v).
        if (e.code != 'not-found' && e.code != 'permission-denied') {
          AppLog.w('Grupo no limpiado al borrar la cuenta: ${e.code}');
        }
      }
    }

    // ----- 3. Borrar el documento del usuario -----
    try {
      await _firestore.collection('users').doc(uid).delete();
    } on FirebaseException catch (e) {
      AppLog.w('No se pudo borrar el documento de usuario: ${e.code}');
    }

    // ----- 4. Revocar el token de Apple -----
    // Sin esto, la app sigue apareciendo en Ajustes → Apple ID → "Inicio de
    // sesión con Apple" después de haber borrado la cuenta, y es motivo
    // documentado de rechazo en revisión.
    if (appleAuthorizationCode.isNotEmpty) {
      try {
        await _auth.revokeTokenWithAuthorizationCode(appleAuthorizationCode);
      } catch (_) {
        // Que falle la revocación no debe dejar la cuenta a medio borrar.
        AppLog.w('No se pudo revocar el token de Apple.');
      }
    }

    // ----- 5. Borrar la cuenta de Auth -----
    await user.delete();

    // Cerrar también la sesión de Google en el móvil. Si no, el sistema se
    // queda con la cuenta elegida y el siguiente toque en «Continuar con
    // Google» crea una cuenta nueva sin preguntar nada: la persona acaba de
    // borrar la suya y se encuentra dentro otra vez, lo que parece que el
    // borrado no ha funcionado.
    if (proveedores.contains('google.com')) {
      try {
        await _authService.cerrarSesionDeGoogle();
      } catch (_) {
        AppLog.w('No se pudo cerrar la sesión de Google tras borrar.');
      }
    }

    AppLog.i('AccountDeletionService: cuenta eliminada.');
  }

  /// Reautentica con Apple y devuelve su `authorizationCode`, que hace falta
  /// más adelante para revocar el token (paso 4).
  Future<String> _reautenticarConApple(User user) async {
    try {
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
            scopes: const <AppleIDAuthorizationScopes>[
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );

      await user.reauthenticateWithCredential(
        OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        ),
      );

      return appleCredential.authorizationCode;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AccountDeletionCancelled();
      }
      rethrow;
    }
  }

  Future<void> _reautenticarConGoogle(User user) async {
    final AuthCredential? credencial = await _authService.credencialDeGoogle();

    // `null` significa que cerró la ventana de Google sin elegir cuenta.
    // Exactamente igual que cancelar la hoja de Apple: no se ha tocado nada.
    if (credencial == null) {
      throw const AccountDeletionCancelled();
    }

    await user.reauthenticateWithCredential(credencial);
  }
}

/// El usuario cerró la hoja de Sign in with Apple durante el borrado. No se ha
/// borrado nada.
class AccountDeletionCancelled implements Exception {
  const AccountDeletionCancelled();

  @override
  String toString() => 'AccountDeletionCancelled';
}
