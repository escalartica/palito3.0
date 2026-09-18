import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/storage_service.dart';
import '../models/memory_model.dart';
import '../services/memory_map_firestore_service.dart';
import 'household_provider.dart';
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

class MemoryNotifier extends StateNotifier<List<MemoryModel>> {
  /// [firestoreService] es inyectable para poder sustituirlo por un doble
  /// de prueba en tests (evita depender de un backend de Firebase real).
  /// En producción siempre se usa el mismo [MemoryMapFirestoreService]
  /// que consume el mapa (vía [memoryMapServiceProvider]), para no abrir
  /// una segunda instancia del servicio ni un segundo listener de
  /// Firestore sobre la misma colección.
  MemoryNotifier({
    required Ref ref,
    MemoryMapFirestoreService? firestoreService,
  }) : _firestoreService =
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

  final MemoryMapFirestoreService _firestoreService;

  /// El diario al que pertenece esta caché local.
  ///
  /// Sale del propio servicio, que ya lo tiene resuelto, en vez de volver a
  /// leer el provider: así no puede desalinearse con el sitio al que este
  /// notifier está escribiendo de verdad.
  String? get _diario => _firestoreService.groupId;

  // ==========================================================================
  // ESTADO INTERNO
  // ==========================================================================

  bool _isDisposed = false;

  bool _hasReceivedFirestoreData = false;

  bool _hasStreamError = false;

  /// Temporizador de la escritura en la caché local. Ver [_schedulePersist].
  Timer? _persistTimer;

  /// Lo último que hay pendiente de escribir en la caché local.
  List<MemoryModel>? _pendingPersist;

  bool _isPermissionDenied = false;

  // ==========================================================================
  // INICIALIZACIÓN
  // ==========================================================================

  Future<void> _initialize() async {
    try {
      _log(
        '🧠 MemoryNotifier: '
        'iniciando inicialización...',
      );

      await _loadLocalMemories();

      _log(
        '🧠 MemoryNotifier: '
        'inicialización completada.',
      );
    } catch (e, stack) {
      _log(
        '❌ MemoryNotifier: '
        'error durante la inicialización: $e',
      );

      _logStack(stackTrace: stack);
    }
  }

  // ==========================================================================
  // CARGAR MEMORIAS LOCALES
  // ==========================================================================

  Future<void> _loadLocalMemories() async {
    try {
      final List<MemoryModel> localMemories =
          await StorageService.loadMemories(groupId: _diario);

      _log(
        '💾 MemoryNotifier: '
        'memorias locales cargadas: '
        '${localMemories.length}',
      );

      if (_isDisposed) {
        return;
      }

      if (localMemories.isEmpty) {
        _log(
          '💾 MemoryNotifier: '
          'no existen memorias locales.',
        );

        return;
      }

      final List<MemoryModel> normalizedMemories = _normalizeMemories(
        localMemories,
      );

      state = normalizedMemories;

      _log(
        '🧠 MemoryNotifier: '
        'estado inicial cargado desde '
        'SharedPreferences: '
        '${state.length} memorias.',
      );
    } catch (e, stack) {
      _log(
        '❌ MemoryNotifier: '
        'error cargando memorias locales: $e',
      );

      _logStack(stackTrace: stack);
    }
  }

  // ==========================================================================
  // ESCUCHAR FIRESTORE
  // ==========================================================================

  void _listenToFirestore(Ref ref) {
    try {
      _log(
        '🔥 MemoryNotifier: '
        'iniciando escucha de Firestore '
        '(stream compartido con el mapa)...',
      );

      // Escucha memoryModelsStreamProvider en vez de abrir su propia
      // suscripción a Firestore: así solo hay un listener en tiempo real
      // sobre la colección de memorias, compartido con el mapa, en vez
      // de uno por cada consumidor.
      ref.listen<AsyncValue<List<MemoryModel>>>(memoryModelsStreamProvider, (
        previous,
        next,
      ) {
        next.when(
          data: (List<MemoryModel> firestoreMemories) async {
            if (_isDisposed) {
              return;
            }

            _log(
              '🔥 MemoryNotifier: '
              'memorias recibidas de Firestore: '
              '${firestoreMemories.length}',
            );

            _hasReceivedFirestoreData = true;

            // Si veníamos de un error (p. ej. tras recuperar la
            // conexión), lo limpiamos: los datos ya están llegando.
            _hasStreamError = false;
            _isPermissionDenied = false;

            final List<MemoryModel> normalizedMemories = _normalizeMemories(
              firestoreMemories,
            );

            if (!_isDisposed) {
              state = normalizedMemories;
            }

            _log(
              '🧠 MemoryNotifier: '
              'estado actualizado desde Firestore: '
              '${normalizedMemories.length} memorias.',
            );

            _schedulePersist(normalizedMemories);
          },
          error: (Object error, StackTrace stack) {
            _log(
              '❌ MemoryNotifier: '
              'error escuchando Firestore: '
              '$error',
            );

            _logStack(stackTrace: stack);

            _hasStreamError = true;
            _isPermissionDenied =
                error is FirebaseException && error.code == 'permission-denied';

            // Reasignamos el estado (misma lista, nueva referencia)
            // solo para notificar a quien esté escuchando
            // memoryProvider de que hay algo nuevo que mostrar — sin
            // esto, un widget que solo mira `state` nunca se
            // reconstruiría al llegar un error, porque `state` en sí
            // no cambia de contenido.
            if (!_isDisposed) {
              state = List<MemoryModel>.from(state);
            }
          },
          loading: () {},
        );
      }, fireImmediately: true);
    } catch (e, stack) {
      _log(
        '❌ MemoryNotifier: '
        'no se pudo iniciar el stream de Firestore: '
        '$e',
      );

      _logStack(stackTrace: stack);
    }
  }

  // ==========================================================================
  // AÑADIR MEMORIA
  // ==========================================================================

  Future<void> addMemory(MemoryModel newMemory) async {
    try {
      final String normalizedId = newMemory.id.trim();

      if (normalizedId.isEmpty) {
        throw ArgumentError('No se puede añadir una memoria sin ID.');
      }

      _log(
        '➕ MemoryNotifier: '
        'añadiendo memoria $normalizedId...',
      );

      // Estado optimista CON marcha atrás. Antes se actualizaba la lista y,
      // si la escritura fallaba, no se revertía: el usuario veía a la vez
      // "No se pudo guardar el recuerdo" y el recuerdo en la lista y en el
      // mapa. Al reiniciar la app desaparecía.
      final List<MemoryModel> previousState = List<MemoryModel>.from(state);

      final List<MemoryModel> updatedMemories = List<MemoryModel>.from(state);

      final int existingIndex = updatedMemories.indexWhere(
        (MemoryModel memory) => memory.id.trim() == normalizedId,
      );

      if (existingIndex >= 0) {
        updatedMemories[existingIndex] = newMemory;
      } else {
        updatedMemories.add(newMemory);
      }

      state = _normalizeMemories(updatedMemories);

      try {
        await StorageService.saveMemory(newMemory, groupId: _diario);

        await _firestoreService.saveMemoryModel(newMemory);
      } catch (_) {
        state = _normalizeMemories(previousState);
        rethrow;
      }

      _log(
        '✅ MemoryNotifier: '
        'memoria añadida correctamente: '
        '$normalizedId',
      );
    } catch (e, stack) {
      _log(
        '❌ MemoryNotifier: '
        'error añadiendo memoria: $e',
      );

      _logStack(stackTrace: stack);

      rethrow;
    }
  }

  // ==========================================================================
  // ACTUALIZAR MEMORIA
  // ==========================================================================

  Future<void> updateMemory(MemoryModel updatedMemory) async {
    try {
      final String normalizedId = updatedMemory.id.trim();

      if (normalizedId.isEmpty) {
        throw ArgumentError('No se puede actualizar una memoria sin ID.');
      }

      _log(
        '✏️ MemoryNotifier: '
        'actualizando memoria '
        '$normalizedId...',
      );

      final List<MemoryModel> updatedMemories = state
          .map(
            (MemoryModel memory) =>
                memory.id.trim() == normalizedId ? updatedMemory : memory,
          )
          .toList();

      state = _normalizeMemories(updatedMemories);

      await StorageService.updateMemory(updatedMemory, groupId: _diario);

      await _firestoreService.saveMemoryModel(updatedMemory);

      _log(
        '✅ MemoryNotifier: '
        'memoria actualizada correctamente: '
        '$normalizedId',
      );
    } catch (e, stack) {
      _log(
        '❌ MemoryNotifier: '
        'error actualizando memoria: $e',
      );

      _logStack(stackTrace: stack);

      rethrow;
    }
  }

  // ==========================================================================
  // ELIMINAR MEMORIA
  // ==========================================================================

  Future<void> removeMemory(String id) async {
    try {
      final String normalizedId = id.trim();

      if (normalizedId.isEmpty) {
        throw ArgumentError('No se puede eliminar una memoria sin ID.');
      }

      _log(
        '🗑️ MemoryNotifier: '
        'eliminando memoria $normalizedId...',
      );

      state = state
          .where((MemoryModel memory) => memory.id.trim() != normalizedId)
          .toList();

      await StorageService.deleteMemory(normalizedId, groupId: _diario);

      await _firestoreService.deleteMemory(normalizedId);

      _log(
        '✅ MemoryNotifier: '
        'memoria eliminada correctamente: '
        '$normalizedId',
      );
    } catch (e, stack) {
      _log(
        '❌ MemoryNotifier: '
        'error eliminando memoria: $e',
      );

      _logStack(stackTrace: stack);

      rethrow;
    }
  }

  // ==========================================================================
  // BUSCAR MEMORIA POR ID
  // ==========================================================================

  MemoryModel? getMemoryById(String id) {
    final String normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    for (final MemoryModel memory in state) {
      if (memory.id.trim() == normalizedId) {
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

  Future<void> clearLocalMemories() async {
    try {
      state = <MemoryModel>[];

      await StorageService.clearMemories(groupId: _diario);

      _log(
        '🧹 MemoryNotifier: '
        'memorias locales eliminadas.',
      );
    } catch (e, stack) {
      _log(
        '❌ MemoryNotifier: '
        'error limpiando memorias locales: $e',
      );

      _logStack(stackTrace: stack);

      rethrow;
    }
  }

  // ==========================================================================
  // NORMALIZAR MEMORIAS
  // ==========================================================================

  List<MemoryModel> _normalizeMemories(List<MemoryModel> memories) {
    final Map<String, MemoryModel> uniqueMemories = <String, MemoryModel>{};

    for (final MemoryModel memory in memories) {
      final String id = memory.id.trim();

      if (id.isEmpty) {
        continue;
      }

      uniqueMemories[id] = memory;
    }

    final List<MemoryModel> normalizedMemories = uniqueMemories.values.toList();

    normalizedMemories.sort(_compareMemoriesByDateDescending);

    return normalizedMemories;
  }

  // ==========================================================================
  // COMPARAR FECHAS
  // ==========================================================================

  static int _compareMemoriesByDateDescending(MemoryModel a, MemoryModel b) {
    final DateTime dateA = a.date;
    final DateTime dateB = b.date;

    return dateB.compareTo(dateA);
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
  // CACHÉ LOCAL
  // ==========================================================================

  /// Guarda el diario en la caché local, pero no en el mismo instante en que
  /// llega de Firestore.
  ///
  /// POR QUÉ. Guardar la caché significa recorrer TODOS los recuerdos,
  /// convertirlos a mapas, normalizarlos y pasarlos por `jsonEncode` — y eso
  /// ocurre en el hilo de la interfaz. Antes se hacía en cada instantánea de
  /// Firestore, y Firestore emite más veces de las que uno imagina: al
  /// guardar un recuerdo emite una por la escritura local (compensación de
  /// latencia) y otra cuando el servidor confirma. Dos recorridos completos
  /// del diario por cada plato que apuntas, justo en el momento en que la
  /// pantalla está animando el guardado.
  ///
  /// Con medio segundo de espera, una ráfaga de instantáneas se convierte en
  /// una sola escritura, y esa escritura ya no cae dentro del fotograma en el
  /// que la interfaz está trabajando.
  ///
  /// QUÉ SE PIERDE: si la app muere en ese medio segundo, la caché local se
  /// queda con la versión anterior. No es grave y es lo correcto: la fuente
  /// de verdad es Firestore, y esta caché solo existe para que la app tenga
  /// algo que enseñar mientras arranca.
  void _schedulePersist(List<MemoryModel> memories) {
    if (_isDisposed) return;

    _pendingPersist = memories;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), _flushPersist);
  }

  Future<void> _flushPersist() async {
    _persistTimer?.cancel();
    _persistTimer = null;

    final List<MemoryModel>? pending = _pendingPersist;
    if (pending == null) return;
    _pendingPersist = null;

    try {
      await StorageService.saveMemories(pending, groupId: _diario);

      _log(
        '💾 MemoryNotifier: '
        'caché local sincronizada '
        'con Firestore.',
      );
    } catch (e, stack) {
      _log(
        '⚠️ MemoryNotifier: '
        'no se pudo actualizar la caché local: '
        '$e',
      );

      _logStack(stackTrace: stack);
    }
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _isDisposed = true;

    // Si quedaba algo por escribir, se escribe ahora: cambiar de diario
    // destruye este notifier, y sin esto el último cambio no llegaría nunca
    // a la caché local. No se espera al resultado — `dispose` no puede ser
    // asíncrono — pero la escritura ya está lanzada.
    if (_pendingPersist != null) {
      unawaited(_flushPersist());
    }
    _persistTimer?.cancel();

    // No hay que cancelar ninguna suscripción manual: el ref.listen de
    // memoryModelsStreamProvider se limpia solo cuando Riverpod destruye
    // este provider.
    _log(
      '🧠 MemoryNotifier: '
      'notifier eliminado.',
    );

    super.dispose();
  }
}

// ============================================================================
// PROVIDER PRINCIPAL
// ============================================================================

final memoryProvider = StateNotifierProvider<MemoryNotifier, List<MemoryModel>>(
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

final selectedCategoryProvider = StateProvider<String>((ref) => 'Todos');

/// Cambiar el diario que se está viendo. `null` vuelve al diario personal.
///
/// Existe para que el cambio de diario y el **borrado del filtro** ocurran
/// siempre juntos. Antes eran dos cosas sueltas y el filtro se quedaba
/// puesto: pasabas de un diario a otro con "Tortilla" marcada y el nuevo te
/// enseñaba solo sus tortillas. Dos de tres recuerdos desaparecían de la
/// vista sin ninguna explicación, y lo que un usuario concluye de eso no es
/// "tengo un filtro puesto", es "he perdido cosas".
///
/// Las categorías además no son las mismas en cada diario: filtrar por una
/// que el diario nuevo no tiene deja la pantalla vacía del todo.
void switchActiveGroup(WidgetRef ref, String? groupId) {
  ref.read(activeGroupIdOverrideProvider.notifier).state = groupId;
  ref.read(selectedCategoryProvider.notifier).state = 'Todos';
}

// ===========================================================================
// LOGS
// ===========================================================================
//
// `debugPrint` NO se desactiva en una build de release: sigue escribiendo al
// log del sistema (Console.app en iOS, logcat en Android), donde lo puede leer
// cualquiera con el dispositivo delante o un informe de diagnóstico. Este
// archivo estaba volcando ahí identificadores de usuario, de grupo y datos de
// ubicación. Con este envoltorio, en release no se escribe nada.
void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

void _logStack({StackTrace? stackTrace}) {
  if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
}
