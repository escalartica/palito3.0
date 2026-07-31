
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:palito_3_0/core/services/gamer_firestore_service.dart';

// ============================================================================
// SERVICIO GLOBAL DE GAMER
// ============================================================================
//
// Este provider centraliza la instancia de GamerFirestoreService.
//
// Ninguna pantalla debe crear directamente:
//
// GamerFirestoreService()
//
// En su lugar, utilizar:
//
// ref.read(gamerServiceProvider)
//
// o:
//
// ref.watch(gamerServiceProvider)
//
// De esta forma, toda la aplicación utiliza la misma instancia del servicio.
// ============================================================================

final gamerServiceProvider = Provider<GamerFirestoreService>(
  (ref) {
    return GamerFirestoreService();
  },
);

// ============================================================================
// ESTADÍSTICAS GAMER DEL USUARIO ACTUAL
// ============================================================================
//
// FUENTE ÚNICA DE LECTURA PARA LAS ESTADÍSTICAS GAMER DE LA UI.
//
// Este provider devuelve un GamerStats normalizado.
//
// La UI NO debe interpretar directamente los mapas de Firestore.
//
// La normalización de:
//
// - total_score
// - totalScore
// - gamerPoints
// - score
// - points
// - decisions
// - totalDecisions
// - total_decisions
// - decisions_streak
// - currentStreak
// - unlocked_challenges
// - unlockedChallenges
//
// se realiza dentro de GamerFirestoreService.
//
// Utilizar desde:
//
// - ProfilePage
// - GamerPage
// - Panel Pro
// - cualquier pantalla que necesite estadísticas Gamer
//
// ============================================================================

final gamerStatsStreamProvider = StreamProvider<GamerStats?>(
  (ref) {
    final GamerFirestoreService service =
        ref.watch(gamerServiceProvider);

    return service.getGamerStatsStream();
  },
);

// ============================================================================
// PERFIL GENERAL DE FIRESTORE POR UID
// ============================================================================
//
// Este provider devuelve los datos generales del documento:
//
// users/{uid}
//
// Este provider NO debe utilizarse para leer estadísticas Gamer.
//
// Para estadísticas Gamer utilizar:
//
// gamerStatsStreamProvider
//
// o:
//
// userGamerStatsStreamProvider(uid)
//
// ============================================================================

final userProfileStreamProvider =
    StreamProvider.family<Map<String, dynamic>?, String>(
  (
    ref,
    uid,
  ) {
    final GamerFirestoreService service =
        ref.watch(gamerServiceProvider);

    return service.getUserProfileStream(uid);
  },
);

// ============================================================================
// ESTADÍSTICAS GAMER DE UN UID ESPECÍFICO
// ============================================================================
//
// Este provider permite consultar las estadísticas Gamer de un usuario
// concreto.
//
// Ejemplo:
//
// ref.watch(
//   userGamerStatsStreamProvider(uid),
// );
//
// Se utiliza principalmente para:
//
// - rankings
// - perfiles de otros usuarios
// - consultas administrativas
// - estadísticas de otros jugadores
//
// Para el usuario actualmente autenticado, preferir:
//
// gamerStatsStreamProvider
//
// ============================================================================

final userGamerStatsStreamProvider =
    StreamProvider.family<GamerPlayerStats?, String>(
  (
    ref,
    uid,
  ) {
    final GamerFirestoreService service =
        ref.watch(gamerServiceProvider);

    return service.getUserGamerStatsStream(uid);
  },
);

