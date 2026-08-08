import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/providers/memory_map_provider.dart';
import '../../../../../core/models/memory_model.dart';

class MapPage extends ConsumerStatefulWidget {
  final String? initialCategory;

  const MapPage({
    super.key,
    this.initialCategory,
  });

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage>
    with TickerProviderStateMixin {
  // ============================================================
  // CONSTANTES
  // ============================================================

  static const LatLng _peninsulaCenter =
      LatLng(40.4168, -3.7038);

  static const double _peninsulaZoom = 6.2;

  static const Duration _cameraAnimationDuration =
      Duration(milliseconds: 750);

  static const Duration _spiderfyAnimationDuration =
      Duration(milliseconds: 280);

  // Distancia visual aproximada del spiderfy en grados.
  //
  // No representa una distancia geográfica real.
  // Su función es únicamente separar visualmente los recuerdos
  // que comparten coordenadas.
  static const double _spiderfyRadiusSmall = 0.00022;
  static const double _spiderfyRadiusMedium = 0.00030;
  static const double _spiderfyRadiusLarge = 0.00038;

  // ============================================================
  // ESTADO
  // ============================================================

  String? _selectedCategory;

  final MapController _mapController = MapController();

  /// Caché de geocodificación por dirección.
  ///
  /// La clave es la dirección normalizada.
  ///
  /// Esta caché NO identifica recuerdos.
  /// Dos recuerdos distintos pueden compartir una coordenada.
  final Map<String, LatLng> _geocodedCache = {};

  /// Coordenada final asociada a cada recuerdo.
  ///
  /// La clave SIEMPRE es memory.id.
  final Map<String, LatLng> _memoryCoordinates = {};

  /// IDs actualmente en proceso de resolución.
  final Set<String> _resolvingMemoryIds = {};

  /// Firma de los datos procesados.
  String _lastProcessedSignature = '';

  /// Controlador de animación de cámara.
  AnimationController? _cameraAnimationController;

  /// Controlador de animación del spiderfy.
  AnimationController? _spiderfyAnimationController;

  /// Indica si existe una resolución global en curso.
  bool _isResolvingCoordinates = false;

  /// Evita múltiples ajustes de cámara simultáneos.
  bool _isFittingCamera = false;

  /// Control de ciclo de vida.
  bool _isDisposed = false;

  /// Generación de resolución.
  int _coordinateResolutionGeneration = 0;

  /// IDs de grupos actualmente abiertos mediante spiderfy.
  ///
  /// La clave es la firma de coordenadas:
  ///
  /// latitude_longitude
  final Set<String> _expandedSpiderfyGroups = {};

  /// Indica si el usuario está interactuando con el mapa.
  ///
  /// Sirve para evitar que un ajuste automático de cámara
  /// interfiera con la navegación manual.
  bool _isUserInteractingWithMap = false;

  final List<String> _filterCategories = [
    'Todas',
    'Croquetas',
    'Ensaladilla',
    'Tortilla',
    'Menú',
    'Plato estrella',
    'Postre/Helados',
    'Decoración/Espacio',
    'Atención',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _selectedCategory = widget.initialCategory;

    debugPrint('🗺️ MAP PAGE INIT');
    debugPrint(
      '🗺️ Categoría inicial: $_selectedCategory',
    );
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

  bool _matchesCategory(
    MemoryModel memory,
    String? filter,
  ) {
    if (filter == null || filter == 'Todas') {
      return true;
    }

    final memoryCat = _normalize(
      memory.category,
    );

    final filterCat = _normalize(
      filter,
    );

    if (memoryCat == filterCat) {
      return true;
    }

    if (filterCat.contains('postre') &&
        (memoryCat.contains('postre') ||
            memoryCat.contains('helado'))) {
      return true;
    }

    if (filterCat.contains('decoracion') &&
        (memoryCat.contains('decoracion') ||
            memoryCat.contains('espacio'))) {
      return true;
    }

    if (filterCat.contains('menu') &&
        memoryCat.contains('menu')) {
      return true;
    }

    if (filterCat.contains('plato') &&
        memoryCat.contains('plato')) {
      return true;
    }

    return false;
  }

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
  // RESOLUCIÓN DE COORDENADAS
  // ============================================================

  Future<void> _resolveAllCoordinates(
    List<MemoryModel> memories,
    List<Map<String, dynamic>> locations,
  ) async {
    if (_isDisposed || !mounted) {
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

      _memoryCoordinates.removeWhere(
        (id, _) =>
            !currentMemoryIds.contains(id),
      );

      _resolvingMemoryIds.removeWhere(
        (id) =>
            !currentMemoryIds.contains(id),
      );

      // ----------------------------------------------------------
      // PROCESAR MEMORIAS
      // ----------------------------------------------------------

      for (final memory in memories) {
        if (_isDisposed || !mounted) {
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

        if (_memoryCoordinates.containsKey(
          memoryId,
        )) {
          continue;
        }

        if (_resolvingMemoryIds.contains(
          memoryId,
        )) {
          continue;
        }

        _resolvingMemoryIds.add(
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

            _memoryCoordinates[
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

              _memoryCoordinates[
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
                _geocodedCache[
                  cacheKey
                ];

            if (cachedCoordinates != null) {
              _memoryCoordinates[
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

            if (_isDisposed || !mounted) {
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

            _geocodedCache[
              cacheKey
            ] = coordinates;

            _memoryCoordinates[
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
          _resolvingMemoryIds.remove(
            memoryId,
          );
        }
      }

      if (_isDisposed || !mounted) {
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
        '🗺️ ${_memoryCoordinates.length}/${memories.length}',
      );

      debugPrint(
        '🗺️ Caché geocodificación: '
        '${_geocodedCache.length}',
      );

      debugPrint(
        '============================================================',
      );

      if (mounted && !_isDisposed) {
        setState(() {});
      }

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          if (_isDisposed || !mounted) {
            return;
          }

          if (generation !=
              _coordinateResolutionGeneration) {
            return;
          }

          if (_isUserInteractingWithMap) {
            return;
          }

          _fitMapToFilteredMemories(
            memories,
            animated: true,
          );
        },
      );
    } finally {
      _isResolvingCoordinates = false;
    }
  }

  // ============================================================
  // SPIDERFY
  // ============================================================

  String _buildCoordinateGroupKey(
    LatLng point,
  ) {
    return '${point.latitude.toStringAsFixed(6)}_'
        '${point.longitude.toStringAsFixed(6)}';
  }

  // Un marcador de grupo abre una hoja con la lista de recuerdos en ese
  // punto en vez de "spiderfy" (expandir espacialmente los marcadores):
  // en un mapa con marcadores cercanos entre sí, el toque para elegir uno
  // de los marcadores expandidos coincidía con el gesto de pointer-down
  // del propio mapa, que los volvía a colapsar antes de registrar el tap.
  // Una lista es además más accesible y profesional que depender de la
  // precisión táctil sobre marcadores diminutos.
  void _showMemoryGroupPicker(
    List<MemoryModel> memories,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFDF5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF0F172A), width: 3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '${memories.length} recuerdos en este lugar',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Elige cuál quieres ver',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: memories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final memory = memories[index];
                    return _buildGroupPickerRow(
                      memory,
                      _getCategoryColor(memory.category),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupPickerRow(
    MemoryModel memory,
    Color categoryColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          _onMarkerTapped(memory);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0F172A), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF0F172A),
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0F172A),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.restaurant_rounded,
                  color: categoryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      memory.category,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    memory.rating.toStringAsFixed(1),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF0F172A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _closeAllSpiderfyGroups() {
    if (_expandedSpiderfyGroups.isEmpty) {
      return;
    }

    if (!mounted || _isDisposed) {
      return;
    }

    setState(() {
      _expandedSpiderfyGroups.clear();
    });
  }

  double _getSpiderfyRadius(
    int count,
  ) {
    if (count <= 3) {
      return _spiderfyRadiusSmall;
    }

    if (count <= 6) {
      return _spiderfyRadiusMedium;
    }

    return _spiderfyRadiusLarge;
  }

  LatLng _getSpiderfyPoint({
    required LatLng center,
    required int index,
    required int count,
  }) {
    final radius =
        _getSpiderfyRadius(count);

    final angle =
        (-pi / 2) +
        (index * (2 * pi / count));

    return LatLng(
      center.latitude +
          radius * cos(angle),
      center.longitude +
          radius * sin(angle),
    );
  }

  // ============================================================
  // MARKER NORMAL
  // ============================================================

  Marker _buildMarker(
    MemoryModel memory,
    LatLng point,
  ) {
    final categoryColor =
        _getCategoryColor(
      memory.category,
    );

    final wouldReturn =
        memory.wouldReturn;

    return Marker(
      width: 68,
      height: 36,
      point: point,
      child: GestureDetector(
        onTap: () {
          _onMarkerTapped(
            memory,
          );
        },
        child: Container(
          alignment:
              Alignment.center,
          decoration:
              BoxDecoration(
            color:
                categoryColor,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border:
                Border.all(
              color:
                  Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.25,
                ),
                blurRadius: 8,
                offset:
                    const Offset(
                  0,
                  4,
                ),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Text(
                '${memory.rating.toStringAsFixed(1)}★',
                style:
                    GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Colors.white,
                ),
              ),
              const SizedBox(
                width: 3,
              ),
              Icon(
                wouldReturn
                    ? Icons.check_rounded
                    : Icons.close_rounded,
                size: 14,
                color:
                    Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MARKER GRUPO
  // ============================================================

  Marker _buildSpiderfyGroupMarker({
    required LatLng point,
    required int count,
    required Color categoryColor,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Marker(
      width: 64,
      height: 64,
      point: point,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale:
              isExpanded ? 1.12 : 1.0,
          duration:
              _spiderfyAnimationDuration,
          curve:
              Curves.easeOutBack,
          child: Container(
            alignment:
                Alignment.center,
            decoration:
                BoxDecoration(
              color:
                  categoryColor,
              shape:
                  BoxShape.circle,
              border:
                  Border.all(
                color:
                    Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(
                    alpha: 0.28,
                  ),
                  blurRadius: 10,
                  offset:
                      const Offset(
                    0,
                    4,
                  ),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  isExpanded
                      ? Icons.close_rounded
                      : Icons.place_rounded,
                  size: 20,
                  color:
                      Colors.white,
                ),
                Text(
                  '$count',
                  style:
                      GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MARKER SPIDERFY
  // ============================================================

  Marker _buildSpiderfyMemoryMarker({
    required MemoryModel memory,
    required LatLng point,
    required LatLng center,
    required int index,
    required int count,
  }) {
    final categoryColor =
        _getCategoryColor(
      memory.category,
    );

    final distance =
        sqrt(
          pow(
                point.latitude -
                    center.latitude,
                2,
              ) +
              pow(
                point.longitude -
                    center.longitude,
                2,
              ),
        );

    final normalizedDistance =
        distance /
            _getSpiderfyRadius(
              count,
            );

    final scale =
        normalizedDistance.clamp(
      0.0,
      1.0,
    );

    return Marker(
      width: 68,
      height: 42,
      point: point,
      child: TweenAnimationBuilder<double>(
        tween:
            Tween<double>(
          begin: 0.0,
          end: scale,
        ),
        duration:
            Duration(
          milliseconds:
              180 +
              (index * 35),
        ),
        curve:
            Curves.easeOutBack,
        builder: (
          context,
          animationValue,
          child,
        ) {
          return Opacity(
            opacity:
                animationValue,
            child: Transform.scale(
              scale:
                  animationValue,
              child:
                  child,
            ),
          );
        },
        child: GestureDetector(
          onTap: () {
            _onMarkerTapped(
              memory,
            );
          },
          child: Container(
            alignment:
                Alignment.center,
            decoration:
                BoxDecoration(
              color:
                  categoryColor,
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
              border:
                  Border.all(
                color:
                    Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(
                    alpha: 0.28,
                  ),
                  blurRadius: 9,
                  offset:
                      const Offset(
                    0,
                    4,
                  ),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  '${memory.rating.toStringAsFixed(1)}★',
                  style:
                      GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.white,
                  ),
                ),
                const SizedBox(
                  width: 3,
                ),
                Icon(
                  memory.wouldReturn
                      ? Icons.check_rounded
                      : Icons.close_rounded,
                  size: 13,
                  color:
                      Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MARKER TAP
  // ============================================================

  void _onMarkerTapped(
    MemoryModel memory,
  ) {
    _showMemoryBottomSheet(
      memory,
    );
  }

  // ============================================================
  // BOTTOM SHEET
  // ============================================================

  void _showMemoryBottomSheet(
    MemoryModel memory,
  ) {
    final categoryColor =
        _getCategoryColor(
      memory.category,
    );

    final coordinates =
        _memoryCoordinates[
          memory.id
        ];

    final double? lat =
        coordinates?.latitude;

    final double? lng =
        coordinates?.longitude;

    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled:
          true,
      builder: (context) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            36,
          ),
          decoration:
              const BoxDecoration(
            color: Color(0xFFFFFDF5),
            borderRadius:
                BorderRadius.vertical(
              top:
                  Radius.circular(
                32,
              ),
            ),
            border: Border(
              top: BorderSide(
                color: Color(0xFF0F172A),
                width: 3,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black26,
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin:
                      const EdgeInsets.only(
                    bottom: 20,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      2,
                    ),
                  ),
                ),
              ),

              // --------------------------------------------------
              // TÍTULO + RATING
              // --------------------------------------------------

              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      memory.title,
                      style:
                          GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            const Color(
                          0xFF0F172A,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          categoryColor
                              .withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: Text(
                      '${memory.rating.toStringAsFixed(1)} ★',
                      style:
                          GoogleFonts.outfit(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 15,
                        color:
                            categoryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              // --------------------------------------------------
              // UBICACIÓN
              // --------------------------------------------------

              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color:
                        Colors.grey.shade500,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                    child:
                        lat != null &&
                                lng != null
                            ? FutureBuilder<
                                String>(
                                future:
                                    _resolveLocationName(
                                  lat,
                                  lng,
                                  memory.location
                                      .address,
                                ),
                                builder:
                                    (
                                  context,
                                  snapshot,
                                ) {
                                  final text =
                                      snapshot.data ??
                                          memory
                                              .location
                                              .address;

                                  return Text(
                                    text.isNotEmpty
                                        ? text
                                        : 'Ubicación no disponible',
                                    style:
                                        GoogleFonts
                                            .inter(
                                      fontSize:
                                          14,
                                      color: Colors
                                          .grey
                                          .shade600,
                                    ),
                                    maxLines:
                                        1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                  );
                                },
                              )
                            : Text(
                                memory.location
                                        .address
                                        .isNotEmpty
                                    ? memory
                                        .location
                                        .address
                                    : 'Ubicación no disponible',
                                style:
                                    GoogleFonts.inter(
                                  fontSize:
                                      14,
                                  color: Colors
                                      .grey
                                      .shade600,
                                ),
                                maxLines:
                                    1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                  ),
                ],
              ),

              const SizedBox(
                height: 16,
              ),

              // --------------------------------------------------
              // CHIPS
              // --------------------------------------------------

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      memory.category,
                    ),
                    backgroundColor:
                        categoryColor
                            .withValues(
                      alpha: 0.15,
                    ),
                    labelStyle:
                        GoogleFonts.inter(
                      fontWeight:
                          FontWeight.w600,
                      fontSize: 13,
                      color:
                          categoryColor,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                    side: BorderSide(
                      color:
                          categoryColor,
                      width: 1.5,
                    ),
                  ),
                  Chip(
                    label: Text(
                      memory.wouldReturn
                          ? '¡Volvería!'
                          : 'No volvería',
                    ),
                    backgroundColor:
                        (memory.wouldReturn
                                ? Colors.green
                                : Colors.red)
                            .withValues(
                      alpha: 0.12,
                    ),
                    labelStyle:
                        GoogleFonts.inter(
                      fontWeight:
                          FontWeight.w600,
                      fontSize: 13,
                      color: memory.wouldReturn
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                    side: BorderSide(
                      color: memory.wouldReturn
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      width: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 24,
              ),

              // --------------------------------------------------
              // BOTÓN DETALLE
              // --------------------------------------------------

              SizedBox(
                width:
                    double.infinity,
                height: 52,
                child:
                    ElevatedButton(
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        const Color(
                      0xFFFFD400,
                    ),
                    foregroundColor:
                        const Color(
                      0xFF0F172A,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      side: const BorderSide(
                        color: Color(0xFF0F172A),
                        width: 2,
                      ),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();

                    Navigator.pop(
                      context,
                    );

                    context.push(
                      '/memory-detail',
                      extra: memory,
                    );
                  },
                  child: Text(
                    'Ver Experiencia Completa',
                    style:
                        GoogleFonts.outfit(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

 // ============================================================
// CÁMARA
// ============================================================

/// Zoom mínimo utilizado por la aplicación.
static const double _mapMinZoom = 3.0;

/// Zoom máximo utilizado por la aplicación.
static const double _mapMaxZoom = 18.0;

/// Zoom utilizado cuando solo existe un recuerdo.
static const double _singleMemoryZoom = 13.5;

/// Zoom utilizado para centrar la ubicación actual.
static const double _currentLocationZoom = 14.5;

/// Padding visual utilizado para el cálculo del encuadre.
/// No depende de CameraFit.
static const double _cameraHorizontalPadding = 70.0;
static const double _cameraTopPadding = 150.0;
static const double _cameraBottomPadding = 120.0;

/// Ajusta la cámara para mostrar los recuerdos filtrados.
///
/// IMPORTANTE:
///
/// Esta implementación NO utiliza:
///
/// - CameraFitBounds
/// - cameraFit.bounds
/// - cameraFit.padding
/// - cameraFit.minZoom
/// - cameraFit.maxZoom
///
/// Esto evita incompatibilidades entre versiones de flutter_map.
void _fitMapToFilteredMemories(
  List<MemoryModel> memories, {
  bool animated = true,
}) {
  if (_isDisposed ||
      !mounted ||
      _isFittingCamera ||
      _isUserInteractingWithMap) {
    return;
  }

  final filteredMemories =
      memories.where(
    (memory) {
      return _matchesCategory(
        memory,
        _selectedCategory,
      );
    },
  ).toList();

  final List<LatLng> points = [];

  for (final memory in filteredMemories) {
    final point =
        _memoryCoordinates[memory.id];

    if (point != null &&
        _isValidCoordinate(
          point.latitude,
          point.longitude,
        )) {
      points.add(point);
    }
  }

  debugPrint(
    '🎯 Ajustando cámara',
  );

  debugPrint(
    '🎯 Categoría: $_selectedCategory',
  );

  debugPrint(
    '🎯 Memories filtradas: '
    '${filteredMemories.length}',
  );

  debugPrint(
    '🎯 Puntos disponibles: '
    '${points.length}',
  );

  if (points.isEmpty) {
    return;
  }

  _isFittingCamera = true;

  try {
    // ==========================================================
    // UN SOLO PUNTO
    // ==========================================================

    if (points.length == 1) {
      _animatedMove(
        points.first,
        _singleMemoryZoom,
        animated,
      );

      _releaseCameraFitLock();

      return;
    }

    // ==========================================================
    // VARIOS PUNTOS
    // ==========================================================

    final bounds =
        LatLngBounds.fromPoints(
      points,
    );

    final center =
        bounds.center;

    final targetZoom =
        _calculateBoundsZoom(
      bounds,
    );

    debugPrint(
      '🎯 Bounds calculados',
    );

    debugPrint(
      '🎯 Norte: ${bounds.north}',
    );

    debugPrint(
      '🎯 Sur: ${bounds.south}',
    );

    debugPrint(
      '🎯 Este: ${bounds.east}',
    );

    debugPrint(
      '🎯 Oeste: ${bounds.west}',
    );

    debugPrint(
      '🎯 Centro: '
      '${center.latitude}, '
      '${center.longitude}',
    );

    debugPrint(
      '🎯 Zoom calculado: $targetZoom',
    );

    // ==========================================================
    // MOVER CÁMARA
    // ==========================================================

    _animatedMove(
      center,
      targetZoom,
      animated,
    );

    _releaseCameraFitLock();
  } catch (e, stack) {
    debugPrint(
      '❌ Error ajustando cámara: $e',
    );

    debugPrintStack(
      stackTrace: stack,
    );

    _releaseCameraFitLock();
  }
}

/// Calcula un zoom aproximado para mostrar todos los puntos
/// incluidos en [bounds].
///
/// Se utiliza una aproximación basada en Web Mercator.
///
/// No depende de APIs internas de flutter_map.
///
/// Esto hace que el código sea compatible con distintas
/// versiones de flutter_map.
double _calculateBoundsZoom(
  LatLngBounds bounds,
) {
  try {
    final size =
        MediaQuery.of(context).size;

    final mapWidth =
        max(
          1.0,
          size.width -
              (_cameraHorizontalPadding * 2),
        );

    final mapHeight =
        max(
          1.0,
          size.height -
              _cameraTopPadding -
              _cameraBottomPadding,
        );

    // ==========================================================
    // EXTENSIÓN LONGITUDINAL
    // ==========================================================

    double longitudeSpan =
        (bounds.east -
                bounds.west)
            .abs();

    // Evitamos división por cero.
    if (longitudeSpan < 0.000001) {
      longitudeSpan = 0.000001;
    }

    // ==========================================================
    // EXTENSIÓN LATITUDINAL
    // ==========================================================

    double latitudeSpan =
        (bounds.north -
                bounds.south)
            .abs();

    if (latitudeSpan < 0.000001) {
      latitudeSpan = 0.000001;
    }

    // ==========================================================
    // WEB MERCATOR
    // ==========================================================

    double mercatorY(
      double latitude,
    ) {
      // Evitamos problemas cerca de los polos.
      final safeLatitude =
          latitude.clamp(
        -85.05112878,
        85.05112878,
      );

      final latRad =
          safeLatitude *
              pi /
              180.0;

      return log(
        tan(
          pi / 4 +
              latRad / 2,
        ),
      );
    }

    final northY =
        mercatorY(
      bounds.north,
    );

    final southY =
        mercatorY(
      bounds.south,
    );

    var mercatorSpan =
        (northY -
                southY)
            .abs();

    if (mercatorSpan <
        0.000001) {
      mercatorSpan =
          0.000001;
    }

    // ==========================================================
    // CONSTANTES
    // ==========================================================

    const double tileSize =
        256.0;

    const double worldWidth =
        360.0;

    const double worldHeight =
        2 * pi;

    // ==========================================================
    // ZOOM HORIZONTAL
    // ==========================================================

    final zoomX =
        log(
              mapWidth /
                  tileSize,
            ) /
            ln2 -
        log(
              longitudeSpan /
                  worldWidth,
            ) /
            ln2;

    // ==========================================================
    // ZOOM VERTICAL
    // ==========================================================

    final zoomY =
        log(
              mapHeight /
                  tileSize,
            ) /
            ln2 -
        log(
              mercatorSpan /
                  worldHeight,
            ) /
            ln2;

    // ==========================================================
    // ZOOM FINAL
    // ==========================================================

    var zoom =
        min(
          zoomX,
          zoomY,
        );

    // ==========================================================
    // MARGEN DE SEGURIDAD
    // ==========================================================

    // Reducimos ligeramente el zoom para evitar que los
    // marcadores queden demasiado cerca de los bordes.
    zoom -= 0.35;

    // ==========================================================
    // LIMITAR ZOOM
    // ==========================================================

    zoom =
        zoom.clamp(
      _mapMinZoom,
      _mapMaxZoom,
    );

    return zoom;
  } catch (e, stack) {
    debugPrint(
      '❌ Error calculando zoom de bounds: $e',
    );

    debugPrintStack(
      stackTrace: stack,
    );

    // Zoom seguro de fallback.
    return 6.0;
  }
}

/// Libera el bloqueo de ajuste automático de cámara
/// después de un pequeño margen.
///
/// El margen evita que la cámara vuelva a intentar ajustarse
/// mientras la animación todavía está terminando.
void _releaseCameraFitLock() {
  Future.delayed(
    const Duration(
      milliseconds: 900,
    ),
    () {
      if (!_isDisposed &&
          mounted) {
        _isFittingCamera = false;
      }
    },
  );
}

// ============================================================
// ANIMACIÓN MOVE
// ============================================================

void _animatedMove(
  LatLng destLocation,
  double destZoom,
  bool animated,
) {
  if (_isDisposed ||
      !mounted) {
    return;
  }

  // ==========================================================
  // LIMITAR ZOOM
  // ==========================================================

  final safeZoom =
      destZoom.clamp(
    _mapMinZoom,
    _mapMaxZoom,
  );

  // ==========================================================
  // DETENER ANIMACIÓN ANTERIOR
  // ==========================================================

  final previousController =
      _cameraAnimationController;

  _cameraAnimationController =
      null;

  previousController
      ?.stop();

  previousController
      ?.dispose();

  // ==========================================================
  // MOVIMIENTO INMEDIATO
  // ==========================================================

  if (!animated) {
    try {
      _mapController.move(
        destLocation,
        safeZoom,
      );
    } catch (e) {
      debugPrint(
        '❌ Error moviendo mapa: $e',
      );
    }

    return;
  }

  // ==========================================================
  // ANIMACIÓN
  // ==========================================================

  try {
    final camera =
        _mapController.camera;

    final startLat =
        camera.center.latitude;

    final startLng =
        camera.center.longitude;

    final startZoom =
        camera.zoom;

    final latTween =
        Tween<double>(
      begin:
          startLat,
      end:
          destLocation.latitude,
    );

    final lngTween =
        Tween<double>(
      begin:
          startLng,
      end:
          destLocation.longitude,
    );

    final zoomTween =
        Tween<double>(
      begin:
          startZoom,
      end:
          safeZoom,
    );

    final controller =
        AnimationController(
      duration:
          _cameraAnimationDuration,
      vsync: this,
    );

    _cameraAnimationController =
        controller;

    final animation =
        CurvedAnimation(
      parent:
          controller,
      curve:
          Curves.easeInOutCubic,
    );

    controller.addListener(
      () {
        if (_isDisposed ||
            !mounted ||
            controller !=
                _cameraAnimationController) {
          return;
        }

        try {
          final lat =
              latTween.evaluate(
            animation,
          );

          final lng =
              lngTween.evaluate(
            animation,
          );

          final zoom =
              zoomTween.evaluate(
            animation,
          );

          _mapController.move(
            LatLng(
              lat,
              lng,
            ),
            zoom,
          );
        } catch (e) {
          debugPrint(
            '❌ Error durante animación de cámara: $e',
          );
        }
      },
    );

    controller
        .forward()
        .whenComplete(
      () {
        if (_cameraAnimationController ==
            controller) {
          _cameraAnimationController =
              null;
        }

        controller.dispose();
      },
    );
  } catch (e, stack) {
    debugPrint(
      '❌ Error creando animación de cámara: $e',
    );

    debugPrintStack(
      stackTrace: stack,
    );
  }
}

  // ============================================================
  // UBICACIÓN ACTUAL
  // ============================================================

  Future<void> _goToCurrentLocation() async {
    try {
      debugPrint(
        '📍 Solicitando ubicación actual...',
      );

      final serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint(
          '⚠️ Servicio de ubicación desactivado.',
        );

        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
              LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        debugPrint(
          '⚠️ Permiso de ubicación no disponible.',
        );

        return;
      }

      final position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      if (_isDisposed || !mounted) {
        return;
      }

      if (!_isValidCoordinate(
        position.latitude,
        position.longitude,
      )) {
        return;
      }

      _closeAllSpiderfyGroups();

      _animatedMove(
        LatLng(
          position.latitude,
          position.longitude,
        ),
        14.5,
        true,
      );
    } catch (e, stack) {
      debugPrint(
        '❌ Error obteniendo ubicación actual: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );
    }
  }

  // ============================================================
  // NOMBRE DE UBICACIÓN
  // ============================================================

  Future<String> _resolveLocationName(
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
  // COLOR CATEGORÍA
  // ============================================================

  Color _getCategoryColor(
    String category,
  ) {
    final cat = _normalize(
      category,
    );

    if (cat.contains('croqueta')) {
      return const Color(
        0xFFE65100,
      );
    }

    if (cat.contains('ensaladilla')) {
      return const Color(
        0xFF00838F,
      );
    }

    if (cat.contains('tortilla')) {
      return const Color(
        0xFFF57F17,
      );
    }

    if (cat.contains('menu')) {
      return const Color(
        0xFF6A1B9A,
      );
    }

    if (cat.contains('plato')) {
      return const Color(
        0xFFC2185B,
      );
    }

    if (cat.contains('postre') ||
        cat.contains('helado')) {
      return const Color(
        0xFF00695C,
      );
    }

    if (cat.contains('decoracion') ||
        cat.contains('espacio')) {
      return const Color(
        0xFF283593,
      );
    }

    if (cat.contains('atencion')) {
      return const Color(
        0xFFD84315,
      );
    }

    return const Color(
      0xFF1E293B,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final memoryModelsAsync =
        ref.watch(
      memoryModelsStreamProvider,
    );

    final locationsAsync =
        ref.watch(
      locationsStreamProvider,
    );

    return Scaffold(
      body: memoryModelsAsync.when(
        loading: () {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        },
        error: (
          error,
          stack,
        ) {
          debugPrint(
            '❌ ERROR STREAM MEMORY MODELS: $error',
          );

          debugPrintStack(
            stackTrace: stack,
          );

          return Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                24,
              ),
              child: Text(
                'Error al cargar recuerdos:\n$error',
                textAlign:
                    TextAlign.center,
              ),
            ),
          );
        },
        data: (
          allMemories,
        ) {
          // ======================================================
          // LOCATIONS LEGACY
          // ======================================================

          final locations =
              locationsAsync.when(
            loading: () =>
                <Map<String, dynamic>>[],
            error: (
              error,
              stack,
            ) {
              debugPrint(
                '⚠️ ERROR STREAM LOCATIONS LEGACY: $error',
              );

              return <
                  Map<String, dynamic>>[];
            },
            data: (
              data,
            ) =>
                data,
          );

          // ======================================================
          // FIRMA
          // ======================================================

          final signature =
              _buildMemorySignature(
            allMemories,
          );

          // ======================================================
          // RESOLVER COORDENADAS
          // ======================================================

          if (_lastProcessedSignature !=
              signature) {
            _lastProcessedSignature =
                signature;

            // Los grupos anteriores pueden haber dejado
            // referencias a recuerdos que ya no existen.
            _closeAllSpiderfyGroups();

            WidgetsBinding.instance
                .addPostFrameCallback(
              (_) {
                if (_isDisposed ||
                    !mounted) {
                  return;
                }

                _resolveAllCoordinates(
                  allMemories,
                  locations,
                );
              },
            );
          }

          // ======================================================
          // FILTRO
          // ======================================================

          final filteredMemories =
              allMemories.where(
            (memory) {
              return _matchesCategory(
                memory,
                _selectedCategory,
              );
            },
          ).toList();

          // ======================================================
          // AGRUPACIÓN POR COORDENADAS
          // ======================================================

          final Map<String,
                  List<MemoryModel>>
              groupedMemories = {};

          final Map<String, LatLng>
              groupCenters = {};

          for (final memory
              in filteredMemories) {
            final point =
                _memoryCoordinates[
                  memory.id
                ];

            if (point == null) {
              continue;
            }

            final key =
                _buildCoordinateGroupKey(
              point,
            );

            groupedMemories
                .putIfAbsent(
                  key,
                  () => [],
                )
                .add(memory);

            groupCenters[key] =
                point;
          }

          // ======================================================
          // CREAR MARKERS
          // ======================================================

          final List<Marker>
              markers = [];

          groupedMemories.forEach(
            (
              groupKey,
              memories,
            ) {
              final center =
                  groupCenters[groupKey];

              if (center == null) {
                return;
              }

              // --------------------------------------------------
              // UN SOLO RECUERDO
              // --------------------------------------------------

              if (memories.length == 1) {
                final memory =
                    memories.first;

                final originalPoint =
                    _memoryCoordinates[
                      memory.id
                    ];

                if (originalPoint == null) {
                  return;
                }

                markers.add(
                  _buildMarker(
                    memory,
                    originalPoint,
                  ),
                );

                return;
              }

              // --------------------------------------------------
              // VARIOS RECUERDOS
              // --------------------------------------------------

              final isExpanded =
                  _expandedSpiderfyGroups
                      .contains(
                groupKey,
              );

              final firstMemory =
                  memories.first;

              final categoryColor =
                  _getCategoryColor(
                firstMemory.category,
              );

              // --------------------------------------------------
              // MARCADOR CENTRAL
              // --------------------------------------------------

              markers.add(
                _buildSpiderfyGroupMarker(
                  point:
                      center,
                  count:
                      memories.length,
                  categoryColor:
                      categoryColor,
                  isExpanded:
                      isExpanded,
                  onTap: () {
                    _showMemoryGroupPicker(
                      memories,
                    );
                  },
                ),
              );

              // --------------------------------------------------
              // MARCADORES ABIERTOS
              // --------------------------------------------------

              if (isExpanded) {
                for (
                  int i = 0;
                  i < memories.length;
                  i++
                ) {
                  final memory =
                      memories[i];

                  final spiderPoint =
                      _getSpiderfyPoint(
                    center:
                        center,
                    index:
                        i,
                    count:
                        memories.length,
                  );

                  markers.add(
                    _buildSpiderfyMemoryMarker(
                      memory:
                          memory,
                      point:
                          spiderPoint,
                      center:
                          center,
                      index:
                          i,
                      count:
                          memories.length,
                    ),
                  );
                }
              }
            },
          );

          // ======================================================
          // INTERFAZ
          // ======================================================

          return Stack(
            children: [
              // ==================================================
              // MAPA
              // ==================================================

              FlutterMap(
                mapController:
                    _mapController,
                options:
                    MapOptions(
                  initialCenter:
                      _peninsulaCenter,
                  initialZoom:
                      _peninsulaZoom,
                  minZoom:
                      3.0,
                  maxZoom:
                      18.0,

                  // ------------------------------------------------
                  // INTERACCIÓN MAPA
                  // ------------------------------------------------

                  onPointerDown:
                      (
                    event,
                    point,
                  ) {
                    _isUserInteractingWithMap =
                        true;

                    _closeAllSpiderfyGroups();
                  },

                  onPointerUp:
                      (
                    event,
                    point,
                  ) {
                    Future.delayed(
                      const Duration(
                        milliseconds:
                            350,
                      ),
                      () {
                        if (!_isDisposed &&
                            mounted) {
                          _isUserInteractingWithMap =
                              false;
                        }
                      },
                    );
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains:
                        const [
                      'a',
                      'b',
                      'c',
                      'd',
                    ],
                    userAgentPackageName:
                        'com.palito.app',
                    maxZoom:
                        19,
                    retinaMode:
                        true,
                  ),

                  // ------------------------------------------------
                  // MARKERS
                  // ------------------------------------------------

                  MarkerLayer(
                    markers:
                        markers,
                  ),
                ],
              ),

              // ==================================================
              // HEADER / FILTROS
              // ==================================================

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child:
                    Container(
                  padding:
                      EdgeInsets.fromLTRB(
                    12,
                    MediaQuery.of(
                          context,
                        )
                            .padding
                            .top +
                        8,
                    12,
                    16,
                  ),
                  decoration:
                      BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment.bottomCenter,
                      colors: [
                        Colors.white
                            .withValues(
                          alpha:
                              0.95,
                        ),
                        Colors.white
                            .withValues(
                          alpha:
                              0.0,
                        ),
                      ],
                    ),
                  ),
                  child:
                      Row(
                    children: [
                      IconButton(
                        onPressed:
                            () {
                          _closeAllSpiderfyGroups();

                          context.go(
                            '/',
                          );
                        },
                        icon:
                            Container(
                          padding:
                              const EdgeInsets
                                  .all(
                            8,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white,
                            shape:
                                BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors
                                    .black
                                    .withValues(
                                  alpha:
                                      0.12,
                                ),
                                blurRadius:
                                    8,
                                offset:
                                    const Offset(
                                  0,
                                  2,
                                ),
                              ),
                            ],
                          ),
                          child:
                              const Icon(
                            Icons.arrow_back,
                            color:
                                Color(
                              0xFF0F172A,
                            ),
                            size:
                                22,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child:
                            SizedBox(
                          height:
                              46,
                          child:
                              ListView
                                  .separated(
                            scrollDirection:
                                Axis.horizontal,
                            itemCount:
                                _filterCategories
                                    .length,
                            separatorBuilder:
                                (
                              _,
                              _,
                            ) =>
                                    const SizedBox(
                              width:
                                  8,
                            ),
                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              final cat =
                                  _filterCategories[
                                      index];

                              final isSelected =
                                  (_selectedCategory ??
                                          'Todas') ==
                                      cat;

                              return FilterChip(
                                label:
                                    Text(
                                  cat,
                                  style:
                                      GoogleFonts
                                          .inter(
                                    fontWeight:
                                        FontWeight.w600,
                                    fontSize:
                                        13,
                                  ),
                                ),
                                selected:
                                    isSelected,
                                onSelected:
                                    (
                                  selected,
                                ) {
                                  if (!selected &&
                                      cat !=
                                          'Todas') {
                                    return;
                                  }

                                  _closeAllSpiderfyGroups();

                                  setState(
                                    () {
                                      _selectedCategory =
                                          cat ==
                                                  'Todas'
                                              ? null
                                              : cat;
                                    },
                                  );

                                  WidgetsBinding
                                      .instance
                                      .addPostFrameCallback(
                                    (_) {
                                      if (_isDisposed ||
                                          !mounted) {
                                        return;
                                      }

                                      _fitMapToFilteredMemories(
                                        allMemories,
                                        animated:
                                            true,
                                      );
                                    },
                                  );
                                },
                                backgroundColor:
                                    Colors.white,
                                selectedColor:
                                    const Color(
                                  0xFFFFD400,
                                ),
                                checkmarkColor:
                                    const Color(
                                  0xFF0F172A,
                                ),
                                elevation:
                                    3,
                                shadowColor:
                                    Colors.black26,
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      10,
                                  vertical:
                                      8,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ==================================================
              // CONTADOR
              // ==================================================

              Positioned(
                bottom:
                    30,
                left:
                    20,
                child:
                    Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal:
                        16,
                    vertical:
                        12,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors
                            .black
                            .withValues(
                          alpha:
                              0.15,
                        ),
                        blurRadius:
                            12,
                        offset:
                            const Offset(
                          0,
                          4,
                        ),
                      ),
                    ],
                  ),
                  child:
                      Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size:
                            18,
                        color:
                            Color(
                          0xFFFF4D29,
                        ),
                      ),
                      const SizedBox(
                        width:
                            8,
                      ),
                      Text(
                        '${filteredMemories.length} '
                        '${filteredMemories.length == 1 ? 'recuerdo' : 'recuerdos'}',
                        style:
                            GoogleFonts
                                .outfit(
                          fontWeight:
                              FontWeight.bold,
                          fontSize:
                              14,
                          color:
                              const Color(
                            0xFF0F172A,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ==================================================
              // BOTÓN UBICACIÓN
              // ==================================================

              Positioned(
                bottom:
                    30,
                right:
                    20,
                child:
                    FloatingActionButton(
                  backgroundColor:
                      Colors.white,
                  foregroundColor:
                      const Color(
                    0xFF0F172A,
                  ),
                  elevation:
                      6,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),
                  onPressed:
                      _goToCurrentLocation,
                  child:
                      const Icon(
                    Icons.my_location_rounded,
                    size:
                        24,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    debugPrint(
      '🗺️ MAP PAGE DISPOSE',
    );

    _isDisposed = true;

    _coordinateResolutionGeneration++;

    _cameraAnimationController
        ?.stop();

    _cameraAnimationController
        ?.dispose();

    _cameraAnimationController =
        null;

    _spiderfyAnimationController
        ?.stop();

    _spiderfyAnimationController
        ?.dispose();

    _spiderfyAnimationController =
        null;

    _resolvingMemoryIds.clear();

    _expandedSpiderfyGroups.clear();

    _memoryCoordinates.clear();

    _geocodedCache.clear();

    super.dispose();
  }
}