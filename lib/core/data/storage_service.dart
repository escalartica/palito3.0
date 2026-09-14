import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory_model.dart';

/// ===========================================================================
/// STORAGE SERVICE
/// ===========================================================================
///
/// Servicio encargado del almacenamiento local de las memorias.
///
/// Utiliza SharedPreferences como caché local.
///
/// Estructura:
///
/// SharedPreferences
///      │
///      └── memories_data
///              │
///              └── JSON
///                    │
///                    └── List<MemoryModel
///
/// Este servicio NO se encarga de Firestore.
///
/// Firestore se gestiona mediante los servicios correspondientes.
///
/// La sincronización entre:
///
/// - almacenamiento local
/// - Firestore
///
/// es responsabilidad del MemoryNotifier.
///
/// ===========================================================================

class StorageService {
  StorageService._();

  // ==========================================================================
  // CONFIGURACIÓN
  // ==========================================================================

  static const String _key = 'memories_data';

  // ==========================================================================
  // GUARDAR TODAS LAS MEMORIAS
  // ==========================================================================

  /// Guarda la lista completa de memorias en SharedPreferences.
  ///
  /// Las memorias se guardan siempre ordenadas:
  ///
  ///     MÁS RECIENTE
  ///          ↓
  ///     MÁS ANTIGUA
  ///
  /// La serialización se realiza mediante MemoryModel.toJson().
  ///
  /// El MemoryModel debe encargarse de convertir DateTime a String
  /// ISO-8601 y de convertir los campos anidados a estructuras compatibles
  /// con JSON.
  static Future<void> saveMemories(List<MemoryModel> memories) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // ----------------------------------------------------------------------
      // CREAR COPIA
      // ----------------------------------------------------------------------
      //
      // No modificamos la lista original recibida.
      //
      final List<MemoryModel> sortedMemories = List<MemoryModel>.from(memories);

      // ----------------------------------------------------------------------
      // ORDENAR MÁS RECIENTE → MÁS ANTIGUA
      // ----------------------------------------------------------------------

      sortedMemories.sort(_compareMemoriesByDateDescending);

      // ----------------------------------------------------------------------
      // CONVERTIR MODELOS A MAPS JSON-SAFE
      // ----------------------------------------------------------------------
      //
      // MemoryModel.toJson() debe devolver:
      //
      // 'date': date.toIso8601String()
      //
      // y no:
      //
      // 'date': date
      //
      // De esta forma jsonEncode() no recibe ningún DateTime directamente.
      //
      final List<Map<String, dynamic>> memoryMaps = sortedMemories.map((
        MemoryModel memory,
      ) {
        final Map<String, dynamic> json = memory.toJson();

        // Protección adicional:
        //
        // Aunque MemoryModel.toJson() debería ser JSON-safe,
        // normalizamos recursivamente cualquier valor que pudiera
        // contener accidentalmente un DateTime dentro de
        // specificFields u otra estructura anidada.
        final dynamic normalized = _makeJsonEncodable(json);

        if (normalized is! Map<String, dynamic>) {
          throw const FormatException(
            'MemoryModel.toJson() '
            'no devolvió un Map<String, dynamic> válido.',
          );
        }

        return normalized;
      }).toList();

      // ----------------------------------------------------------------------
      // CONVERTIR A JSON
      // ----------------------------------------------------------------------

      final String encodedData = jsonEncode(memoryMaps);

      // ----------------------------------------------------------------------
      // GUARDAR EN SHAREDPREFERENCES
      // ----------------------------------------------------------------------

      final bool saved = await prefs.setString(_key, encodedData);

      if (!saved) {
        throw Exception('SharedPreferences no pudo guardar memories_data.');
      }

      _log(
        '💾 StorageService: '
        '${sortedMemories.length} memorias guardadas localmente.',
      );
    } catch (e, stack) {
      _log(
        '❌ StorageService: '
        'error guardando memorias: $e',
      );

      _logStack(stackTrace: stack);

      rethrow;
    }
  }

  // ==========================================================================
  // CARGAR TODAS LAS MEMORIAS
  // ==========================================================================

  /// Carga todas las memorias almacenadas localmente.
  ///
  /// Devuelve:
  ///
  /// [] si:
  ///
  /// - no existe información guardada
  /// - el JSON está vacío
  /// - el JSON no tiene formato válido
  /// - ocurre un error de lectura
  ///
  /// Las memorias individuales que no puedan convertirse correctamente
  /// se ignoran para evitar que una memoria corrupta bloquee todas las demás.
  ///
  /// El resultado se devuelve ordenado:
  ///
  ///     MÁS RECIENTE
  ///          ↓
  ///     MÁS ANTIGUA
  static Future<List<MemoryModel>> loadMemories() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // ----------------------------------------------------------------------
      // OBTENER JSON
      // ----------------------------------------------------------------------

      final String? encodedData = prefs.getString(_key);

      if (encodedData == null || encodedData.trim().isEmpty) {
        _log(
          '💾 StorageService: '
          'no hay memorias almacenadas localmente.',
        );

        return <MemoryModel>[];
      }

      // ----------------------------------------------------------------------
      // DECODIFICAR JSON
      // ----------------------------------------------------------------------

      final dynamic decodedData = jsonDecode(encodedData);

      if (decodedData is! List) {
        _log(
          '⚠️ StorageService: '
          'los datos almacenados no tienen formato de lista.',
        );

        return <MemoryModel>[];
      }

      // ----------------------------------------------------------------------
      // CONVERTIR CADA MEMORIA
      // ----------------------------------------------------------------------

      final List<MemoryModel> memories = <MemoryModel>[];

      for (final dynamic item in decodedData) {
        try {
          if (item is! Map) {
            _log(
              '⚠️ StorageService: '
              'se encontró un elemento inválido '
              'en memories_data.',
            );

            continue;
          }

          final Map<String, dynamic> memoryMap = Map<String, dynamic>.from(
            item,
          );

          final MemoryModel memory = MemoryModel.fromMap(memoryMap);

          // ---------------------------------------------------------------
          // VALIDAR ID
          // ---------------------------------------------------------------

          if (memory.id.trim().isEmpty) {
            _log(
              '⚠️ StorageService: '
              'se ignoró una memoria sin ID.',
            );

            continue;
          }

          memories.add(memory);
        } catch (e, stack) {
          _log(
            '❌ StorageService: '
            'error procesando una memoria almacenada: $e',
          );

          _logStack(stackTrace: stack);
        }
      }

      // ----------------------------------------------------------------------
      // ORDENAR MÁS RECIENTE → MÁS ANTIGUA
      // ----------------------------------------------------------------------

      memories.sort(_compareMemoriesByDateDescending);

      _log(
        '💾 StorageService: '
        '${memories.length} memorias cargadas '
        'desde almacenamiento local.',
      );

      return memories;
    } catch (e, stack) {
      _log(
        '❌ StorageService: '
        'error cargando memorias: $e',
      );

      _logStack(stackTrace: stack);

      return <MemoryModel>[];
    }
  }

  // ==========================================================================
  // GUARDAR UNA MEMORIA
  // ==========================================================================

  /// Guarda o actualiza una única memoria.
  ///
  /// Si ya existe una memoria con el mismo ID:
  ///
  ///     se actualiza.
  ///
  /// Si no existe:
  ///
  ///     se añade.
  ///
  /// La lista completa se guarda posteriormente ordenada de:
  ///
  ///     más reciente → más antigua
  static Future<void> saveMemory(MemoryModel memory) async {
    try {
      final List<MemoryModel> memories = await loadMemories();

      final int existingIndex = memories.indexWhere(
        (MemoryModel item) => item.id == memory.id,
      );

      if (existingIndex >= 0) {
        // ---------------------------------------------------------------
        // ACTUALIZAR
        // ---------------------------------------------------------------

        memories[existingIndex] = memory;

        _log(
          '💾 StorageService: '
          'memoria actualizada localmente: ${memory.id}',
        );
      } else {
        // ---------------------------------------------------------------
        // AÑADIR
        // ---------------------------------------------------------------

        memories.add(memory);

        _log(
          '💾 StorageService: '
          'nueva memoria guardada localmente: ${memory.id}',
        );
      }

      // --------------------------------------------------------------------
      // GUARDAR LISTA COMPLETA
      // --------------------------------------------------------------------

      await saveMemories(memories);
    } catch (e, stack) {
      _log(
        '❌ StorageService: '
        'error guardando memoria ${memory.id}: $e',
      );

      _logStack(stackTrace: stack);

      rethrow;
    }
  }

  // ==========================================================================
  // ELIMINAR UNA MEMORIA
  // ==========================================================================

  /// Elimina una memoria del almacenamiento local.
  ///
  /// Si no existe, no genera error.
  static Future<void> deleteMemory(String memoryId) async {
    try {
      final String normalizedId = memoryId.trim();

      if (normalizedId.isEmpty) {
        _log(
          '⚠️ StorageService: '
          'no se puede eliminar una memoria sin ID.',
        );

        return;
      }

      final List<MemoryModel> memories = await loadMemories();

      final int originalLength = memories.length;

      memories.removeWhere((MemoryModel memory) => memory.id == normalizedId);

      if (memories.length == originalLength) {
        _log(
          '⚠️ StorageService: '
          'no se encontró la memoria local $normalizedId.',
        );

        return;
      }

      await saveMemories(memories);

      _log(
        '🗑️ StorageService: '
        'memoria eliminada localmente: $normalizedId',
      );
    } catch (e, stack) {
      _log(
        '❌ StorageService: '
        'error eliminando memoria $memoryId: $e',
      );

      _logStack(stackTrace: stack);

      rethrow;
    }
  }

  // ==========================================================================
  // ACTUALIZAR UNA MEMORIA
  // ==========================================================================

  /// Actualiza una memoria existente.
  ///
  /// Es un alias explícito de saveMemory().
  ///
  /// Si la memoria no existe, se añadirá.
  static Future<void> updateMemory(MemoryModel memory) async {
    await saveMemory(memory);
  }

  // ==========================================================================
  // LIMPIAR TODAS LAS MEMORIAS
  // ==========================================================================

  /// Elimina todas las memorias almacenadas localmente.
  ///
  /// IMPORTANTE:
  ///
  /// Este método solo elimina la copia local.
  ///
  /// NO elimina memorias de Firestore.
  static Future<void> clearMemories() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.remove(_key);

      _log(
        '🧹 StorageService: '
        'todas las memorias locales han sido eliminadas.',
      );
    } catch (e, stack) {
      _log(
        '❌ StorageService: '
        'error limpiando memorias locales: $e',
      );

      _logStack(stackTrace: stack);

      rethrow;
    }
  }

  // ==========================================================================
  // COMPROBAR SI EXISTEN MEMORIAS LOCALES
  // ==========================================================================

  /// Comprueba si existen memorias guardadas localmente.
  static Future<bool> hasMemories() async {
    try {
      final List<MemoryModel> memories = await loadMemories();

      return memories.isNotEmpty;
    } catch (e) {
      _log(
        '⚠️ StorageService: '
        'error comprobando memorias locales: $e',
      );

      return false;
    }
  }

  // ==========================================================================
  // NORMALIZAR OBJETOS PARA JSON
  // ==========================================================================

  /// Convierte recursivamente un objeto en una estructura compatible
  /// con jsonEncode().
  ///
  /// Tipos soportados:
  ///
  /// - null
  /// - String
  /// - num
  /// - bool
  /// - DateTime
  /// - Map
  /// - Iterable
  ///
  /// DateTime se convierte automáticamente a String ISO-8601.
  ///
  /// Esta capa funciona como protección adicional para evitar que un
  /// DateTime escondido dentro de specificFields provoque:
  ///
  ///     Converting object to an encodable object failed
  static dynamic _makeJsonEncodable(dynamic value) {
    // ------------------------------------------------------------------------
    // NULL
    // ------------------------------------------------------------------------

    if (value == null) {
      return null;
    }

    // ------------------------------------------------------------------------
    // TIPOS JSON NATIVOS
    // ------------------------------------------------------------------------

    if (value is String || value is num || value is bool) {
      return value;
    }

    // ------------------------------------------------------------------------
    // DATETIME
    // ------------------------------------------------------------------------

    if (value is DateTime) {
      return value.toIso8601String();
    }

    // ------------------------------------------------------------------------
    // MAP
    // ------------------------------------------------------------------------

    if (value is Map) {
      final Map<String, dynamic> result = <String, dynamic>{};

      value.forEach((dynamic key, dynamic nestedValue) {
        result[key.toString()] = _makeJsonEncodable(nestedValue);
      });

      return result;
    }

    // ------------------------------------------------------------------------
    // ITERABLE / LIST / SET
    // ------------------------------------------------------------------------

    if (value is Iterable) {
      return value.map((dynamic item) => _makeJsonEncodable(item)).toList();
    }

    // ------------------------------------------------------------------------
    // TIPO NO SOPORTADO
    // ------------------------------------------------------------------------

    throw FormatException(
      'Objeto no serializable encontrado en '
      'StorageService: ${value.runtimeType}',
    );
  }

  // ==========================================================================
  // ORDENAR MEMORIAS POR FECHA
  // ==========================================================================

  /// Ordena las memorias de:
  ///
  ///     MÁS RECIENTE → MÁS ANTIGUA
  ///
  /// MemoryModel.date es DateTime, por lo que podemos comparar directamente.
  static int _compareMemoriesByDateDescending(MemoryModel a, MemoryModel b) {
    return b.date.compareTo(a.date);
  }
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
