import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/storage_service.dart';
import '../models/memory_model.dart';
import '../services/memory_map_firestore_service.dart';

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
  MemoryNotifier()
      : _firestoreService =
            MemoryMapFirestoreService(),
        super(<MemoryModel>[]) {
    _initialize();
  }

  // ==========================================================================
  // SERVICIO FIRESTORE
  // ==========================================================================

  final MemoryMapFirestoreService
      _firestoreService;

  // ==========================================================================
  // SUSCRIPCIÓN
  // ==========================================================================

  StreamSubscription<
          List<MemoryModel>>?
      _firestoreSubscription;

  // ==========================================================================
  // ESTADO INTERNO
  // ==========================================================================

  bool _isDisposed = false;

  bool _hasReceivedFirestoreData = false;

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

      if (_isDisposed) {
        return;
      }

      _listenToFirestore();

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

  void _listenToFirestore() {
    try {
      debugPrint(
        '🔥 MemoryNotifier: '
        'iniciando escucha de Firestore...',
      );

      _firestoreSubscription =
          _firestoreService
              .getMemoryModelsStream()
              .listen(
        (
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
        onError: (
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
        },
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

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _isDisposed = true;

    _firestoreSubscription
        ?.cancel();

    _firestoreSubscription = null;

    debugPrint(
      '🧠 MemoryNotifier: '
      'stream de Firestore cancelado.',
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
    return MemoryNotifier();
  },
);

// ============================================================================
// CATEGORÍA SELECCIONADA
// ============================================================================

final selectedCategoryProvider =
    StateProvider<String>(
  (ref) => 'Todos',
);