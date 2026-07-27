import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class GamerFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener la referencia de la colección de estadísticas del usuario actual
  CollectionReference<Map<String, dynamic>>? get _userGamerCollection {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).collection('gamer_stats');
  }

  // Stream para escuchar cambios en las estadísticas generales del juego en tiempo real
  Stream<Map<String, dynamic>?> getGamerStatsStream() {
    final collection = _userGamerCollection;
    if (collection == null) return Stream.value(null);

    return collection.doc('main_stats').snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return snapshot.data();
    });
  }

  // Stream parametrizado por UID para escuchar el perfil y puntos específicos de cada usuario desde Firestore.
  Stream<Map<String, dynamic>?> getUserProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return snapshot.data();
    });
  }

  // Actualizar o inicializar estadísticas globales y de sesión en Firestore
  Future<void> updateGamerStats({
    required int score,
    required int streak,
    required List<String> unlockedChallenges,
  }) async {
    try {
      final collection = _userGamerCollection;
      if (collection == null) return;

      final docRef = collection.doc('main_stats');
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          transaction.set(docRef, {
            'total_score': score,
            'decisions_streak': streak,
            'unlocked_challenges': unlockedChallenges,
            'last_updated': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(docRef, {
            'total_score': score,
            'decisions_streak': streak,
            'unlocked_challenges': unlockedChallenges,
            'last_updated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      debugPrint("Error al actualizar estadísticas en Firestore: $e");
    }
  }

  // Guardar un registro histórico detallado de cada partida o tirada en la nube
  Future<void> logGameSessionEvent({
    required String winnerName,
    required String eventDetail,
    required int pointsAwarded,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('game_history')
          .add({
        'winner_name': winnerName,
        'event_detail': eventDetail,
        'points_awarded': pointsAwarded,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error al registrar evento de juego en Firestore: $e");
    }
  }
}