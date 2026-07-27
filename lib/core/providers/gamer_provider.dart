import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palito_3_0/core/services/gamer_firestore_service.dart';

// Proveedor global del servicio de Firestore para la Zona Gamer
final gamerServiceProvider = Provider<GamerFirestoreService>((ref) {
  return GamerFirestoreService();
});

// StreamProvider global para escuchar las estadísticas generales de la sesión en tiempo real
final gamerStatsStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(gamerServiceProvider).getGamerStatsStream();
});

// StreamProvider parametrizado por UID para escuchar el perfil y puntos específicos de cada usuario desde Firestore.
final userProfileStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
  return ref.watch(gamerServiceProvider).getUserProfileStream(uid);
});