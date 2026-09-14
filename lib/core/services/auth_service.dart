import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      nameFromApple: nameFromApple.isNotEmpty ? nameFromApple : null,
    );

    return user;
  }

  /// Se asegura de que `users/{uid}` exista con todos sus campos base y de
  /// que tenga un grupo personal — cubre tres casos con la misma lógica:
  ///  1. Cuenta nueva de verdad (documento no existe todavía).
  ///  2. Cuenta creada antes de introducir grupos múltiples (documento existe,
  ///     pero sin `groupIds`/`personalGroupId`).
  ///  3. Sesión de Firebase Auth persistida cuyo documento nunca llegó a
  ///     escribirse. `signInWithApple()` no se vuelve a llamar en ese caso, así
  ///     que este método también se dispara reactivamente desde `main.dart`.
  ///
  /// [nameFromApple] solo se escribe si todavía no hay un `displayName`
  /// guardado: el nombre que el usuario haya puesto a mano siempre gana.
  Future<void> ensureUserDocument(
    String uid, {
    String? nameFromApple,
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

    final String? displayName = storedDisplayName ?? nameFromApple?.trim();

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

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
