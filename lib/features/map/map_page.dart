import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/providers/memory_map_provider.dart';
import '../../../../../core/models/memory_model.dart';
import 'services/memory_geocoding_service.dart';
import 'widgets/map_marker_builder.dart';
import 'widgets/memory_bottom_sheet.dart';
import 'widgets/memory_group_picker.dart';
import '../../core/utils/app_log.dart';

class MapPage extends ConsumerStatefulWidget {
  final String? initialCategory;

  const MapPage({super.key, this.initialCategory});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage>
    with TickerProviderStateMixin {
  // ============================================================
  // CONSTANTES
  // ============================================================

  static const LatLng _peninsulaCenter = LatLng(40.4168, -3.7038);

  static const double _peninsulaZoom = 6.2;

  static const Duration _cameraAnimationDuration = Duration(milliseconds: 750);

  static const Duration _spiderfyAnimationDuration = Duration(
    milliseconds: 280,
  );

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

  /// Resuelve y cachea las coordenadas geográficas de los recuerdos
  /// (geocodificación, geocodificación inversa y firma de datos
  /// procesados). Se inicializa en `initState` (no como field initializer)
  /// para poder reutilizar la misma instancia compartida de
  /// `MemoryMapFirestoreService` que expone `memoryMapServiceProvider`, en
  /// vez de crear una segunda instancia con su propio `groupId`
  /// potencialmente desincronizado.
  late final MemoryGeocodingService _geocodingService;

  /// Controlador de animación de cámara.
  AnimationController? _cameraAnimationController;

  /// Controlador de animación del spiderfy.
  AnimationController? _spiderfyAnimationController;

  /// Evita múltiples ajustes de cámara simultáneos.
  bool _isFittingCamera = false;

  /// Control de ciclo de vida.
  bool _isDisposed = false;

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

    _geocodingService = MemoryGeocodingService(
      firestoreService: ref.read(memoryMapServiceProvider),
    );

    _selectedCategory = widget.initialCategory;

    _log('🗺️ MAP PAGE INIT');
    _log('🗺️ Categoría inicial: $_selectedCategory');
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

  bool _isValidCoordinate(double? lat, double? lng) {
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

  bool _matchesCategory(MemoryModel memory, String? filter) {
    if (filter == null || filter == 'Todas') {
      return true;
    }

    final memoryCat = _normalize(memory.category);

    final filterCat = _normalize(filter);

    if (memoryCat == filterCat) {
      return true;
    }

    if (filterCat.contains('postre') &&
        (memoryCat.contains('postre') || memoryCat.contains('helado'))) {
      return true;
    }

    if (filterCat.contains('decoracion') &&
        (memoryCat.contains('decoracion') || memoryCat.contains('espacio'))) {
      return true;
    }

    if (filterCat.contains('menu') && memoryCat.contains('menu')) {
      return true;
    }

    if (filterCat.contains('plato') && memoryCat.contains('plato')) {
      return true;
    }

    return false;
  }

  // ============================================================
  // SPIDERFY
  // ============================================================

  String _buildCoordinateGroupKey(LatLng point) {
    return '${point.latitude.toStringAsFixed(6)}_'
        '${point.longitude.toStringAsFixed(6)}';
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

  double _getSpiderfyRadius(int count) {
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
    final radius = _getSpiderfyRadius(count);

    final angle = (-pi / 2) + (index * (2 * pi / count));

    return LatLng(
      center.latitude + radius * cos(angle),
      center.longitude + radius * sin(angle),
    );
  }

  // ============================================================
  // MARKER TAP
  // ============================================================

  void _onMarkerTapped(MemoryModel memory) {
    MemoryBottomSheet.show(
      context: context,
      memory: memory,
      getCategoryColor: _getCategoryColor,
      getCoordinates: (memoryId) =>
          _geocodingService.memoryCoordinates[memoryId],
      resolveLocationName: _geocodingService.resolveLocationName,
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

    final filteredMemories = memories.where((memory) {
      return _matchesCategory(memory, _selectedCategory);
    }).toList();

    final List<LatLng> points = [];

    for (final memory in filteredMemories) {
      final point = _geocodingService.memoryCoordinates[memory.id];

      if (point != null &&
          _isValidCoordinate(point.latitude, point.longitude)) {
        points.add(point);
      }
    }

    _log('🎯 Ajustando cámara');

    _log('🎯 Categoría: $_selectedCategory');

    _log(
      '🎯 Memories filtradas: '
      '${filteredMemories.length}',
    );

    _log(
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
        _animatedMove(points.first, _singleMemoryZoom, animated);

        _releaseCameraFitLock();

        return;
      }

      // ==========================================================
      // VARIOS PUNTOS
      // ==========================================================

      final bounds = LatLngBounds.fromPoints(points);

      final center = bounds.center;

      final targetZoom = _calculateBoundsZoom(bounds);

      _log('🎯 Bounds calculados');

      _log('🎯 Norte: ${bounds.north}');

      _log('🎯 Sur: ${bounds.south}');

      _log('🎯 Este: ${bounds.east}');

      _log('🎯 Oeste: ${bounds.west}');

      _log(
        '🎯 Centro: '
        '${center.latitude}, '
        '${center.longitude}',
      );

      _log('🎯 Zoom calculado: $targetZoom');

      // ==========================================================
      // MOVER CÁMARA
      // ==========================================================

      _animatedMove(center, targetZoom, animated);

      _releaseCameraFitLock();
    } catch (e, stack) {
      _log('❌ Error ajustando cámara: $e');

      _logStack(stackTrace: stack);

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
  double _calculateBoundsZoom(LatLngBounds bounds) {
    try {
      final size = MediaQuery.of(context).size;

      final mapWidth = max(1.0, size.width - (_cameraHorizontalPadding * 2));

      final mapHeight = max(
        1.0,
        size.height - _cameraTopPadding - _cameraBottomPadding,
      );

      // ==========================================================
      // EXTENSIÓN LONGITUDINAL
      // ==========================================================

      double longitudeSpan = (bounds.east - bounds.west).abs();

      // Evitamos división por cero.
      if (longitudeSpan < 0.000001) {
        longitudeSpan = 0.000001;
      }

      // ==========================================================
      // EXTENSIÓN LATITUDINAL
      // ==========================================================

      double latitudeSpan = (bounds.north - bounds.south).abs();

      if (latitudeSpan < 0.000001) {
        latitudeSpan = 0.000001;
      }

      // ==========================================================
      // WEB MERCATOR
      // ==========================================================

      double mercatorY(double latitude) {
        // Evitamos problemas cerca de los polos.
        final safeLatitude = latitude.clamp(-85.05112878, 85.05112878);

        final latRad = safeLatitude * pi / 180.0;

        return log(tan(pi / 4 + latRad / 2));
      }

      final northY = mercatorY(bounds.north);

      final southY = mercatorY(bounds.south);

      var mercatorSpan = (northY - southY).abs();

      if (mercatorSpan < 0.000001) {
        mercatorSpan = 0.000001;
      }

      // ==========================================================
      // CONSTANTES
      // ==========================================================

      const double tileSize = 256.0;

      const double worldWidth = 360.0;

      const double worldHeight = 2 * pi;

      // ==========================================================
      // ZOOM HORIZONTAL
      // ==========================================================

      final zoomX =
          log(mapWidth / tileSize) / ln2 -
          log(longitudeSpan / worldWidth) / ln2;

      // ==========================================================
      // ZOOM VERTICAL
      // ==========================================================

      final zoomY =
          log(mapHeight / tileSize) / ln2 -
          log(mercatorSpan / worldHeight) / ln2;

      // ==========================================================
      // ZOOM FINAL
      // ==========================================================

      var zoom = min(zoomX, zoomY);

      // ==========================================================
      // MARGEN DE SEGURIDAD
      // ==========================================================

      // Reducimos ligeramente el zoom para evitar que los
      // marcadores queden demasiado cerca de los bordes.
      zoom -= 0.35;

      // ==========================================================
      // LIMITAR ZOOM
      // ==========================================================

      zoom = zoom.clamp(_mapMinZoom, _mapMaxZoom);

      return zoom;
    } catch (e, stack) {
      _log('❌ Error calculando zoom de bounds: $e');

      _logStack(stackTrace: stack);

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
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!_isDisposed && mounted) {
        _isFittingCamera = false;
      }
    });
  }

  // ============================================================
  // ANIMACIÓN MOVE
  // ============================================================

  void _animatedMove(LatLng destLocation, double destZoom, bool animated) {
    if (_isDisposed || !mounted) {
      return;
    }

    // ==========================================================
    // LIMITAR ZOOM
    // ==========================================================

    final safeZoom = destZoom.clamp(_mapMinZoom, _mapMaxZoom);

    // ==========================================================
    // DETENER ANIMACIÓN ANTERIOR
    // ==========================================================

    final previousController = _cameraAnimationController;

    _cameraAnimationController = null;

    previousController?.stop();

    previousController?.dispose();

    // ==========================================================
    // MOVIMIENTO INMEDIATO
    // ==========================================================

    if (!animated) {
      try {
        _mapController.move(destLocation, safeZoom);
      } catch (e) {
        _log('❌ Error moviendo mapa: $e');
      }

      return;
    }

    // ==========================================================
    // ANIMACIÓN
    // ==========================================================

    try {
      final camera = _mapController.camera;

      final startLat = camera.center.latitude;

      final startLng = camera.center.longitude;

      final startZoom = camera.zoom;

      final latTween = Tween<double>(
        begin: startLat,
        end: destLocation.latitude,
      );

      final lngTween = Tween<double>(
        begin: startLng,
        end: destLocation.longitude,
      );

      final zoomTween = Tween<double>(begin: startZoom, end: safeZoom);

      final controller = AnimationController(
        duration: _cameraAnimationDuration,
        vsync: this,
      );

      _cameraAnimationController = controller;

      final animation = CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOutCubic,
      );

      controller.addListener(() {
        if (_isDisposed ||
            !mounted ||
            controller != _cameraAnimationController) {
          return;
        }

        try {
          final lat = latTween.evaluate(animation);

          final lng = lngTween.evaluate(animation);

          final zoom = zoomTween.evaluate(animation);

          _mapController.move(LatLng(lat, lng), zoom);
        } catch (e) {
          _log('❌ Error durante animación de cámara: $e');
        }
      });

      controller.forward().whenComplete(() {
        if (_cameraAnimationController == controller) {
          _cameraAnimationController = null;
        }

        controller.dispose();
      });
    } catch (e, stack) {
      _log('❌ Error creando animación de cámara: $e');

      _logStack(stackTrace: stack);
    }
  }

  // ============================================================
  // UBICACIÓN ACTUAL
  // ============================================================

  Future<void> _goToCurrentLocation() async {
    try {
      _log('📍 Solicitando ubicación actual...');

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        // Antes esto era un `return` mudo: el usuario pulsaba el botón de
        // ubicación y no pasaba absolutamente nada.
        _showLocationMessage(
          'La ubicación está desactivada en tu móvil.',
          onSettings: Geolocator.openLocationSettings,
        );

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Palito no tiene permiso para usar tu ubicación.',
          onSettings: permission == LocationPermission.deniedForever
              ? Geolocator.openAppSettings
              : null,
        );

        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (_isDisposed || !mounted) {
        return;
      }

      if (!_isValidCoordinate(position.latitude, position.longitude)) {
        return;
      }

      _closeAllSpiderfyGroups();

      _animatedMove(LatLng(position.latitude, position.longitude), 14.5, true);
    } catch (e, stack) {
      AppLog.e('Error obteniendo ubicación actual', e, stack);
      _showLocationMessage('No se pudo obtener tu ubicación.');
    }
  }

  /// Mensaje visible cuando la ubicación no se puede usar, con acceso
  /// directo a los ajustes cuando tiene sentido ofrecerlo.
  void _showLocationMessage(String message, {VoidCallback? onSettings}) {
    if (_isDisposed || !mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: onSettings == null
              ? null
              : SnackBarAction(label: 'Ajustes', onPressed: onSettings),
        ),
      );
  }

  // ============================================================
  // COLOR CATEGORÍA
  // ============================================================

  Color _getCategoryColor(String category) {
    final cat = _normalize(category);

    if (cat.contains('croqueta')) {
      return const Color(0xFFE65100);
    }

    if (cat.contains('ensaladilla')) {
      return const Color(0xFF00838F);
    }

    if (cat.contains('tortilla')) {
      return const Color(0xFFF57F17);
    }

    if (cat.contains('menu')) {
      return const Color(0xFF6A1B9A);
    }

    if (cat.contains('plato')) {
      return const Color(0xFFC2185B);
    }

    if (cat.contains('postre') || cat.contains('helado')) {
      return const Color(0xFF00695C);
    }

    if (cat.contains('decoracion') || cat.contains('espacio')) {
      return const Color(0xFF283593);
    }

    if (cat.contains('atencion')) {
      return const Color(0xFFD84315);
    }

    return const Color(0xFF1E293B);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final memoryModelsAsync = ref.watch(memoryModelsStreamProvider);

    final locationsAsync = ref.watch(locationsStreamProvider);

    return Scaffold(
      body: memoryModelsAsync.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stack) {
          _log('❌ ERROR STREAM MEMORY MODELS: $error');

          _logStack(stackTrace: stack);

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error al cargar recuerdos:\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        data: (allMemories) {
          // ======================================================
          // LOCATIONS LEGACY
          // ======================================================

          final locations = locationsAsync.when(
            loading: () => <Map<String, dynamic>>[],
            error: (error, stack) {
              _log('⚠️ ERROR STREAM LOCATIONS LEGACY: $error');

              return <Map<String, dynamic>>[];
            },
            data: (data) => data,
          );

          // ======================================================
          // RESOLVER COORDENADAS
          // ======================================================

          if (_geocodingService.shouldResolve(allMemories)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_isDisposed || !mounted) {
                return;
              }

              // Esta limpieza llama a setState. Estaba FUERA del
              // post-frame, es decir, en plena fase de build: en cuanto
              // había un grupo spiderfy abierto y llegaba una emisión
              // nueva del stream, saltaba "setState() called during
              // build" y la pantalla del mapa se rompía.
              _closeAllSpiderfyGroups();

              _geocodingService.resolveAllCoordinates(
                allMemories,
                locations,
                isActive: () => !_isDisposed && mounted,
                onCoordinatesUpdated: () {
                  if (mounted && !_isDisposed) {
                    setState(() {});
                  }
                },
                onCameraFitNeeded: (memories) {
                  _fitMapToFilteredMemories(memories, animated: true);
                },
              );
            });
          }

          // ======================================================
          // FILTRO
          // ======================================================

          final filteredMemories = allMemories.where((memory) {
            return _matchesCategory(memory, _selectedCategory);
          }).toList();

          // ======================================================
          // AGRUPACIÓN POR COORDENADAS
          // ======================================================

          final Map<String, List<MemoryModel>> groupedMemories = {};

          final Map<String, LatLng> groupCenters = {};

          for (final memory in filteredMemories) {
            final point = _geocodingService.memoryCoordinates[memory.id];

            if (point == null) {
              continue;
            }

            final key = _buildCoordinateGroupKey(point);

            groupedMemories.putIfAbsent(key, () => []).add(memory);

            groupCenters[key] = point;
          }

          // ======================================================
          // CREAR MARKERS
          // ======================================================

          final List<Marker> markers = [];

          groupedMemories.forEach((groupKey, memories) {
            final center = groupCenters[groupKey];

            if (center == null) {
              return;
            }

            // --------------------------------------------------
            // UN SOLO RECUERDO
            // --------------------------------------------------

            if (memories.length == 1) {
              final memory = memories.first;

              final originalPoint =
                  _geocodingService.memoryCoordinates[memory.id];

              if (originalPoint == null) {
                return;
              }

              markers.add(
                MapMarkerBuilder.buildMarker(
                  memory: memory,
                  point: originalPoint,
                  getCategoryColor: _getCategoryColor,
                  onMarkerTapped: _onMarkerTapped,
                ),
              );

              return;
            }

            // --------------------------------------------------
            // VARIOS RECUERDOS
            // --------------------------------------------------

            final isExpanded = _expandedSpiderfyGroups.contains(groupKey);

            final firstMemory = memories.first;

            final categoryColor = _getCategoryColor(firstMemory.category);

            // --------------------------------------------------
            // MARCADOR CENTRAL
            // --------------------------------------------------

            markers.add(
              MapMarkerBuilder.buildSpiderfyGroupMarker(
                point: center,
                count: memories.length,
                categoryColor: categoryColor,
                isExpanded: isExpanded,
                spiderfyAnimationDuration: _spiderfyAnimationDuration,
                onTap: () {
                  MemoryGroupPicker.show(
                    context: context,
                    memories: memories,
                    getCategoryColor: _getCategoryColor,
                    onMemorySelected: _onMarkerTapped,
                  );
                },
              ),
            );

            // --------------------------------------------------
            // MARCADORES ABIERTOS
            // --------------------------------------------------

            if (isExpanded) {
              for (int i = 0; i < memories.length; i++) {
                final memory = memories[i];

                final spiderPoint = _getSpiderfyPoint(
                  center: center,
                  index: i,
                  count: memories.length,
                );

                markers.add(
                  MapMarkerBuilder.buildSpiderfyMemoryMarker(
                    memory: memory,
                    point: spiderPoint,
                    center: center,
                    index: i,
                    count: memories.length,
                    getCategoryColor: _getCategoryColor,
                    onMarkerTapped: _onMarkerTapped,
                    getSpiderfyRadius: _getSpiderfyRadius,
                  ),
                );
              }
            }
          });

          // ======================================================
          // INTERFAZ
          // ======================================================

          return Stack(
            children: [
              // ==================================================
              // MAPA
              // ==================================================
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _peninsulaCenter,
                  initialZoom: _peninsulaZoom,
                  minZoom: 3.0,
                  maxZoom: 18.0,

                  // ------------------------------------------------
                  // INTERACCIÓN MAPA
                  // ------------------------------------------------
                  onPointerDown: (event, point) {
                    _isUserInteractingWithMap = true;

                    _closeAllSpiderfyGroups();
                  },

                  onPointerUp: (event, point) {
                    Future.delayed(const Duration(milliseconds: 350), () {
                      if (!_isDisposed && mounted) {
                        _isUserInteractingWithMap = false;
                      }
                    });
                  },
                ),
                children: [
                  TileLayer(
                    // CARTO (proveedor anterior) empezó a exigir una API
                    // key incluso en su capa gratuita — se cambia a las
                    // teselas estándar de OpenStreetMap, gratuitas sin
                    // registro, coherente con el resto del proyecto
                    // (coste cero).
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.palito.app',
                    maxZoom: 19,
                  ),

                  // ------------------------------------------------
                  // MARKERS
                  // ------------------------------------------------
                  MarkerLayer(markers: markers),
                ],
              ),

              // ==================================================
              // HEADER / FILTROS
              // ==================================================
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    MediaQuery.of(context).padding.top + 8,
                    12,
                    16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Volver al inicio',
                        onPressed: () {
                          _closeAllSpiderfyGroups();

                          context.go('/');
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF0F172A),
                            size: 22,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filterCategories.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cat = _filterCategories[index];

                              final isSelected =
                                  (_selectedCategory ?? 'Todas') == cat;

                              return FilterChip(
                                label: Text(
                                  cat,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (!selected && cat != 'Todas') {
                                    return;
                                  }

                                  _closeAllSpiderfyGroups();

                                  setState(() {
                                    _selectedCategory = cat == 'Todas'
                                        ? null
                                        : cat;
                                  });

                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (_isDisposed || !mounted) {
                                      return;
                                    }

                                    _fitMapToFilteredMemories(
                                      allMemories,
                                      animated: true,
                                    );
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: const Color(0xFFFFD400),
                                checkmarkColor: const Color(0xFF0F172A),
                                elevation: 3,
                                shadowColor: Colors.black26,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
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
                // Sin sumar el área segura, el contador quedaba justo encima
                // del indicador de inicio del iPhone, donde el gesto del
                // sistema se come el toque.
                bottom: 30 + MediaQuery.viewPaddingOf(context).bottom,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 18,
                        color: Color(0xFFFF4D29),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${filteredMemories.length} '
                        '${filteredMemories.length == 1 ? 'recuerdo' : 'recuerdos'}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
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
                bottom: 30 + MediaQuery.viewPaddingOf(context).bottom,
                right: 20,
                child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  onPressed: _goToCurrentLocation,
                  child: const Icon(Icons.my_location_rounded, size: 24),
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
    _log('🗺️ MAP PAGE DISPOSE');

    _isDisposed = true;

    _geocodingService.dispose();

    _cameraAnimationController?.stop();

    _cameraAnimationController?.dispose();

    _cameraAnimationController = null;

    _spiderfyAnimationController?.stop();

    _spiderfyAnimationController?.dispose();

    _spiderfyAnimationController = null;

    _expandedSpiderfyGroups.clear();

    super.dispose();
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
