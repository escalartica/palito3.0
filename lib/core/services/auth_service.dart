import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// ===========================================================================
/// AUTH SERVICE
/// ===========================================================================
///
/// Encapsula el único método de inicio de sesión de la app: Sign in with
/// Apple. Al iniciar sesión por primera vez, crea el documento
/// `users/{uid}` del usuario (con `householdId: null` hasta que cree o se
/// una a un hogar) — Apple solo entrega el nombre real la primera vez que
/// un usuario autoriza esta app, así que se captura y persiste en ese
/// mismo momento.
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

    await _ensureUserDocument(
      user,
      givenName: appleCredential.givenName,
      familyName: appleCredential.familyName,
    );

    return user;
  }

  Future<void> _ensureUserDocument(
    User user, {
    String? givenName,
    String? familyName,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        _firestore.collection('users').doc(user.uid);

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await docRef.get();

    if (snapshot.exists) {
      // Ya tiene perfil (no es su primer inicio de sesión) — no lo
      // sobreescribimos, para no perder su householdId ni su displayName
      // ya elegido.
      return;
    }

    final String nameFromApple = <String?>[givenName, familyName]
        .where(
          (String? part) => part != null && part.trim().isNotEmpty,
        )
        .join(' ')
        .trim();

    final String displayName = nameFromApple.isNotEmpty
        ? nameFromApple
        : (user.email?.split('@').first ?? 'Usuario');

    await docRef.set(<String, dynamic>{
      'displayName': displayName,
      'photoUrl': null,
      'householdId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '✅ AuthService: perfil creado para ${user.uid} ($displayName).',
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
