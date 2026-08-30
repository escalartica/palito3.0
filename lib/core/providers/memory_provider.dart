import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/storage_service.dart';
import '../models/memory_model.dart';
import '../services/memory_map_firestore_service.dart';
import 'memory_map_provider.dart';

/// ===========================================================================
/// MEMORY NOTIFIER
/// ===========================================================================
///
/// Gestiona el estado global de las memorias.
///
/// Firestore es la fuente principal.
///
/// SharedPreferences funciona como:
///
/// - caché local
/// - carga rápida inicial
/// - respaldo temporal
///
/// ===========================================================================

class MemoryNotifier
    extends StateNotifier<List<MemoryModel>> {
  /// [firestoreService] es inyectable para poder sustituirlo por un doble
  /// de prueba en tests (evita depender de un backend de Firebase real).
  /// En producción siempre se usa el mismo [MemoryMapFirestoreService]
  /// que consume el mapa (vía [memoryMapServiceProvider]), para no abrir
  /// una segunda instancia del servicio ni un segundo listener de
  /// Firestore sobre la misma colección.
  MemoryNotifier({
    required Ref ref,
    MemoryMapFirestoreService? firestoreService,
  })  : _firestoreService =
            firestoreService ?? ref.read(memoryMapServiceProvider),
        super(<MemoryModel>[]) {
    // Se registra primero, de forma síncrona, para no perder ninguna
    // emisión del stream compartido con el mapa mientras se cargan las
    // memorias locales.
    _listenToFirestore(ref);
    _initialize();
  }

  // ==========================================================================
  // SERVICIO FIRESTORE
  // ==========================================================================

  final MemoryMapFirestoreService
      _firestoreService;

  // ==========================================================================
  // ESTADO INTERNO
  // ==========================================================================

  bool _isDisposed = false;

  bool _hasReceivedFirestoreData = false;

  bool _hasStreamError = false;

  bool _isPermissionDenied = false;

  // ==========================================================================
  // INICIALIZACIÓN
  // ==========================================================================

  Future<void> _initialize() async {
    try {
      debugPrint(
        '🧠 MemoryNotifier: '
        'iniciando inicialización...',
      );

      await _loadLocalMemories();

      debugPrint(
        '🧠 MemoryNotifier: '
        'inicialización completada.',
      );
    } catch (e, stack) {
      debugPrint(
        '❌ MemoryNotifier: '
        'error durante la inicialización: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );
    }
  }

  // ==========================================================================
  // CARGAR MEMORIAS LOCALES
  // ==========================================================================

  Future<void> _loadLocalMemories() async {
    try {
      final List<MemoryModel> localMemories =
          await StorageService.loadMemories();

      debugPrint(
        '💾 MemoryNotifier: '
        'memorias locales cargadas: '
        '${localMemories.length}',
      );

      if (_isDisposed) {
        return;
      }

      if (localMemories.isEmpty) {
        debugPrint(
          '💾 MemoryNotifier: '
          'no existen memorias locales.',
        );

        return;
      }

      final List<MemoryModel>
          normalizedMemories =
          _normalizeMemories(
        localMemories,
      );

      state = normalizedMemories;

      debugPrint(
        '🧠 MemoryNotifier: '
        'estado inicial cargado desde '
        'SharedPreferences: '
        '${state.length} memorias.',
      );
    } catch (e, stack) {
      debugPrint(
        '❌ MemoryNotifier: '
        'error cargando memorias locales: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );
    }
  }

  // ==========================================================================
  // ESCUCHAR FIRESTORE
  // ==========================================================================

  void _listenToFirestore(Ref ref) {
    try {
      debugPrint(
        '🔥 MemoryNotifier: '
        'iniciando escucha de Firestore '
        '(stream compartido con el mapa)...',
      );

      // Escucha memoryModelsStreamProvider en vez de abrir su propia
      // suscripción a Firestore: así solo hay un listener en tiempo real
      // sobre la colección de memorias, compartido con el mapa, en vez
      // de uno por cada consumidor.
      ref.listen<AsyncValue<List<MemoryModel>>>(
        memoryModelsStreamProvider,
        (previous, next) {
          next.when(
            data: (
              List<MemoryModel>
                  firestoreMemories,
            ) async {
              if (_isDisposed) {
                return;
              }

              debugPrint(
                '🔥 MemoryNotifier: '
                'memorias recibidas de Firestore: '
                '${firestoreMemories.length}',
              );

              _hasReceivedFirestoreData =
                  true;

              // Si veníamos de un error (p. ej. tras recuperar la
              // conexión), lo limpiamos: los datos ya están llegando.
              _hasStreamError = false;
              _isPermissionDenied = false;

              final List<MemoryModel>
                  normalizedMemories =
                  _normalizeMemories(
                firestoreMemories,
              );

              if (!_isDisposed) {
                state = normalizedMemories;
              }

              debugPrint(
                '🧠 MemoryNotifier: '
                'estado actualizado desde Firestore: '
                '${normalizedMemories.length} memorias.',
              );

              try {
                await StorageService
                    .saveMemories(
                  normalizedMemories,
                );

                debugPrint(
                  '💾 MemoryNotifier: '
                  'caché local sincronizada '
                  'con Firestore.',
                );
              } catch (e, stack) {
                debugPrint(
                  '⚠️ MemoryNotifier: '
                  'no se pudo actualizar la caché local: '
                  '$e',
                );

                debugPrintStack(
                  stackTrace: stack,
                );
              }
            },
            error: (
              Object error,
              StackTrace stack,
            ) {
              debugPrint(
                '❌ MemoryNotifier: '
                'error escuchando Firestore: '
                '$error',
              );

              debugPrintStack(
                stackTrace: stack,
              );

              _hasStreamError = true;
              _isPermissionDenied =
                  error is FirebaseException &&
                  error.code == 'permission-denied';

              // Reasignamos el estado (misma lista, nueva referencia)
              // solo para notificar a quien esté escuchando
              // memoryProvider de que hay algo nuevo que mostrar — sin
              // esto, un widget que solo mira `state` nunca se
              // reconstruiría al llegar un error, porque `state` en sí
              // no cambia de contenido.
              if (!_isDisposed) {
                state = List<MemoryModel>.from(
                  state,
                );
              }
            },
            loading: () {},
          );
        },
        fireImmediately: true,
      );
    } catch (e, stack) {
      debugPrint(
        '❌ MemoryNotifier: '
        'no se pudo iniciar el stream de Firestore: '
        '$e',
      );

      debugPrintStack(
        stackTrace: stack,
      );
    }
  }

  // ==========================================================================
  // AÑADIR MEMORIA
  // ==========================================================================

  Future<void> addMemory(
    MemoryModel newMemory,
  ) async {
    try {
      final String normalizedId =
          newMemory.id.trim();

      if (normalizedId.isEmpty) {
        throw ArgumentError(
          'No se puede añadir una memoria sin ID.',
        );
      }

      debugPrint(
        '➕ MemoryNotifier: '
        'añadiendo memoria $normalizedId...',
      );

      final List<MemoryModel>
          updatedMemories =
          List<MemoryModel>.from(
        state,
      );

      final int existingIndex =
          updatedMemories.indexWhere(
        (MemoryModel memory) =>
            memory.id.trim() ==
            normalizedId,
      );

      if (existingIndex >= 0) {
        updatedMemories[
                existingIndex] =
            newMemory;
      } else {
        updatedMemories.add(
          newMemory,
        );
      }

      state = _normalizeMemories(
        updatedMemories,
      );

      await StorageService.saveMemory(
        newMemory,
      );

      await _firestoreService
          .saveMemoryModel(
        newMemory,
      );

      debugPrint(
        '✅ MemoryNotifier: '
        'memoria añadida correctamente: '
        '$normalizedId',
      );
    } catch (e, stack) {
      debugPrint(
        '❌ MemoryNotifier: '
        'error añadiendo memoria: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // ACTUALIZAR MEMORIA
  // ==========================================================================

  Future<void> updateMemory(
    MemoryModel updatedMemory,
  ) async {
    try {
      final String normalizedId =
          updatedMemory.id.trim();

      if (normalizedId.isEmpty) {
        throw ArgumentError(
          'No se puede actualizar una memoria sin ID.',
        );
      }

      debugPrint(
        '✏️ MemoryNotifier: '
        'actualizando memoria '
        '$normalizedId...',
      );

      final List<MemoryModel>
          updatedMemories =
          state
              .map(
                (
                  MemoryModel memory,
                ) =>
                    memory.id.trim() ==
                            normalizedId
                        ? updatedMemory
                        : memory,
              )
              .toList();

      state = _normalizeMemories(
        updatedMemories,
      );

      await StorageService
          .updateMemory(
        updatedMemory,
      );

      await _firestoreService
          .saveMemoryModel(
        updatedMemory,
      );

      debugPrint(
        '✅ MemoryNotifier: '
        'memoria actualizada correctamente: '
        '$normalizedId',
      );
    } catch (e, stack) {
      debugPrint(
        '❌ MemoryNotifier: '
        'error actualizando memoria: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // ELIMINAR MEMORIA
  // ==========================================================================

  Future<void> removeMemory(
    String id,
  ) async {
    try {
      final String normalizedId =
          id.trim();

      if (normalizedId.isEmpty) {
        throw ArgumentError(
          'No se puede eliminar una memoria sin ID.',
        );
      }

      debugPrint(
        '🗑️ MemoryNotifier: '
        'eliminando memoria $normalizedId...',
      );

      state = state
          .where(
            (
              MemoryModel memory,
            ) =>
                memory.id.trim() !=
                normalizedId,
          )
          .toList();

      await StorageService
          .deleteMemory(
        normalizedId,
      );

      await _firestoreService
          .deleteMemory(
        normalizedId,
      );

      debugPrint(
        '✅ MemoryNotifier: '
        'memoria eliminada correctamente: '
        '$normalizedId',
      );
    } catch (e, stack) {
      debugPrint(
        '❌ MemoryNotifier: '
        'error eliminando memoria: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // BUSCAR MEMORIA POR ID
  // ==========================================================================

  MemoryModel? getMemoryById(
    String id,
  ) {
    final String normalizedId =
        id.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    for (final MemoryModel memory
        in state) {
      if (memory.id.trim() ==
          normalizedId) {
        return memory;
      }
    }

    return null;
  }

  // ==========================================================================
  // MEMORIA MÁS RECIENTE
  // ==========================================================================

  MemoryModel? get latestMemory {
    if (state.isEmpty) {
      return null;
    }

    return state.first;
  }

  // ==========================================================================
  // LIMPIAR MEMORIAS LOCALES
  // ==========================================================================

  Future<void>
      clearLocalMemories() async {
    try {
      state = <MemoryModel>[];

      await StorageService
          .clearMemories();

      debugPrint(
        '🧹 MemoryNotifier: '
        'memorias locales eliminadas.',
      );
    } catch (e, stack) {
      debugPrint(
        '❌ MemoryNotifier: '
        'error limpiando memorias locales: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // NORMALIZAR MEMORIAS
  // ==========================================================================

  List<MemoryModel>
      _normalizeMemories(
    List<MemoryModel> memories,
  ) {
    final Map<String, MemoryModel>
        uniqueMemories =
        <String, MemoryModel>{};

    for (final MemoryModel memory
        in memories) {
      final String id =
          memory.id.trim();

      if (id.isEmpty) {
        continue;
      }

      uniqueMemories[id] =
          memory;
    }

    final List<MemoryModel>
        normalizedMemories =
        uniqueMemories.values.toList();

    normalizedMemories.sort(
      _compareMemoriesByDateDescending,
    );

    return normalizedMemories;
  }

  // ==========================================================================
  // COMPARAR FECHAS
  // ==========================================================================

  static int
      _compareMemoriesByDateDescending(
    MemoryModel a,
    MemoryModel b,
  ) {
    final DateTime dateA = a.date;
    final DateTime dateB = b.date;

    return dateB.compareTo(
      dateA,
    );
  }

  // ==========================================================================
  // ESTADO FIRESTORE
  // ==========================================================================

  bool get hasReceivedFirestoreData {
    return _hasReceivedFirestoreData;
  }

  /// true si la última emisión del stream de Firestore fue un error (p.
  /// ej. sin conexión, o las reglas de seguridad rechazando el acceso).
  /// Se limpia solo en cuanto vuelven a llegar datos.
  bool get hasStreamError {
    return _hasStreamError;
  }

  /// true si el error del stream es específicamente un rechazo de
  /// `firestore.rules` (UID no autorizado) — p. ej. tras un reinstall
  /// completo, que genera una sesión anónima nueva no incluida todavía
  /// en la whitelist. Se distingue de un error de red genérico porque
  /// el mensaje a mostrar (y la solución) es completamente distinto.
  bool get isPermissionDenied {
    return _isPermissionDenied;
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _isDisposed = true;

    // No hay que cancelar ninguna suscripción manual: el ref.listen de
    // memoryModelsStreamProvider se limpia solo cuando Riverpod destruye
    // este provider.
    debugPrint(
      '🧠 MemoryNotifier: '
      'notifier eliminado.',
    );

    super.dispose();
  }
}

// ============================================================================
// PROVIDER PRINCIPAL
// ============================================================================

final memoryProvider =
    StateNotifierProvider<
        MemoryNotifier,
        List<MemoryModel>>(
  (ref) {
    // `ref.watch` (no `.read`): si el grupo activo cambia — al
    // resolverse por primera vez tras iniciar sesión, o al cambiar de
    // grupo con el selector — hay que recrear el notifier entero con un
    // `MemoryMapFirestoreService` nuevo, apuntando al grupo correcto.
    // Antes se capturaba una sola vez dentro del propio `MemoryNotifier`
    // (con `ref.read`), así que quedaba fijado para siempre al grupo que
    // hubiera activo en el instante exacto en que se creó el notifier —
    // guardar un recuerdo nunca volvía a apuntar al grupo correcto tras
    // cambiar de grupo, y si ese instante caía antes de que el grupo
    // personal terminara de resolverse, se quedaba fijado a `null` para
    // el resto de la sesión.
    final service = ref.watch(memoryMapServiceProvider);
    return MemoryNotifier(ref: ref, firestoreService: service);
  },
);

// ============================================================================
// CATEGORÍA SELECCIONADA
// ============================================================================

final selectedCategoryProvider =
    StateProvider<String>(
  (ref) => 'Todos',
);