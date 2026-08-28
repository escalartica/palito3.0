import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/services/memory_map_firestore_service.dart';

/// Resuelve y cachea las coordenadas geográficas de los recuerdos
/// mostrados en el mapa.
///
/// Encapsula:
///
/// - La resolución de coordenadas por recuerdo, con prioridad:
///   1. Coordenadas directas en `memory.location`.
///   2. Location legacy asociada (por `id` o `memoryId`).
///   3. Caché de geocodificación por dirección.
///   4. Geocodificación (`locationFromAddress`) contra el paquete
///      `geocoding`.
/// - La geocodificación inversa usada para mostrar un nombre de
///   ubicación legible en la hoja de detalle de un recuerdo.
/// - La firma de los datos procesados, para evitar volver a resolver
///   coordenadas cuando la lista de recuerdos no ha cambiado.
///
/// No conoce nada de widgets: `_MapPageState` mantiene una instancia y
/// llama a sus métodos, pasándole mediante callbacks lo que necesita
/// para actualizar la UI (comprobar si sigue montado, reconstruir,
/// reencuadrar la cámara).
class MemoryGeocodingService {
  MemoryGeocodingService({
    required MemoryMapFirestoreService firestoreService,
  }) : _firestoreService = firestoreService;

  /// Inyectable para tests; en producción, la misma instancia compartida
  /// que expone `memoryMapServiceProvider`.
  final MemoryMapFirestoreService _firestoreService;

  /// Caché de geocodificación por dirección.
  ///
  /// La clave es la dirección normalizada.
  ///
  /// Esta caché NO identifica recuerdos.
  /// Dos recuerdos distintos pueden compartir una coordenada.
  final Map<String, LatLng> geocodedCache = {};

  /// Coordenada final asociada a cada recuerdo.
  ///
  /// La clave SIEMPRE es memory.id.
  final Map<String, LatLng> memoryCoordinates = {};

  /// IDs actualmente en proceso de resolución.
  final Set<String> resolvingMemoryIds = {};

  /// Firma de los datos procesados.
  String _lastProcessedSignature = '';

  /// Indica si existe una resolución global en curso.
  bool _isResolvingCoordinates = false;

  /// Generación de resolución.
  int _coordinateResolutionGeneration = 0;

  // ============================================================
  // FIRMA DE DATOS
  // ============================================================

  String _buildMemorySignature(
    List<MemoryModel> memories,
  ) {
    final sortedMemories =
        List<MemoryModel>.from(
      memories,
    )..sort(
        (a, b) => a.id.compareTo(b.id),
      );

    return sortedMemories
        .map(
          (memory) =>
              '${memory.id}:'
              '${memory.location.lat}:'
              '${memory.location.lng}:'
              '${memory.location.address}:'
              '${memory.category}:'
              '${memory.title}:'
              '${memory.rating}:'
              '${memory.wouldReturn}',
        )
        .join('|');
  }

  /// Indica si `memories` difiere de la última tanda procesada y, en ese
  /// caso, actualiza la firma recordada para la próxima comprobación.
  bool shouldResolve(
    List<MemoryModel> memories,
  ) {
    final signature = _buildMemorySignature(
      memories,
    );

    if (_lastProcessedSignature == signature) {
      return false;
    }

    _lastProcessedSignature = signature;

    return true;
  }

  // ============================================================
  // INDEXACIÓN LOCATIONS LEGACY
  // ============================================================

  Map<String, Map<String, dynamic>> _indexLocations(
    List<Map<String, dynamic>> locations,
  ) {
    final Map<String, Map<String, dynamic>> result = {};

    for (final location in locations) {
      final id = location['id']
          ?.toString()
          .trim();

      if (id != null && id.isNotEmpty) {
        result['id:$id'] = location;
      }

      final memoryId =
          location['memoryId']
                  ?.toString()
                  .trim() ??
              location['memory_id']
                  ?.toString()
                  .trim() ??
              location['memoryID']
                  ?.toString()
                  .trim();

      if (memoryId != null &&
          memoryId.isNotEmpty) {
        result['memory:$memoryId'] =
            location;
      }
    }

    return result;
  }

  Map<String, dynamic>? _findLocationForMemory(
    MemoryModel memory,
    Map<String, Map<String, dynamic>> locationsByKey,
  ) {
    final byId =
        locationsByKey['id:${memory.id}'];

    if (byId != null) {
      return byId;
    }

    final byMemoryId =
        locationsByKey['memory:${memory.id}'];

    if (byMemoryId != null) {
      return byMemoryId;
    }

    return null;
  }

  // ============================================================
  // UTILIDADES
  // ============================================================

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _normalizeAddress(String address) {
    return address
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isValidCoordinate(
    double? lat,
    double? lng,
  ) {
    if (lat == null || lng == null) {
      return false;
    }

    if (!lat.isFinite || !lng.isFinite) {
      return false;
    }

    if (lat < -90 || lat > 90) {
      return false;
    }

    if (lng < -180 || lng > 180) {
      return false;
    }

    return true;
  }

  double? _parseCoordinate(dynamic value) {
    if (value is num) {
      final result = value.toDouble();

      return result.isFinite
          ? result
          : null;
    }

    if (value is String) {
      final result = double.tryParse(
        value.trim(),
      );

      if (result != null && result.isFinite) {
        return result;
      }
    }

    return null;
  }

  // ============================================================
  // RESOLUCIÓN DE COORDENADAS
  // ============================================================

  /// Resuelve las coordenadas de todos los `memories`, usando
  /// `locations` como fallback legacy y cacheando por dirección.
  ///
  /// - `isActive` sustituye a `!_isDisposed && mounted`: se comprueba
  ///   repetidamente durante la resolución (que puede tardar, al hacer
  ///   llamadas de red) para abortar en cuanto el widget deje de estar
  ///   activo.
  /// - `onCoordinatesUpdated` se invoca una vez resueltas las
  ///   coordenadas, para que el llamador reconstruya la UI
  ///   (`setState`).
  /// - `onCameraFitNeeded` se invoca después, en el frame siguiente,
  ///   para que el llamador reencuadre la cámara sobre los recuerdos
  ///   filtrados.
  Future<void> resolveAllCoordinates(
    List<MemoryModel> memories,
    List<Map<String, dynamic>> locations, {
    required bool Function() isActive,
    required VoidCallback onCoordinatesUpdated,
    required void Function(List<MemoryModel> memories) onCameraFitNeeded,
  }) async {
    if (!isActive()) {
      return;
    }

    if (_isResolvingCoordinates) {
      debugPrint(
        '🗺️ Ya hay una resolución de coordenadas en curso.',
      );

      return;
    }

    _isResolvingCoordinates = true;

    final int generation =
        ++_coordinateResolutionGeneration;

    debugPrint(
      '============================================================',
    );

    debugPrint(
      '🗺️ INICIANDO RESOLUCIÓN DE COORDENADAS',
    );

    debugPrint(
      '🗺️ Generación: $generation',
    );

    debugPrint(
      '🗺️ Memories recibidas: ${memories.length}',
    );

    debugPrint(
      '📍 Locations legacy recibidas: ${locations.length}',
    );

    debugPrint(
      '============================================================',
    );

    try {
      final locationsByKey =
          _indexLocations(
        locations,
      );

      // ----------------------------------------------------------
      // LIMPIAR MEMORIAS ELIMINADAS
      // ----------------------------------------------------------

      final currentMemoryIds = memories
          .map(
            (memory) => memory.id.trim(),
          )
          .where(
            (id) => id.isNotEmpty,
          )
          .toSet();

      memoryCoordinates.removeWhere(
        (id, _) =>
            !currentMemoryIds.contains(id),
      );

      resolvingMemoryIds.removeWhere(
        (id) =>
            !currentMemoryIds.contains(id),
      );

      // ----------------------------------------------------------
      // PROCESAR MEMORIAS
      // ----------------------------------------------------------

      for (final memory in memories) {
        if (!isActive()) {
          return;
        }

        if (generation !=
            _coordinateResolutionGeneration) {
          debugPrint(
            '🗺️ Resolución antigua invalidada.',
          );

          return;
        }

        final memoryId =
            memory.id.trim();

        if (memoryId.isEmpty) {
          debugPrint(
            '⚠️ Recuerdo ignorado porque no tiene ID.',
          );

          continue;
        }

        if (memoryCoordinates.containsKey(
          memoryId,
        )) {
          continue;
        }

        if (resolvingMemoryIds.contains(
          memoryId,
        )) {
          continue;
        }

        resolvingMemoryIds.add(
          memoryId,
        );

        try {
          LatLng? coordinates;

          debugPrint(
            '------------------------------------------------------------',
          );

          debugPrint(
            '📌 PROCESANDO MEMORY',
          );

          debugPrint(
            '📌 ID: $memoryId',
          );

          debugPrint(
            '📌 Título: ${memory.title}',
          );

          debugPrint(
            '📌 Dirección: "${memory.location.address}"',
          );

          debugPrint(
            '📌 Lat: ${memory.location.lat}',
          );

          debugPrint(
            '📌 Lng: ${memory.location.lng}',
          );

          // ------------------------------------------------------
          // 1. COORDENADAS DIRECTAS
          // ------------------------------------------------------

          if (_isValidCoordinate(
            memory.location.lat,
            memory.location.lng,
          )) {
            coordinates = LatLng(
              memory.location.lat!,
              memory.location.lng!,
            );

            memoryCoordinates[
              memoryId
            ] = coordinates;

            debugPrint(
              '✅ [$memoryId] '
              'Coordenadas desde memory.location.',
            );

            continue;
          }

          // ------------------------------------------------------
          // 2. FALLBACK LEGACY
          // ------------------------------------------------------

          final locationData =
              _findLocationForMemory(
            memory,
            locationsByKey,
          );

          if (locationData != null) {
            debugPrint(
              '📍 [$memoryId] '
              'Encontrada location legacy asociada.',
            );

            final lat = _parseCoordinate(
              locationData['lat'],
            );

            final lng = _parseCoordinate(
              locationData['lng'],
            );

            if (_isValidCoordinate(
              lat,
              lng,
            )) {
              coordinates = LatLng(
                lat!,
                lng!,
              );

              memoryCoordinates[
                memoryId
              ] = coordinates;

              debugPrint(
                '✅ [$memoryId] '
                'Coordenadas desde locations legacy.',
              );

              continue;
            }
          }

          // ------------------------------------------------------
          // 3. CACHÉ POR DIRECCIÓN
          // ------------------------------------------------------

          final address =
              memory.location.address.trim();

          if (address.isNotEmpty) {
            final cacheKey =
                _normalizeAddress(
              address,
            );

            final cachedCoordinates =
                geocodedCache[
                  cacheKey
                ];

            if (cachedCoordinates != null) {
              memoryCoordinates[
                memoryId
              ] = cachedCoordinates;

              debugPrint(
                '✅ [$memoryId] '
                'Coordenadas recuperadas desde caché.',
              );

              continue;
            }
          }

          // ------------------------------------------------------
          // 4. GEOCODIFICACIÓN
          // ------------------------------------------------------

          if (address.isEmpty) {
            debugPrint(
              '⚠️ [$memoryId] '
              'No tiene dirección para geocodificar.',
            );

            continue;
          }

          String query = address;

          final normalizedAddress =
              _normalize(address);

          if (normalizedAddress ==
              'medellin') {
            query =
                'Medellín, Badajoz, España';
          }

          final normalizedQuery =
              _normalize(query);

          if (!normalizedQuery.contains(
                'espana',
              ) &&
              !normalizedQuery.contains(
                'spain',
              )) {
            query =
                '$query, España';
          }

          debugPrint(
            '🔎 [$memoryId] '
            'Geocodificando: "$query"',
          );

          try {
            final results =
                await locationFromAddress(
              query,
            );

            if (!isActive()) {
              return;
            }

            if (generation !=
                _coordinateResolutionGeneration) {
              return;
            }

            if (results.isEmpty) {
              debugPrint(
                '⚠️ [$memoryId] '
                'No se encontraron resultados.',
              );

              continue;
            }

            LatLng? resolvedCoordinates;

            for (final result in results) {
              if (_isValidCoordinate(
                result.latitude,
                result.longitude,
              )) {
                resolvedCoordinates =
                    LatLng(
                  result.latitude,
                  result.longitude,
                );

                break;
              }
            }

            if (resolvedCoordinates == null) {
              debugPrint(
                '⚠️ [$memoryId] '
                'Todos los resultados fueron inválidos.',
              );

              continue;
            }

            coordinates =
                resolvedCoordinates;

            final cacheKey =
                _normalizeAddress(
              address,
            );

            geocodedCache[
              cacheKey
            ] = coordinates;

            memoryCoordinates[
              memoryId
            ] = coordinates;

            debugPrint(
              '✅ [$memoryId] '
              'Geocodificación correcta.',
            );

            debugPrint(
              '📍 ${coordinates.latitude}, '
              '${coordinates.longitude}',
            );

            // Persistimos el resultado en el propio recuerdo para no
            // tener que repetir esta llamada de geocodificación en cada
            // arranque — la próxima vez, "1. COORDENADAS DIRECTAS" (más
            // arriba) la resolverá sin red. Si falla (sin conexión,
            // etc.) no afecta a la resolución actual, que ya tiene sus
            // coordenadas en memoria: solo se repetirá la geocodificación
            // la próxima vez.
            unawaited(
              _firestoreService
                  .updateMemoryCoordinates(
                memoryId: memoryId,
                lat: coordinates.latitude,
                lng: coordinates.longitude,
              ).catchError((Object e) {
                debugPrint(
                  '⚠️ [$memoryId] '
                  'No se pudieron guardar las coordenadas '
                  'geocodificadas: $e',
                );
              }),
            );
          } catch (e, stack) {
            debugPrint(
              '❌ [$memoryId] '
              'Error geocodificando "$query": $e',
            );

            debugPrintStack(
              stackTrace: stack,
            );
          }
        } finally {
          resolvingMemoryIds.remove(
            memoryId,
          );
        }
      }

      if (!isActive()) {
        return;
      }

      if (generation !=
          _coordinateResolutionGeneration) {
        return;
      }

      debugPrint(
        '============================================================',
      );

      debugPrint(
        '🗺️ COORDENADAS RESUELTAS',
      );

      debugPrint(
        '🗺️ ${memoryCoordinates.length}/${memories.length}',
      );

      debugPrint(
        '🗺️ Caché geocodificación: '
        '${geocodedCache.length}',
      );

      debugPrint(
        '============================================================',
      );

      onCoordinatesUpdated();

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          if (!isActive()) {
            return;
          }

          if (generation !=
              _coordinateResolutionGeneration) {
            return;
          }

          onCameraFitNeeded(
            memories,
          );
        },
      );
    } finally {
      _isResolvingCoordinates = false;
    }
  }

  // ============================================================
  // NOMBRE DE UBICACIÓN
  // ============================================================

  Future<String> resolveLocationName(
    double lat,
    double lng,
    String currentAddress,
  ) async {
    final normalizedAddress =
        currentAddress.trim();

    if (normalizedAddress.isNotEmpty &&
        !normalizedAddress.startsWith(
          'GPS:',
        ) &&
        !normalizedAddress.startsWith(
          'Lat:',
        ) &&
        normalizedAddress.length > 3) {
      return normalizedAddress;
    }

    try {
      final placemarks =
          await placemarkFromCoordinates(
        lat,
        lng,
      );

      if (placemarks.isNotEmpty) {
        final place =
            placemarks.first;

        final locality =
            place.locality ??
                place.subAdministrativeArea ??
                place.administrativeArea ??
                '';

        final subLocality =
            place.subLocality ?? '';

        if (locality.isNotEmpty) {
          return subLocality.isNotEmpty &&
                  subLocality != locality
              ? '$subLocality, $locality'
              : locality;
        }
      }
    } catch (e) {
      debugPrint(
        '⚠️ Error obteniendo nombre de ubicación: $e',
      );
    }

    return normalizedAddress.isNotEmpty
        ? normalizedAddress
        : 'Ubicación GPS '
            '(${lat.toStringAsFixed(2)}, '
            '${lng.toStringAsFixed(2)})';
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  /// Libera el estado acumulado por el servicio.
  ///
  /// Incrementa la generación de resolución para invalidar cualquier
  /// resolución en curso y limpia las cachés.
  void dispose() {
    _coordinateResolutionGeneration++;

    resolvingMemoryIds.clear();

    memoryCoordinates.clear();

    geocodedCache.clear();
  }
}
