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
/// Responsabilidades:
///
/// 1. Mantener la lista de memorias en Riverpod.
/// 2. Cargar datos desde la caché local.
/// 3. Escuchar los cambios de Firestore.
/// 4. Guardar nuevas memorias.
/// 5. Actualizar memorias.
/// 6. Eliminar memorias.
/// 7. Mantener sincronizada la caché local.
/// 8. Mantener las memorias ordenadas de más reciente a más antigua.
///
/// Arquitectura:
///
///                  ┌──────────────────────┐
///                  │   MemoryNotifier     │
///                  │      Riverpod        │
///                  └──────────┬───────────┘
///                             │
///                ┌────────────┴────────────┐
///                │                         │
///                ▼                         ▼
///       ┌─────────────────┐      ┌────────────────────┐
///       │ StorageService  │      │ Firestore Service  │
///       │ SharedPrefs     │      │ Fuente principal   │
///       └─────────────────┘      └────────────────────┘
///
/// Firestore es la fuente principal de datos.
///
/// SharedPreferences funciona como:
///
/// - caché local
/// - carga rápida inicial
/// - respaldo temporal si Firestore tarda o falla
///
/// ===========================================================================

class MemoryNotifier extends StateNotifier<List<MemoryModel>> {
MemoryNotifier()
: _firestoreService = MemoryMapFirestoreService(),
super(<MemoryModel>[]) {
_initialize();
}

// ==========================================================================
// SERVICIO FIRESTORE
// ==========================================================================

final MemoryMapFirestoreService _firestoreService;

// ==========================================================================
// SUSCRIPCIÓN AL STREAM DE FIRESTORE
// ==========================================================================

StreamSubscription<List<MemoryModel>>? _firestoreSubscription;

// ==========================================================================
// ESTADO INTERNO
// ==========================================================================

bool _isDisposed = false;

/// Indica si ya hemos recibido al menos una respuesta válida de Firestore.
///
/// Sirve para diferenciar:
///
/// - caché local inicial
/// - datos reales recibidos desde Firestore
///
/// No se utiliza para bloquear operaciones, solo para trazabilidad.
bool _hasReceivedFirestoreData = false;

// ==========================================================================
// INICIALIZACIÓN
// ==========================================================================

/// Inicializa el notifier.
///
/// Flujo:
///
/// 1. Carga inmediatamente la caché local.
/// 2. Ordena las memorias de más reciente a más antigua.
/// 3. Comienza a escuchar Firestore.
///
/// Esto permite que la aplicación muestre datos rápidamente mientras
/// Firestore termina de responder.
Future<void> _initialize() async {
try {
debugPrint(
'🧠 MemoryNotifier: '
'iniciando inicialización...',
);


  // ======================================================================
  // PASO 1
  // CARGAR CACHÉ LOCAL
  // ======================================================================

  await _loadLocalMemories();

  if (_isDisposed) {
    return;
  }

  // ======================================================================
  // PASO 2
  // ESCUCHAR FIRESTORE
  // ======================================================================

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

/// Carga las memorias almacenadas en SharedPreferences.
///
/// Las memorias se reciben desde StorageService ya ordenadas, pero se vuelven
/// a ordenar aquí para garantizar que el estado de Riverpod siempre siga
/// la misma regla:
///
///     MÁS RECIENTE
///          ↓
///     MÁS ANTIGUA
///
/// No carga datos mock.
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

  // ======================================================================
  // NORMALIZAR
  // ======================================================================

  final List<MemoryModel> normalizedMemories =
      _normalizeMemories(
    localMemories,
  );

  // ======================================================================
  // ACTUALIZAR ESTADO
  // ======================================================================

  state = normalizedMemories;

  debugPrint(
    '🧠 MemoryNotifier: '
    'estado inicial cargado desde SharedPreferences: '
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

/// Inicia la escucha de cambios en Firestore.
///
/// El servicio Firestore debe devolver únicamente las memorias pertenecientes
/// al usuario autenticado.
///
/// Cada actualización:
///
/// 1. Elimina IDs duplicados.
/// 2. Ordena de más reciente a más antigua.
/// 3. Actualiza Riverpod.
/// 4. Actualiza la caché local.
void _listenToFirestore() {
try {
debugPrint(
'🔥 MemoryNotifier: '
'iniciando escucha de Firestore...',
);


  _firestoreSubscription =
      _firestoreService.getMemoryModelsStream().listen(
    (
      List<MemoryModel> firestoreMemories,
    ) async {
      if (_isDisposed) {
        return;
      }

      debugPrint(
        '🔥 MemoryNotifier: '
        'memorias recibidas de Firestore: '
        '${firestoreMemories.length}',
      );

      // ==================================================================
      // MARCAR QUE FIRESTORE YA RESPONDIÓ
      // ==================================================================

      _hasReceivedFirestoreData = true;

      // ==================================================================
      // NORMALIZAR
      // ==================================================================

      final List<MemoryModel> normalizedMemories =
          _normalizeMemories(
        firestoreMemories,
      );

      // ==================================================================
      // ACTUALIZAR RIVERPOD
      // ==================================================================

      if (!_isDisposed) {
        state = normalizedMemories;
      }

      debugPrint(
        '🧠 MemoryNotifier: '
        'estado actualizado desde Firestore: '
        '${normalizedMemories.length} memorias.',
      );

      // ==================================================================
      // ACTUALIZAR CACHÉ LOCAL
      // ==================================================================

      try {
        await StorageService.saveMemories(
          normalizedMemories,
        );

        debugPrint(
          '💾 MemoryNotifier: '
          'caché local sincronizada con Firestore.',
        );
      } catch (e, stack) {
        debugPrint(
          '⚠️ MemoryNotifier: '
          'no se pudo actualizar la caché local: $e',
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
        'error escuchando Firestore: $error',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      // ==================================================================
      // FALLBACK
      // ==================================================================
      //
      // No vaciamos el estado si Firestore falla.
      //
      // El estado actual puede proceder de:
      //
      // - Firestore
      // - caché local
      //
      // De esta manera la aplicación mantiene los últimos datos
      // disponibles en lugar de mostrar una pantalla vacía.
    },
  );
} catch (e, stack) {
  debugPrint(
    '❌ MemoryNotifier: '
    'no se pudo iniciar el stream de Firestore: $e',
  );

  debugPrintStack(
    stackTrace: stack,
  );
}


}

// ==========================================================================
// AÑADIR MEMORIA
// ==========================================================================

/// Añade una nueva memoria.
///
/// Flujo:
///
/// 1. Valida el ID.
/// 2. Actualiza Riverpod de forma optimista.
/// 3. Guarda en SharedPreferences.
/// 4. Guarda en Firestore.
///
/// La memoria aparece inmediatamente en la aplicación.
///
/// Después Firestore se convierte en la fuente definitiva.
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

  // ======================================================================
  // ACTUALIZACIÓN OPTIMISTA
  // ======================================================================

  final List<MemoryModel> updatedMemories =
      List<MemoryModel>.from(
    state,
  );

  final int existingIndex =
      updatedMemories.indexWhere(
    (MemoryModel memory) =>
        memory.id.trim() == normalizedId,
  );

  if (existingIndex >= 0) {
    updatedMemories[existingIndex] =
        newMemory;
  } else {
    updatedMemories.add(
      newMemory,
    );
  }

  state = _normalizeMemories(
    updatedMemories,
  );

  // ======================================================================
  // GUARDAR LOCALMENTE
  // ======================================================================

  await StorageService.saveMemory(
    newMemory,
  );

  // ======================================================================
  // GUARDAR EN FIRESTORE
  // ======================================================================

  await _firestoreService.saveMemoryModel(
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

/// Actualiza una memoria existente.
///
/// Flujo:
///
/// 1. Actualiza Riverpod.
/// 2. Ordena el resultado.
/// 3. Actualiza SharedPreferences.
/// 4. Actualiza Firestore.
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

  // ======================================================================
  // ACTUALIZAR ESTADO
  // ======================================================================

  final List<MemoryModel> updatedMemories =
      state
          .map(
            (MemoryModel memory) =>
                memory.id.trim() == normalizedId
                    ? updatedMemory
                    : memory,
          )
          .toList();

  state = _normalizeMemories(
    updatedMemories,
  );

  // ======================================================================
  // ACTUALIZAR STORAGE
  // ======================================================================

  await StorageService.updateMemory(
    updatedMemory,
  );

  // ======================================================================
  // ACTUALIZAR FIRESTORE
  // ======================================================================

  await _firestoreService.saveMemoryModel(
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

/// Elimina una memoria.
///
/// Flujo:
///
/// 1. Valida el ID.
/// 2. Elimina de Riverpod.
/// 3. Elimina de SharedPreferences.
/// 4. Elimina de Firestore.
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

  // ======================================================================
  // ACTUALIZAR ESTADO
  // ======================================================================

  state = state
      .where(
        (MemoryModel memory) =>
            memory.id.trim() != normalizedId,
      )
      .toList();

  // ======================================================================
  // ELIMINAR STORAGE
  // ======================================================================

  await StorageService.deleteMemory(
    normalizedId,
  );

  // ======================================================================
  // ELIMINAR FIRESTORE
  // ======================================================================

  await _firestoreService.deleteMemory(
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

/// Devuelve una memoria por su ID.
MemoryModel? getMemoryById(
String id,
) {
final String normalizedId =
id.trim();


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
// OBTENER MEMORIA MÁS RECIENTE
// ==========================================================================

/// Devuelve la memoria más reciente.
///
/// Como el estado se mantiene siempre ordenado, normalmente será
/// state.first.
///
/// Se mantiene este getter para que la pantalla de inicio pueda utilizarlo
/// directamente para mostrar la imagen/recuerdo más reciente.
MemoryModel? get latestMemory {
if (state.isEmpty) {
return null;
}


return state.first;


}

// ==========================================================================
// LIMPIAR MEMORIAS LOCALES
// ==========================================================================

/// Elimina todas las memorias del estado y de la caché local.
///
/// IMPORTANTE:
///
/// Este método NO elimina automáticamente las memorias de Firestore.
///
/// Firestore continúa siendo la fuente principal.
Future<void> clearLocalMemories() async {
try {
state = <MemoryModel>[];


  await StorageService.clearMemories();

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

/// Normaliza una lista de memorias.
///
/// Realiza dos operaciones:
///
/// 1. Elimina duplicados utilizando el ID como identidad.
/// 2. Ordena de más reciente a más antigua.
///
/// Esta función es el punto central para garantizar que:
///
/// - la pantalla de inicio
/// - la lista de recuerdos
/// - la caché local
/// - los datos recibidos de Firestore
///
/// utilicen exactamente el mismo orden.
List<MemoryModel> _normalizeMemories(
List<MemoryModel> memories,
) {
final Map<String, MemoryModel> uniqueMemories =
<String, MemoryModel>{};


for (final MemoryModel memory in memories) {
  final String id =
      memory.id.trim();

  if (id.isEmpty) {
    continue;
  }

  uniqueMemories[id] =
      memory;
}

final List<MemoryModel> normalizedMemories =
    uniqueMemories.values.toList();

normalizedMemories.sort(
  _compareMemoriesByDateDescending,
);

return normalizedMemories;


}

// ==========================================================================
// COMPARAR FECHAS
// ==========================================================================

/// Ordena dos memorias de más reciente a más antigua.
///
/// Resultado:
///
/// - negativo → A aparece antes que B.
/// - positivo → B aparece antes que A.
/// - cero → misma fecha.
static int _compareMemoriesByDateDescending(
MemoryModel a,
MemoryModel b,
) {
final DateTime dateA =
a.date;


final DateTime dateB =
    b.date;

return dateB.compareTo(
  dateA,
);


}

// ==========================================================================
// ESTADO DE FIRESTORE
// ==========================================================================

/// Indica si Firestore ya ha enviado al menos una respuesta.
///
/// Puede ser útil posteriormente para mostrar estados como:
///
/// - "Cargando recuerdos..."
/// - "Mostrando recuerdos guardados localmente..."
/// - "Sincronizado"
bool get hasReceivedFirestoreData {
return _hasReceivedFirestoreData;
}

// ==========================================================================
// DISPOSE
// ==========================================================================

@override
void dispose() {
_isDisposed = true;

_firestoreSubscription?.cancel();

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
//
// Valores esperados:
//
// - Todos
// - Croquetas
// - Ensaladilla
// - Restaurantes
// - etc.
//
// El filtro real debe aplicarse en el selector que consume este provider.
// Aquí únicamente se mantiene la categoría seleccionada globalmente.
//

final selectedCategoryProvider =
StateProvider<String>(
(ref) => 'Todos',
);
