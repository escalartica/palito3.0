import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CloudService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ==========================================================================
  // ZONA GAMER & ESTADÍSTICAS
  // ==========================================================================

  // Guardar o actualizar el estado de la sesión de juego.
  Future<void> saveGameSession(
    String sessionId,
    Map<String, dynamic> sessionData,
  ) async {
    try {
      await _firestore
          .collection('game_sessions')
          .doc(sessionId)
          .set(
        {
          ...sessionData,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      debugPrint(
        '☁️ CloudService: '
        'sesión de juego guardada: '
        '$sessionId',
      );
    } catch (e, stack) {
      debugPrint(
        '❌ CloudService: '
        'error al guardar la sesión de juego: '
        '$e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // STREAM DE SESIÓN DE JUEGO
  // ==========================================================================

  Stream<
          DocumentSnapshot<
              Map<String, dynamic>>>
      streamGameSession(
    String sessionId,
  ) {
    return _firestore
        .collection('game_sessions')
        .doc(sessionId)
        .snapshots();
  }

  // ==========================================================================
  // RECUERDOS Y LOCALIZACIONES
  // ==========================================================================

  // Guardar un nuevo recuerdo gastronómico.
  Future<void> saveMemory(
    String memoryId,
    Map<String, dynamic> memoryData,
  ) async {
    try {
      await _firestore
          .collection('memories')
          .doc(memoryId)
          .set(
        {
          ...memoryData,
          'timestamp':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      debugPrint(
        '☁️ CloudService: '
        'recuerdo guardado: '
        '$memoryId',
      );
    } catch (e, stack) {
      debugPrint(
        '❌ CloudService: '
        'error al guardar el recuerdo: '
        '$e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // STREAM DE RECUERDOS
  // ==========================================================================

  Stream<
          QuerySnapshot<
              Map<String, dynamic>>>
      streamMemories() {
    return _firestore
        .collection('memories')
        .orderBy(
          'timestamp',
          descending: true,
        )
        .snapshots();
  }
}