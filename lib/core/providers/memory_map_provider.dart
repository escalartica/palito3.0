
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'household_provider.dart';
import '../services/memory_map_firestore_service.dart';
import '../models/memory_model.dart';

/// ============================================================
/// MEMORY MAP FIRESTORE SERVICE PROVIDER
/// ============================================================

final memoryMapServiceProvider =
    Provider<MemoryMapFirestoreService>((ref) {
  final String? householdId = ref.watch(currentHouseholdIdProvider);

  return MemoryMapFirestoreService(householdId: householdId);
});

/// ============================================================
/// MEMORY MODELS STREAM PROVIDER
/// ============================================================


final memoryModelsStreamProvider =
    StreamProvider<List<MemoryModel>>((ref) {
  final service =
      ref.watch(
    memoryMapServiceProvider,
  );

  return service.getMemoryModelsStream();
});

/// ============================================================
/// MEMORIES MAP STREAM PROVIDER
/// ============================================================
///
/// Provider legacy/compatibilidad.
///
/// Devuelve los recuerdos como:
///

///
/// El MapPage nuevo debería utilizar preferentemente:
///
/// memoryModelsStreamProvider
///
/// Este provider se mantiene por compatibilidad con otras
/// partes de la aplicación que todavía esperan mapas dinámicos.
///

final memoriesStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service =
      ref.watch(
    memoryMapServiceProvider,
  );

  return service.getMemoriesStream();
});

/// ============================================================
/// LOCATIONS STREAM PROVIDER
/// ============================================================
///
/// Colección secundaria de localizaciones.
///
/// Se mantiene por compatibilidad con datos antiguos.
///
/// Estructura:
///
/// users/{uid}/locations
///
/// El MapPage principal NO depende de esta colección para
/// mostrar los recuerdos.
///
/// Solo se utiliza como fallback para documentos legacy que
/// todavía no tengan coordenadas dentro de:
///
/// memory.location.lat
/// memory.location.lng
///

// autoDispose: a diferencia de memoryModelsStreamProvider (que
// memoryProvider mantiene vivo permanentemente para toda la app), este
// stream solo lo consume la pantalla de Mapa. Sin autoDispose, visitar
// el Mapa una sola vez dejaría un listener de Firestore abierto para
// siempre, incluso navegando a otras pantallas.
final locationsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service =
      ref.watch(
    memoryMapServiceProvider,
  );

  return service.getLocationsStream();
});

