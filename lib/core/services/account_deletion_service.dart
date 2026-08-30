import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'household_service.dart';

/// ===========================================================================
/// ACCOUNT DELETION SERVICE
/// ===========================================================================
///
/// Cumple el requisito de Apple (App Store Guideline 5.1.1(v)): toda cuenta
/// creada dentro de la app debe poder eliminarse desde dentro de la app.
///
/// Orden de operaciones (no reordenar): primero se sale de todos sus
/// grupos (incluido su grupo personal) y se borra `users/{uid}` — ambas
/// escrituras dependen de que `request.auth.uid` siga existiendo y
/// coincidiendo (ver `isGroupMember()`/`isOwner()` en `firestore.rules`),
/// así que deben ocurrir ANTES de borrar la cuenta de Firebase Auth. Si se
/// borrara Auth primero, esas escrituras de limpieza fallarían por falta
/// de sesión.
///
/// Cuando el usuario que se va es el ÚLTIMO miembro de un grupo (siempre
/// el caso de su grupo personal), los datos compartidos (recuerdos, fotos,
/// stats) NO se borran — el grupo queda archivado (`members: []`) por si
/// la cuenta se recupera o alguien vuelve a unirse más adelante con el
/// mismo `groupId`. Apple exige que la CUENTA sea eliminable, no que el
/// contenido compartido desaparezca.
/// ===========================================================================

class AccountDeletionService {
  AccountDeletionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Elimina por completo la cuenta del usuario actual: lo saca de todos
  /// sus grupos (retirando también su perfil/foto de cada uno), borra su
  /// documento `users/{uid}` y finalmente su cuenta de Firebase Auth. Si
  /// Firebase exige un inicio de sesión reciente para esta operación
  /// sensible, vuelve a pedir Sign in with Apple automáticamente y
  /// reintenta una sola vez.
  Future<void> deleteAccount() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    final String uid = user.uid;

    final DocumentSnapshot<Map<String, dynamic>> userSnap = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    final List<String> groupIds =
        (userSnap.data()?['groupIds'] as List?)?.whereType<String>().toList() ??
            const <String>[];

    final HouseholdService householdService =
        HouseholdService(firestore: _firestore);
    for (final groupId in groupIds) {
      await householdService.removeMember(groupId: groupId, targetUid: uid);
    }

    await _firestore.collection('users').doc(uid).delete();

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      await _reauthenticateWithApple(user);
      await user.delete();
    }

    debugPrint('✅ AccountDeletionService: cuenta $uid eliminada.');
  }

  Future<void> _reauthenticateWithApple(User user) async {
    final AuthorizationCredentialAppleID appleCredential =
        await SignInWithApple.getAppleIDCredential(
          scopes: const [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

    final OAuthCredential oauthCredential = OAuthProvider(
      'apple.com',
    ).credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    await user.reauthenticateWithCredential(oauthCredential);
  }
}
