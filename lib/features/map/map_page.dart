import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/providers/memory_map_provider.dart';
import '../../../../../core/models/memory_model.dart';
import 'services/memory_geocoding_service.dart';
import 'map_fit.dart';
import 'widgets/map_marker_builder.dart';
import 'widgets/memory_bottom_sheet.dart';
import 'widgets/memory_group_picker.dart';
import '../../core/utils/app_log.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/theme/tokens/app_animation.dart';
import '../../core/theme/components/app_dock.dart';
import '../../core/theme/components/neo_pressable.dart';
import '../../core/theme/components/category_chip.dart';

/// Paleta de categorías de los marcadores del mapa.
///
/// Excepción deliberada al sistema de tokens de marca: navy/amarillo/coral
/// son tres colores y aquí hacen falta ocho, uno por categoría, más un color
/// de reserva — no hay forma de expresar "ocho colores distintos entre sí"
/// con una paleta de marca de tres. Cada valor está medido en contraste
/// contra el texto e iconos BLANCOS que dibuja [MapMarkerBuilder] encima
/// (WCAG AA, texto pequeño y en negrita: mínimo 4,5:1); tres de los ocho
/// originales no llegaban (croqueta 3,79:1, tortilla 2,65:1, atención
/// 4,44:1) y se han oscurecido manteniendo el matiz.
abstract final class _MapCategoryColors {
  static const Color croqueta = Color(0xFFBF360C); // 5,60:1
  static const Color ensaladilla = Color(0xFF00838F); // 4,52:1
  static const Color tortilla = Color(0xFF8D5300); // 6,23:1
  static const Color menu = Color(0xFF6A1B9A); // 9,39:1
  static const Color plato = Color(0xFFC2185B); // 5,87:1
  static const Color postre = Color(0xFF00695C); // 6,61:1
  static const Color decoracion = Color(0xFF283593); // 10,39:1
  static const Color atencion = Color(0xFFC23C13); // 5,32:1
  static const Color fallback = Color(0xFF1E293B); // 14,63:1
}

class MapPage extends ConsumerStatefulWidget {
  final String? initialCategory;

  const MapPage({super.key, this.initialCategory});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}


/// A qué altura tienen que flotar los controles del Mapa para no quedar
/// debajo del dock.
///
/// El dock vive en un `Stack` por delante del contenido (ver main.dart) y
/// ocupa desde `área segura + 12` hasta `+ AppDock.height`. Cualquier cosa
/// que se pinte por debajo de esa línea existe pero no se puede tocar.
double _kOverlayBottom(BuildContext context) =>
    AppDock.height + 28 + MediaQuery.viewPaddingOf(context).bottom;

class _MapPageState extends ConsumerState<MapPage>
    with TickerProviderStateMixin {
  // ============================================================
  // CONSTANTES
  // ============================================================

  /// ENCUADRE DE ARRANQUE: EL MUNDO, NO MADRID.
  ///
  /// El mapa abría siempre en la Puerta del Sol con zoom 6,2, es decir, con
  /// la península ocupando la pantalla entera. Para quien tiene sus platos
  /// en Sevilla eso parece un detalle bonito; para quien acaba de instalar
  /// la app en Ciudad de México, en Tokio o en Buenos Aires, el mapa de su
  /// diario de comidas se abre en otro continente. Y la app no es española
  /// por dentro: las coordenadas, el geocodificador y las teselas de OSM
  /// funcionan igual en los cinco continentes. Lo único que era español
  /// era esta constante.
  ///
  /// Ahora el arranque es el mundo, y encima se cumple una de estas tres,
  /// por orden:
  ///
  /// 1. Si hay recuerdos con coordenadas, la cámara **salta** —sin volar—
  ///    al encuadre que los contiene a todos. Es lo que pasa siempre que
  ///    el diario tiene algo dentro, así que el mundo casi nunca se llega
  ///    a ver.
  /// 2. Si el diario está vacío pero ya nos habían dado permiso de
  ///    ubicación, se va a la última posición conocida. Sin pedir permiso
  ///    y sin encender el GPS: `getLastKnownPosition()` es instantáneo y
  ///    no muestra ningún diálogo.
  /// 3. Si no, se queda el mundo. Que es la respuesta honesta a "todavía
  ///    no sé nada de ti".
  static const LatLng _worldCenter = LatLng(20.0, 0.0);

  static const double _worldZoom = 1.2;

  /// Zoom para la ubicación del propio dispositivo cuando el diario está
  /// vacío: ciudad, no calle. No sabemos aún dónde come esta persona.
  static const double _aroundMeZoom = 10.5;

  static const Duration _cameraAnimationDuration = AppAnimation.camera;

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

  /// El primer encuadre no vuela: salta.
  ///
  /// La cámara arranca mirando al mundo entero, así que animar el primer
  /// ajuste sería un vuelo de dos continentes cada vez que se abre el mapa
  /// —bonito la primera vez, cansino la vigésima, y encima con las teselas
  /// cargándose a medio camino—. Los ajustes siguientes (cambiar de filtro,
  /// añadir un plato) sí se animan: ahí el movimiento explica qué ha
  /// cambiado.
  bool _hasFittedOnce = false;

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

    _centerOnMeIfDiaryIsEmpty();
  }

  /// Si el diario todavía no tiene ningún plato en el mapa, colocar la
  /// cámara alrededor de quien lo está mirando.
  ///
  /// Con reglas estrictas, porque abrir una pestaña no es motivo para pedir
  /// nada:
  ///
  /// - **No pide permiso.** `checkPermission()` solo consulta lo que ya hay
  ///   decidido; si no está concedido, no pasa nada y se queda el mundo.
  /// - **No enciende el GPS.** `getLastKnownPosition()` devuelve la última
  ///   posición que el sistema ya tenía guardada, al instante y sin gastar
  ///   batería. Si no hay ninguna, no pasa nada.
  /// - **Cede siempre.** Si para cuando contesta ya se ha encuadrado el
  ///   diario ([_hasFittedOnce]) o la persona ha tocado el mapa, no se mueve
  ///   nada: los platos mandan sobre la ubicación, y la persona sobre todo.
  Future<void> _centerOnMeIfDiaryIsEmpty() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();

      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }

      final Position? last = await Geolocator.getLastKnownPosition();

      if (last == null || _isDisposed || !mounted) return;
      if (_hasFittedOnce || _isUserInteractingWithMap) return;
      if (!_isValidCoordinate(last.latitude, last.longitude)) return;

      _animatedMove(
        LatLng(last.latitude, last.longitude),
        _aroundMeZoom,
        false,
      );
    } catch (e) {
      // Que no haya ubicación disponible no es un error que contar: el
      // mapa del mundo es una respuesta perfectamente válida.
      _log('🗺️ Sin ubicación previa para centrar: $e');
    }
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
  // 3.0 no dejaba ver el mundo entero: en una pantalla de móvil el planeta
  // no cabe por debajo de zoom ~1,5. Con el tope en 3 era **imposible**
  // encuadrar a la vez un plato de Sevilla y uno de Tokio: el cálculo de
  // encuadre pedía zoom 1,1 y este `clamp` lo subía a 3, dejando la mitad
  // de los marcadores fuera de pantalla sin ninguna pista de que estaban
  // ahí. OSM sirve teselas desde zoom 0.
  static const double _mapMinZoom = 1.0;

  /// Zoom máximo utilizado por la aplicación.
  static const double _mapMaxZoom = 18.0;

  /// Zoom utilizado cuando solo existe un recuerdo.
  /// Con un solo recuerdo, la cámara se plantaba en 13,5: la calle, con el
  /// marcador flotando sobre un plano de portales sin nada alrededor. Un
  /// mapa así no dice "aquí comiste", dice "estás perdido": no se reconoce
  /// el barrio, ni la ciudad, ni si eso está cerca de casa. A 11,0 se ve la
  /// ciudad entera con el punto dentro, que es la respuesta a la pregunta
  /// que se hace al abrir el mapa. Para el portal exacto está el zoom.
  static const double _singleMemoryZoom = 11.0;

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
    bool force = false,
  }) {
    if (_isDisposed || !mounted) return;

    // Los ajustes automáticos ceden el paso mientras alguien está tocando
    // el mapa: nada peor que una cámara que te corrige la mano. Pero cuando
    // el ajuste lo ha pedido la persona ([force]), manda ella.
    if (!force && (_isFittingCamera || _isUserInteractingWithMap)) {
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

      final bool fly = animated && _hasFittedOnce;
      _hasFittedOnce = true;

      if (points.length == 1) {
        _animatedMove(points.first, _singleMemoryZoom, fly);

        _releaseCameraFitLock();

        return;
      }

      // ==========================================================
      // VARIOS PUNTOS
      // ==========================================================

      final GeoFit fit = computeGeoFit(points);

      final center = fit.center;

      final targetZoom = _calculateBoundsZoom(fit);

      _log('🎯 Encuadre calculado');

      _log('🎯 Norte: ${fit.north}');

      _log('🎯 Sur: ${fit.south}');

      _log('🎯 Ancho en grados: ${fit.longitudeSpan}');

      _log(
        '🎯 Centro: '
        '${center.latitude}, '
        '${center.longitude}',
      );

      _log('🎯 Zoom calculado: $targetZoom');

      // ==========================================================
      // MOVER CÁMARA
      // ==========================================================

      _animatedMove(center, targetZoom, fly);

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
  double _calculateBoundsZoom(GeoFit fit) {
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

      double longitudeSpan = fit.longitudeSpan;

      // Evitamos división por cero.
      if (longitudeSpan < 0.000001) {
        longitudeSpan = 0.000001;
      }

      // ==========================================================
      // EXTENSIÓN LATITUDINAL
      // ==========================================================

      // ==========================================================
      // WEB MERCATOR
      // ==========================================================

      double mercatorY(double latitude) {
        // Evitamos problemas cerca de los polos.
        final safeLatitude = latitude.clamp(-85.05112878, 85.05112878);

        final latRad = safeLatitude * pi / 180.0;

        return log(tan(pi / 4 + latRad / 2));
      }

      final northY = mercatorY(fit.north);

      final southY = mercatorY(fit.south);

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
        curve: AppAnimation.inOut,
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
      return _MapCategoryColors.croqueta;
    }

    if (cat.contains('ensaladilla')) {
      return _MapCategoryColors.ensaladilla;
    }

    if (cat.contains('tortilla')) {
      return _MapCategoryColors.tortilla;
    }

    if (cat.contains('menu')) {
      return _MapCategoryColors.menu;
    }

    if (cat.contains('plato')) {
      return _MapCategoryColors.plato;
    }

    if (cat.contains('postre') || cat.contains('helado')) {
      return _MapCategoryColors.postre;
    }

    if (cat.contains('decoracion') || cat.contains('espacio')) {
      return _MapCategoryColors.decoracion;
    }

    if (cat.contains('atencion')) {
      return _MapCategoryColors.atencion;
    }

    return _MapCategoryColors.fallback;
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

          // Antes esto pintaba `'Error al cargar recuerdos:\n$error'`, así
          // que quien solo quería ver dónde había comido se encontraba con
          // `[cloud_firestore/permission-denied] The caller does not have
          // permission to execute the specified operation.` centrado en la
          // pantalla, sin reintentar, sin volver y sin explicación. La
          // pestaña Mapa se quedaba inservible hasta reiniciar la app.
          //
          // Inicio ya resolvía bien este mismo caso; el Mapa se quedó sin
          // hacer.
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 44,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hemos podido cargar el mapa',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Suele ser la conexión. Tus recuerdos siguen guardados: '
                    'no se ha perdido nada.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  NeoActionButton(
                    label: 'Volver a intentarlo',
                    icon: Icons.refresh_rounded,
                    background: AppColors.primary,
                    expand: false,
                    onTap: () => ref.invalidate(memoryModelsStreamProvider),
                  ),
                ],
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
                  initialCenter: _worldCenter,
                  initialZoom: _worldZoom,
                  minZoom: _mapMinZoom,
                  maxZoom: _mapMaxZoom,

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
                      // AQUÍ HABÍA UNA FLECHA DE "VOLVER AL INICIO".
                      //
                      // El Mapa es una pestaña raíz, igual que Inicio, Zona
                      // Gamer y Perfil: de una pestaña no se "vuelve", se
                      // cambia. Una flecha atrás en la barra superior dice
                      // que estás dentro de algo, y no lo estás — el dock ya
                      // te lleva a donde quieras con un toque.
                      //
                      // Perfil y Zona Gamer ya la tenían quitada; el Mapa se
                      // quedó sin igualar. Además hacía `context.go('/')`,
                      // que es exactamente lo que hace el botón de Inicio
                      // del dock, treinta píxeles más abajo.
                      //
                      // Los chips de categoría se quedan con todo el ancho,
                      // que en esta pantalla iban apretados.

                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filterCategories.length,
                            // Sin hueco AQUÍ: `CategoryChip` ya trae el
                            // suyo de 8. Con los dos, el Mapa separaba el
                            // doble que Inicio con el mismo componente.
                            separatorBuilder: (_, _) => const SizedBox.shrink(),
                            itemBuilder: (context, index) {
                              final cat = _filterCategories[index];

                              final isSelected =
                                  (_selectedCategory ?? 'Todas') == cat;

                              // Mismo chip que Inicio. Antes esto era un `FilterChip` de
                              // Material: pastilla perfecta, palomita del
                              // catálogo y tipografía del sistema, dentro de
                              // una app con lenguaje propio. Nadie distingue
                              // dos implementaciones, pero sí nota que el
                              // filtro de Inicio y el del Mapa "no son el
                              // mismo control".
                              return CategoryChip(
                                label: cat,
                                isSelected: isSelected,
                                onTap: () {
                                  if (isSelected && cat != 'Todas') return;

                                  _closeAllSpiderfyGroups();

                                  setState(() {
                                    _selectedCategory = cat == 'Todas'
                                        ? null
                                        : cat;
                                  });

                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (_isDisposed || !mounted) return;

                                    _fitMapToFilteredMemories(
                                      allMemories,
                                      animated: true,
                                    );
                                  });
                                },
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
              // ==================================================
              // SIN NADA QUE ENSEÑAR
              // ==================================================
              //
              // Antes, un mapa sin chinchetas era un mapa de España y nada
              // más: ni qué es esta pantalla, ni por qué está vacía, ni qué
              // hacer. Y hay dos motivos distintos para que lo esté —no has
              // guardado nada todavía, o el filtro no encuentra nada—, que
              // piden respuestas distintas.
              if (filteredMemories.isEmpty)
                Positioned(
                  left: 24,
                  right: 24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: AppColors.textPrimary,
                            width: 2,
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: AppColors.textPrimary,
                              blurRadius: 0,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.push_pin_outlined,
                              size: 32,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedCategory == null
                                  ? 'Aquí aparecerán tus sitios'
                                  : 'Ninguno de $_selectedCategory por aquí',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedCategory == null
                                  ? 'Cada recuerdo que guardes con una '
                                        'dirección se planta aquí como una '
                                        'chincheta.'
                                  : 'Prueba con "Todas" para ver el resto.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // CONTADOR
              // ==================================================
              Positioned(
                // Mismo cálculo que el botón de ubicación: por encima del
                // dock, no solo por encima del área segura. Antes quedaba
                // tapado igual que él.
                bottom: _kOverlayBottom(context),
                left: 20,
                // EL CONTADOR AHORA ES EL BOTÓN DE "VÉRLOS TODOS".
                //
                // El encuadre automático se aparta en cuanto tocas el mapa,
                // que es lo correcto. El problema era que no había vuelta:
                // te alejabas arrastrando, perdías de vista los marcadores y
                // no existía ningún control para recuperarlos — con platos
                // en dos países, encontrarlos a mano es imposible. La
                // pastilla que ya decía cuántos hay es el sitio evidente
                // para "enséñamelos".
                child: Semantics(
                  button: true,
                  label:
                      '${filteredMemories.length} '
                      '${filteredMemories.length == 1 ? 'recuerdo' : 'recuerdos'} '
                      'en el mapa. Toca para verlos todos',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: filteredMemories.isEmpty
                          ? null
                          : () => _fitMapToFilteredMemories(
                              allMemories,
                              force: true,
                            ),
                      child: ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.place_rounded,
                                size: 18,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${filteredMemories.length} '
                                '${filteredMemories.length == 1 ? 'recuerdo' : 'recuerdos'}',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (filteredMemories.isNotEmpty) ...<Widget>[
                                const SizedBox(width: 8),
                                Container(
                                  width: 1,
                                  height: 16,
                                  color: AppColors.tintMuted,
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.zoom_out_map_rounded,
                                  size: 17,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ==================================================
              // ATRIBUCIÓN DE OPENSTREETMAP
              // ==================================================
              //
              // No estaba, y no es opcional.
              //
              // Las teselas son de OpenStreetMap, cuyos datos van bajo la
              // licencia ODbL: usarlos **obliga** a decir de dónde salen, a
              // la vista, en la propia pantalla del mapa. Además la política
              // de uso de sus servidores lo exige por escrito, y quien la
              // incumple se expone a que le corten las teselas — es decir,
              // a que el mapa de la app deje de cargar de un día para otro,
              // sin aviso y sin nada que tocar en el código.
              //
              // Justo antes de gastar dinero en publicidad, ese riesgo no
              // merece la pena por ahorrarse una línea de ocho píxeles.
              Positioned(
                bottom: _kOverlayBottom(context) + 62,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    '© OpenStreetMap',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),

              // ==================================================
              // BOTÓN UBICACIÓN
              // ==================================================
              Positioned(
                // POR ENCIMA DEL DOCK.
                //
                // Estaba a `30 + área segura`. El dock ocupa desde
                // `área segura + 12` hasta `+ 88` (ver main.dart y
                // AppDock.height) y va en un Stack por delante del
                // contenido: el botón caía entero debajo y **no se podía
                // pulsar**. Es la función principal de esta pantalla.
                //
                // `_kOverlayBottom` lo deriva del alto real del dock en vez
                // de un número a ojo, para que no se vuelva a descuadrar si
                // el dock cambia de tamaño.
                bottom: _kOverlayBottom(context),
                right: 20,
                child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 6,
                  // Sin esto VoiceOver anunciaba "botón" y nada más.
                  tooltip: 'Centrar el mapa en dónde estás',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
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
