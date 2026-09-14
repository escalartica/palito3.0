import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/services/storage_image_service.dart';

/// Resultado de [MemorySaveController.save]: la memoria ya persistida
/// junto con los avisos no bloqueantes (foto/geocodificación) que el
/// llamador pueda querer mostrar en un SnackBar.
class MemorySaveResult {
  final MemoryModel memory;
  final bool couldNotUploadPhoto;
  final bool couldNotGeocode;

  const MemorySaveResult({
    required this.memory,
    required this.couldNotUploadPhoto,
    required this.couldNotGeocode,
  });
}

/// Orquesta el guardado de un recuerdo: sube la foto nueva (si la hay),
/// resuelve la ubicación (reutilizando coordenadas ya conocidas o
/// geocodificando la dirección escrita) y delega toda la persistencia
/// (SharedPreferences + Firestore, colecciones memories/locations) en
/// [MemoryNotifier] vía `memoryProvider`. No escribe en Firestore por su
/// cuenta, para no duplicar la escritura que ya hace `MemoryNotifier`.
///
/// Deliberadamente no conoce `BuildContext` ni controladores de
/// animación: mostrar SnackBars, gestionar el estado de "guardando" y
/// navegar de vuelta sigue siendo responsabilidad de
/// `_MemoryFormPageState`, que envuelve la llamada a [save] en su propio
/// try/catch/finally.
class MemorySaveController {
  final WidgetRef ref;

  MemorySaveController(this.ref);

  Future<MemorySaveResult> save({
    required MemoryModel? existingMemory,
    required String restaurantName,
    required String addressText,
    required LocationData? currentGpsLocation,
    required bool wouldReturn,
    required double rating,
    required Uint8List? tempMediaBytes,
    required String? existingImagePath,
    required String category,
    required Map<String, dynamic> dynamicData,
    required String description,
    required String otroSabor,
  }) async {
    // ========================================================
    // 0. ID (se genera antes para poder usarlo como carpeta de Storage)
    // ========================================================

    // El notifier se captura AQUÍ, antes del primer `await`. Leerlo después
    // de la subida a Cloudinary y de la geocodificación (decenas de segundos
    // con mala cobertura) podía encontrarse el widget ya destruido:
    // `Bad state: Cannot use "ref" after the widget was disposed`, y el
    // recuerdo no se guardaba en ninguna parte sin que el usuario se enterara.
    final MemoryNotifier memoryNotifier = ref.read(memoryProvider.notifier);

    final memoryId = existingMemory?.id ?? const Uuid().v4();

    // ========================================================
    // 1. GUARDAR IMAGEN (Firebase Storage — visible en ambos móviles)
    // ========================================================

    List<String> finalImagePaths = List<String>.from(
      existingMemory?.imageUrls ?? <String>[],
    );

    bool couldNotUploadPhoto = false;

    if (tempMediaBytes != null) {
      // La subida de la foto no debe poder tirar el guardado del resto
      // del recuerdo (título, puntuación, campos dinámicos...) si hay un
      // problema de red puntual — algo frecuente en un bar/restaurante.
      // Si falla, se conserva la foto anterior (si la había) y se avisa,
      // en vez de perderlo todo.
      try {
        final downloadUrl = await StorageImageService.uploadMemoryImage(
          memoryId: memoryId,
          bytes: tempMediaBytes,
        );

        finalImagePaths = [downloadUrl];
      } catch (e) {
        _log('⚠️ No se pudo subir la foto del recuerdo: $e');
        couldNotUploadPhoto = true;
      }
    } else if (existingImagePath != null && existingImagePath.isNotEmpty) {
      finalImagePaths = [existingImagePath];
    }

    // ========================================================
    // 2. RESOLVER UBICACIÓN
    // ========================================================

    LocationData? resolvedLocation = resolveKnownLocation(
      addressText: addressText,
      currentGpsLocation: currentGpsLocation,
      existingMemory: existingMemory,
    );

    if (resolvedLocation != null) {
      _log(
        '📍 Usando coordenadas ya conocidas (GPS actual o recuerdo '
        'existente): ${resolvedLocation.lat}, ${resolvedLocation.lng}',
      );
    }

    resolvedLocation ??= await _resolveAddressToLocation(addressText);

    bool couldNotGeocode = false;

    if (resolvedLocation == null ||
        resolvedLocation.lat == null ||
        resolvedLocation.lng == null) {
      // No bloqueamos el guardado del recuerdo por esto: el usuario
      // escribió la dirección a mano y no hay razón para tirar el resto
      // del formulario (foto, puntuación, campos dinámicos...) solo
      // porque el servicio de geocodificación no pudo resolverla.
      // Se guarda con el texto tal cual; simplemente no tendrá pin en
      // el mapa hasta que se corrija (p. ej. usando el botón GPS).
      _log(
        '⚠️ No se pudieron obtener coordenadas '
        'para la ubicación "$addressText". '
        'Se guardará el recuerdo solo con el texto de la dirección.',
      );

      resolvedLocation = LocationData(address: addressText);

      couldNotGeocode = true;
    }

    final double? lat = resolvedLocation.lat;

    final double? lng = resolvedLocation.lng;

    _log(
      '📍 UBICACIÓN FINAL: '
      'address=$addressText, '
      'lat=$lat, '
      'lng=$lng',
    );

    // ========================================================
    // 3. LOCATIONDATA FINAL
    // ========================================================

    final finalLocation = LocationData(
      address: addressText,
      lat: lat,
      lng: lng,
    );

    // ========================================================
    // 4. DATOS DINÁMICOS
    // ========================================================

    final Map<String, dynamic> finalDynamicData = Map<String, dynamic>.from(
      dynamicData,
    );

    if (description.isNotEmpty) {
      finalDynamicData['description'] = description;
    } else {
      finalDynamicData.remove('description');
    }

    // Los recuerdos antiguos guardaban la nota en 'nota'. El formulario la
    // lee de ahí al editar, pero solo escribía 'description': el documento
    // se quedaba con DOS notas distintas, la nueva y la vieja.
    finalDynamicData.remove('nota');

    if (otroSabor.isNotEmpty) {
      finalDynamicData['otro_sabor'] = otroSabor;
    }

    // ========================================================
    // 6. MODELO FINAL
    // ========================================================

    final newMemory = MemoryModel(
      id: memoryId,
      title: restaurantName,
      restaurantName: restaurantName,
      location: finalLocation,
      wouldReturn: wouldReturn,
      rating: rating,
      imageUrls: finalImagePaths,
      videoUrl: existingMemory?.videoUrl,
      date: existingMemory?.date ?? DateTime.now(),
      category: category,
      specificFields: finalDynamicData,
    );

    // ========================================================
    // 7. PERSISTIR (SharedPreferences + Firestore, vía MemoryNotifier)
    // ========================================================
    //
    // addMemory/updateMemory ya escriben en las dos colecciones de
    // Firestore (memories y locations) — no hay que repetir la
    // escritura aquí. Se espera a que termine para que los errores de
    // Firestore lleguen al try/catch de quien llama a `save`.

    if (existingMemory != null) {
      await memoryNotifier.updateMemory(newMemory);
    } else {
      await memoryNotifier.addMemory(newMemory);
    }

    _log('✅ RECUERDO GUARDADO COMPLETAMENTE');

    _log(
      '🗺️ COORDENADAS DISPONIBLES PARA EL MAPA: '
      '$lat, $lng',
    );

    return MemorySaveResult(
      memory: newMemory,
      couldNotUploadPhoto: couldNotUploadPhoto,
      couldNotGeocode: couldNotGeocode,
    );
  }

  // ==========================================================
  // GEOCODIFICACIÓN
  // ==========================================================

  /// Decide si ya conocemos las coordenadas de [addressText] sin
  /// necesidad de geocodificar: reutiliza el GPS actual si su dirección
  /// coincide textualmente con la escrita, o si no las coordenadas ya
  /// guardadas en [existingMemory] si su dirección también coincide.
  /// Devuelve `null` si ninguna de las dos aplica (habrá que
  /// geocodificar). Extraído como método estático puro para poder
  /// testear esta decisión sin necesidad de un `WidgetRef` ni de red.
  static LocationData? resolveKnownLocation({
    required String addressText,
    required LocationData? currentGpsLocation,
    required MemoryModel? existingMemory,
  }) {
    if (currentGpsLocation != null &&
        currentGpsLocation.lat != null &&
        currentGpsLocation.lng != null &&
        currentGpsLocation.address.trim().toLowerCase() ==
            addressText.toLowerCase()) {
      return LocationData(
        address: addressText,
        lat: currentGpsLocation.lat,
        lng: currentGpsLocation.lng,
      );
    }

    if (existingMemory != null &&
        existingMemory.location.lat != null &&
        existingMemory.location.lng != null &&
        existingMemory.location.address.trim().toLowerCase() ==
            addressText.toLowerCase()) {
      return LocationData(
        address: addressText,
        lat: existingMemory.location.lat,
        lng: existingMemory.location.lng,
      );
    }

    return null;
  }

  /// Reconoce coordenadas escritas a mano en la propia dirección, con el
  /// formato `GPS: lat, lng` (lo genera el botón de GPS cuando no hay
  /// conexión para geocodificar la dirección legible). `null` si no hay
  /// ninguna coincidencia o las coordenadas están fuera de rango.
  static LocationData? parseEmbeddedGpsCoordinates(String cleanAddress) {
    final gpsRegex = RegExp(
      r'GPS:\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
      caseSensitive: false,
    );

    final gpsMatch = gpsRegex.firstMatch(cleanAddress);

    if (gpsMatch == null) {
      return null;
    }

    final lat = double.tryParse(gpsMatch.group(1) ?? '');
    final lng = double.tryParse(gpsMatch.group(2) ?? '');

    if (lat == null ||
        lng == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }

    return LocationData(address: cleanAddress, lat: lat, lng: lng);
  }

  /// Construye, en orden de prioridad, las direcciones que se probarán
  /// contra el geocodificador: la dirección tal cual, con ", España"
  /// añadido si no la menciona ya, y con un caso especial para
  /// "Medellín" (que por defecto geocodificaría a Colombia, no a la
  /// pedanía de Badajoz).
  static List<String> buildGeocodingQueries(String cleanAddress) {
    final queries = <String>[cleanAddress];

    if (!cleanAddress.toLowerCase().contains('españa') &&
        !cleanAddress.toLowerCase().contains('spain')) {
      queries.add('$cleanAddress, España');
    }

    if (cleanAddress.toLowerCase() == 'medellín' ||
        cleanAddress.toLowerCase() == 'medellin') {
      queries.insert(0, 'Medellín, Badajoz, España');
    }

    return queries;
  }

  Future<LocationData?> _resolveAddressToLocation(String address) async {
    final cleanAddress = address.trim();

    if (cleanAddress.isEmpty) {
      return null;
    }

    final embeddedGps = parseEmbeddedGpsCoordinates(cleanAddress);

    if (embeddedGps != null) {
      return embeddedGps;
    }

    final queries = buildGeocodingQueries(cleanAddress);

    for (final query in queries) {
      try {
        _log('🔎 Intentando geocodificar: "$query"');

        final locations = await locationFromAddress(query);

        if (locations.isNotEmpty) {
          final location = locations.first;

          final lat = location.latitude;
          final lng = location.longitude;

          if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
            _log(
              '✅ Coordenadas encontradas para "$query": '
              '$lat, $lng',
            );

            return LocationData(address: cleanAddress, lat: lat, lng: lng);
          }
        }
      } catch (e) {
        _log('⚠️ Fallo geocodificando "$query": $e');
      }
    }

    _log(
      '❌ No se pudieron obtener coordenadas para: '
      '"$cleanAddress"',
    );

    return null;
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
