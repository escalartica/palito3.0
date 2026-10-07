import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:palito_3_0/core/utils/app_log.dart';

import 'household_service.dart';

/// ===========================================================================
/// AUTH SERVICE
/// ===========================================================================
///
/// Encapsula el único método de inicio de sesión de la app: Sign in with
/// Apple. Al iniciar sesión por primera vez, crea el documento `users/{uid}`
/// del usuario Y su grupo personal (su diario privado — ver
/// `HouseholdService`), así nadie se queda nunca sin ningún grupo y no hace
/// falta ninguna pantalla de configuración obligatoria antes de poder usar la
/// app.
///
/// SOBRE EL NOMBRE — Apple solo entrega `givenName`/`familyName` la PRIMERA
/// vez que un Apple ID autoriza esta app. En cualquier reinstalación o
/// re-login llegan a `null`. La versión anterior caía entonces al prefijo del
/// correo, lo que con "Ocultar mi correo" producía nombres como
/// `gdvcgp2gdt`, sin forma de arreglarlos desde la app.
///
/// Ahora el nombre es un dato NUESTRO, no de Apple: si Apple no lo da, se
/// deja `displayName` a `null` y la app pide el nombre al usuario
/// (`needsDisplayName`). Nunca se deriva del correo.
/// ===========================================================================

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  /// Nombre que se muestra cuando todavía no hay uno de verdad. Una sola
  /// constante: antes convivían 'Miembro', 'Yo', 'Usuario' y 'Team' según la
  /// pantalla, y la misma persona aparecía con nombres distintos.
  static const String unnamedMember = 'Sin nombre';

  /// Inicia sesión con Apple, creando el usuario de Firebase Auth si es la
  /// primera vez, y asegura que exista su documento `users/{uid}`.
  Future<User?> signInWithApple() async {
    final AuthorizationCredentialAppleID appleCredential =
        await SignInWithApple.getAppleIDCredential(
          scopes: const <AppleIDAuthorizationScopes>[
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

    final OAuthCredential oauthCredential = OAuthProvider('apple.com')
        .credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );

    final UserCredential userCredential = await _auth.signInWithCredential(
      oauthCredential,
    );

    final User? user = userCredential.user;

    if (user == null) {
      return null;
    }

    final String nameFromApple =
        <String?>[appleCredential.givenName, appleCredential.familyName]
            .where((String? part) => part != null && part.trim().isNotEmpty)
            .join(' ')
            .trim();

    await ensureUserDocument(
      user.uid,
      // `null` si Apple no lo ha dado: es preferible preguntar al usuario a
      // inventarle un nombre a partir de su correo.
      nameFromProvider: nameFromApple.isNotEmpty ? nameFromApple : null,
    );

    return user;
  }

  // ══ EL IDENTIFICADOR DEL CLIENTE WEB ══
  //
  // `google_sign_in` necesita saber para quién emite el token, y Firebase
  // solo acepta tokens emitidos para el cliente WEB del proyecto —no para el
  // de Android—. Es el contrasentido que hace perder una tarde: el código
  // parece correcto, la ventana de Google se abre, eliges tu cuenta, y
  // Firebase rechaza el token sin más explicación.
  //
  // Sale de `android/app/google-services.json`, del `oauth_client` con
  // `client_type: 3`. No es un secreto: viaja dentro de la app y Google lo
  // trata como público; lo que protege la cuenta es la huella SHA-1
  // registrada en Firebase, no esta cadena.
  static const String _clienteWeb =
      '911590606586-rve1ffovi3s3i1vpo75i99fbhbmgshsb.apps.googleusercontent.com';

  static bool _googleListo = false;

  /// `initialize()` de `google_sign_in` 7 solo puede llamarse una vez por
  /// arranque, pero puede llamarse tarde. Se hace aquí, perezosamente, en vez
  /// de en `main()`: así quien nunca toque el botón de Google no paga el
  /// coste, y no hay un orden de arranque que respetar.
  static Future<void> _prepararGoogle() async {
    if (_googleListo) return;
    await GoogleSignIn.instance.initialize(serverClientId: _clienteWeb);
    _googleListo = true;
  }

  /// Pide a Google una credencial. Devuelve `null` si la persona cierra la
  /// ventana sin elegir cuenta —que no es un error y no debe pintarse como
  /// tal—.
  ///
  /// Se separa de `signInWithGoogle` porque la misma credencial sirve para
  /// tres cosas distintas: entrar, añadir Google a una cuenta que ya existe, y
  /// demostrar que la cuenta es tuya antes de borrarla
  /// (`AccountDeletionService`).
  Future<AuthCredential?> credencialDeGoogle() async {
    await _prepararGoogle();

    final GoogleSignInAccount cuenta;
    try {
      cuenta = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      // ══ POR QUÉ SE ANOTA SIEMPRE, INCLUSO AL CANCELAR ══
      //
      // En Android esto va por el Gestor de credenciales del sistema, y ahí
      // `canceled` NO significa solo «ha cerrado la ventana»: es también lo
      // que contesta cuando no hay ninguna cuenta de Google en el móvil,
      // cuando la huella SHA-1 de esta compilación no está registrada en
      // Firebase, y cuando el identificador de cliente no cuadra.
      //
      // Tratarlo todo como una cancelación deja la app completamente muda
      // ante tres averías de configuración distintas: la persona toca el
      // botón, se abre algo, se cierra, y no pasa nada ni se dice nada. Pasó
      // el 20/09 en el primer Android y costó encontrarlo justo por esto.
      //
      // Para la persona sigue sin ser un error —cancelar no lo es—, pero
      // queda escrito en el registro con su código y su descripción, que es
      // lo único que distingue una cosa de la otra.
      AppLog.w('Google no ha dado credencial: ${e.code} — ${e.description}');

      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }

    final String? idToken = cuenta.authentication.idToken;
    if (idToken == null) {
      // Sin `idToken` no hay nada que darle a Firebase. Pasa cuando falta la
      // huella SHA-1 en Firebase o el cliente web no es el correcto.
      throw StateError(
        'Google no ha devuelto el token de identidad. Revisa que la huella '
        'SHA-1 de esta compilación esté registrada en Firebase.',
      );
    }

    return GoogleAuthProvider.credential(idToken: idToken);
  }

  /// Inicia sesión con Google. Devuelve `null` si la persona lo cancela.
  ///
  /// Existe sobre todo por Android: la app nació solo con Sign in with Apple,
  /// que en Android funciona pero como una ventana web y pidiendo una cuenta
  /// de Apple que casi nadie tiene ahí.
  Future<User?> signInWithGoogle() async {
    final AuthCredential? credencial = await credencialDeGoogle();
    if (credencial == null) return null;

    final UserCredential userCredential = await _auth.signInWithCredential(
      credencial,
    );

    final User? user = userCredential.user;
    if (user == null) return null;

    await ensureUserDocument(
      user.uid,
      // Google casi siempre da el nombre; si no, se pregunta como con Apple.
      nameFromProvider: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : null,
    );

    return user;
  }

  // ══ ENLAZAR OTRA FORMA DE ENTRAR ══
  //
  // EL PROBLEMA QUE RESUELVEN ESTOS DOS MÉTODOS.
  //
  // Una misma persona con iPhone y Android entraría con Apple en uno y con
  // Google en el otro. Para Firebase son DOS usuarios distintos, cada uno con
  // su `uid` —y en esta app los diarios cuelgan del `uid`—: sus recuerdos, sus
  // grupos y sus puntos no estarían en el otro móvil. Lo viviría como que la
  // app ha perdido sus datos.
  //
  // POR QUÉ NO SE RESUELVE SOLO CON EL CORREO.
  //
  // Firebase trae activado «una cuenta por dirección de correo», así que se
  // podría enlazar cuando el correo coincide. Pero Sign in with Apple ofrece
  // «Ocultar mi correo», y entonces la dirección es una de
  // `privaterelay.appleid.com` que NUNCA va a coincidir con la de Google.
  // Justo la gente más celosa de su privacidad se quedaría con dos cuentas.
  //
  // POR QUÉ ENLAZAR DESDE EL PERFIL SÍ FUNCIONA SIEMPRE.
  //
  // Aquí la sesión ya está iniciada: no hay que adivinar quién eres, lo
  // sabemos. `linkWithCredential` añade el proveedor nuevo a ESE usuario, sin
  // depender de que dos correos se parezcan.

  /// Añade Google a la cuenta con la sesión iniciada.
  ///
  /// Devuelve `false` si la persona cancela. Lanza [FirebaseAuthException] con
  /// `credential-already-in-use` si esa cuenta de Google ya es de otro usuario
  /// de la app —caso real y con datos de por medio, así que lo decide quien
  /// llama, no este servicio—.
  Future<bool> vincularGoogle() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('No hay sesión iniciada.');
    }

    final AuthCredential? credencial = await credencialDeGoogle();
    if (credencial == null) return false;

    await user.linkWithCredential(credencial);
    await user.reload();
    return true;
  }

  /// Añade Apple a la cuenta con la sesión iniciada. El gemelo de
  /// [vincularGoogle], para quien empezó en Android.
  Future<bool> vincularApple() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('No hay sesión iniciada.');
    }

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return false;
      }
      rethrow;
    }

    final OAuthCredential credencial = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    await user.linkWithCredential(credencial);
    await user.reload();
    return true;
  }

  /// Los proveedores con los que esta cuenta puede entrar hoy. La pantalla de
  /// perfil lo usa para no ofrecer añadir algo que ya está puesto.
  Set<String> get proveedoresVinculados => <String>{
    for (final UserInfo info in _auth.currentUser?.providerData ?? const <UserInfo>[])
      info.providerId,
  };

  /// Se asegura de que `users/{uid}` exista con todos sus campos base y de
  /// que tenga un grupo personal — cubre tres casos con la misma lógica:
  ///  1. Cuenta nueva de verdad (documento no existe todavía).
  ///  2. Cuenta creada antes de introducir grupos múltiples (documento existe,
  ///     pero sin `groupIds`/`personalGroupId`).
  ///  3. Sesión de Firebase Auth persistida cuyo documento nunca llegó a
  ///     escribirse. `signInWithApple()` no se vuelve a llamar en ese caso, así
  ///     que este método también se dispara reactivamente desde `main.dart`.
  ///
  /// [nameFromProvider] solo se escribe si todavía no hay un `displayName`
  /// guardado: el nombre que el usuario haya puesto a mano siempre gana.
  Future<void> ensureUserDocument(
    String uid, {
    String? nameFromProvider,
    Map<String, dynamic>? existingData,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection('users')
        .doc(uid);

    final Map<String, dynamic> data =
        existingData ?? (await docRef.get()).data() ?? <String, dynamic>{};

    final String? storedDisplayName =
        (data['displayName'] as String?)?.trim().isNotEmpty == true
        ? (data['displayName'] as String).trim()
        : null;

    final String? displayName = storedDisplayName ?? nameFromProvider?.trim();

    await docRef.set(<String, dynamic>{
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
      if (!data.containsKey('photoUrl')) 'photoUrl': null,
      if (!data.containsKey('groupIds')) 'groupIds': <String>[],
      if (!data.containsKey('createdAt'))
        'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (data['personalGroupId'] != null) {
      return;
    }

    // Antes de crear uno nuevo, adoptar el personal que ya exista. Sin esta
    // comprobación, cada intento fallido de escribir `personalGroupId` dejaba
    // un grupo "Mi diario" huérfano más en la lista del usuario — y como
    // `main.dart` reintenta en cada arranque mientras el campo esté vacío, se
    // acumulaban indefinidamente.
    final String? adopted = await _findExistingPersonalGroup(uid, data);

    if (adopted != null) {
      await docRef.set(<String, dynamic>{
        'personalGroupId': adopted,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AppLog.i('AuthService: grupo personal existente adoptado.');
      return;
    }

    // El grupo y el `personalGroupId` se escriben en el MISMO batch, así que
    // o existen los dos o no existe ninguno.
    await HouseholdService(firestore: _firestore).createHousehold(
      uid: uid,
      displayName: displayName ?? unnamedMember,
      name: 'Mi diario',
      isPersonal: true,
      linkAsPersonal: true,
    );

    AppLog.i('AuthService: grupo personal listo.');
  }

  /// Busca entre los grupos que el usuario ya tiene registrados uno marcado
  /// como personal. Devuelve `null` si no hay ninguno o si no se pueden leer.
  Future<String?> _findExistingPersonalGroup(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final List<String> groupIds =
        (data['groupIds'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList();

    for (final String groupId in groupIds) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
            .collection('groups')
            .doc(groupId)
            .get();
        if (snap.exists && snap.data()?['isPersonal'] == true) {
          return groupId;
        }
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
      }
    }

    return null;
  }

  /// Guarda el nombre elegido por el usuario y lo propaga a la copia que cada
  /// grupo guarda en `memberProfiles` — si no, cambiarlo en Perfil no se veía
  /// en ninguna parte.
  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
    required List<String> groupIds,
  }) async {
    final String clean = displayName.trim();

    if (clean.isEmpty) {
      throw StateError('Escribe un nombre.');
    }

    final String safe = clean.length > 40 ? clean.substring(0, 40) : clean;

    await _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'displayName': safe,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await HouseholdService(
      firestore: _firestore,
    ).syncDisplayNameInGroups(uid: uid, groupIds: groupIds, displayName: safe);
  }

  /// Olvida la cuenta de Google elegida en este móvil.
  ///
  /// Sin esto, la próxima vez que alguien toque «Continuar con Google» el
  /// sistema le mete con la misma cuenta sin preguntar nada — que es lo
  /// contrario de lo que espera quien acaba de salir, y justo lo contrario de
  /// lo que espera quien acaba de borrar su cuenta.
  Future<void> cerrarSesionDeGoogle() async {
    // Si nunca se llamó a `initialize()`, no hay sesión de Google que cerrar
    // y llamar a `GoogleSignIn.instance` lanzaría.
    if (!_googleListo) return;
    await GoogleSignIn.instance.signOut();
  }

  Future<void> signOut() async {
    // Se ignora el fallo a propósito: que Google no responda no puede
    // impedir salir de la app.
    try {
      await cerrarSesionDeGoogle();
    } catch (e, st) {
      AppLog.e('No se pudo cerrar la sesión de Google', e, st);
    }
    await _auth.signOut();
  }
}
