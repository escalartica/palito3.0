import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'household_service.dart';

/// ===========================================================================
/// AUTH SERVICE
/// ===========================================================================
///
/// Encapsula el único método de inicio de sesión de la app: Sign in with
/// Apple. Al iniciar sesión por primera vez, crea el documento
/// `users/{uid}` del usuario Y su grupo personal (su diario privado — ver
/// `HouseholdService`) — así nadie se queda nunca sin ningún grupo, y no
/// hace falta ninguna pantalla de configuración obligatoria antes de poder
/// usar la app. Apple solo entrega el nombre real la primera vez que un
/// usuario autoriza esta app, así que se captura y persiste en ese mismo
/// momento.
/// ===========================================================================

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  /// Inicia sesión con Apple, creando el usuario de Firebase Auth si es la
  /// primera vez, y asegura que exista su documento `users/{uid}`.
  Future<User?> signInWithApple() async {
    final AuthorizationCredentialAppleID appleCredential =
        await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final OAuthCredential oauthCredential = OAuthProvider('apple.com')
        .credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final UserCredential userCredential =
        await _auth.signInWithCredential(oauthCredential);

    final User? user = userCredential.user;

    if (user == null) {
      return null;
    }

    final String nameFromApple = <String?>[
      appleCredential.givenName,
      appleCredential.familyName,
    ]
        .where((String? part) => part != null && part.trim().isNotEmpty)
        .join(' ')
        .trim();

    await ensureUserDocument(
      user.uid,
      fallbackDisplayName: nameFromApple.isNotEmpty
          ? nameFromApple
          : (user.email?.split('@').first ?? 'Usuario'),
    );

    return user;
  }

  /// Se asegura de que `users/{uid}` exista con todos sus campos base y
  /// de que tenga un grupo personal — cubre tres casos con la misma
  /// lógica, sin necesitar ramas separadas:
  ///  1. Cuenta nueva de verdad (documento no existe todavía).
  ///  2. Cuenta creada antes de introducir grupos múltiples (documento
  ///     existe, pero sin `groupIds`/`personalGroupId`).
  ///  3. Sesión de Firebase Auth persistida cuyo documento nunca llegó a
  ///     escribirse (p. ej. por un fallo de red o de permisos en su
  ///     primer inicio de sesión) — Auth recuerda al usuario, pero
  ///     Firestore no tiene su perfil. `signInWithApple()` no se vuelve a
  ///     llamar en este caso (la sesión ya está iniciada), así que este
  ///     método también se dispara reactivamente desde `main.dart` en
  ///     cuanto se detecta el hueco, sin esperar a un nuevo inicio de
  ///     sesión manual.
  ///
  /// [fallbackDisplayName] solo se usa si hay que crear el documento
  /// desde cero y no había ya un `displayName` guardado.
  Future<void> ensureUserDocument(
    String uid, {
    String fallbackDisplayName = 'Usuario',
    Map<String, dynamic>? existingData,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        _firestore.collection('users').doc(uid);

    final Map<String, dynamic> data =
        existingData ?? (await docRef.get()).data() ?? <String, dynamic>{};

    final String? storedDisplayName = data['displayName'] as String?;
    final String displayName = storedDisplayName?.trim().isNotEmpty == true
        ? storedDisplayName!
        : fallbackDisplayName;

    // set(merge: true) es seguro tanto si el documento no existía
    // todavía (lo crea con estos valores) como si ya existía (solo
    // rellena los campos que falten, sin pisar groupIds/displayName ya
    // elegidos) — a diferencia de `update()`, que lanza `not-found` si
    // el documento no existe, el caso exacto que dejaba a una sesión ya
    // autenticada sin forma de repararse sola.
    await docRef.set(<String, dynamic>{
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

    final String personalGroupId =
        await HouseholdService(firestore: _firestore).createHousehold(
      uid: uid,
      displayName: displayName,
      name: 'Mi diario',
      isPersonal: true,
    );

    await docRef.set(<String, dynamic>{
      'personalGroupId': personalGroupId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint(
      '✅ AuthService: grupo personal $personalGroupId listo para $uid '
      '($displayName).',
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
