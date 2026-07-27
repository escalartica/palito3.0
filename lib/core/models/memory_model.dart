
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// ===========================================================================
/// LOCATION DATA
/// ===========================================================================
///
/// Modelo de ubicación asociado a una memoria.
///
/// Soporta:
/// - Dirección.
/// - Latitud.
/// - Longitud.
///
/// Las coordenadas son opcionales.
///
/// Firestore:
///     toMap()
///
/// JSON / SharedPreferences:
///     toJson()
///
/// En este modelo no existe ningún DateTime, Timestamp ni otro objeto
/// no serializable, por lo que toMap() y toJson() son equivalentes.
///
class LocationData {
  final String address;
  final double? lat;
  final double? lng;

  const LocationData({
    required this.address,
    this.lat,
    this.lng,
  });

  /// Indica si existe una dirección no vacía.
  bool get hasAddress {
    return address.trim().isNotEmpty;
  }

  /// Indica si existen latitud y longitud válidas.
  bool get hasCoordinates {
    return _isValidCoordinatePair(
      lat,
      lng,
    );
  }

  /// Devuelve las coordenadas como LatLng si son válidas.
  LatLng? get coordinates {
    if (!hasCoordinates) {
      return null;
    }

    return LatLng(
      lat!,
      lng!,
    );
  }

  /// Convierte la ubicación a Map.
  ///
  /// Compatible con Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'address': address,
      'lat': lat,
      'lng': lng,
    };
  }

  /// Convierte la ubicación a JSON.
  ///
  /// Todos los valores son compatibles con jsonEncode().
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'address': address,
      'lat': lat,
      'lng': lng,
    };
  }

  /// Crea LocationData desde un Map.
  ///
  /// Soporta:
  /// - lat
  /// - latitude
  /// - lng
  /// - longitude
  /// - address
  factory LocationData.fromMap(
    Map<String, dynamic> map,
  ) {
    final double? parsedLat =
        _parseCoordinate(
      map['lat'] ??
          map['latitude'],
      min: -90,
      max: 90,
    );

    final double? parsedLng =
        _parseCoordinate(
      map['lng'] ??
          map['longitude'],
      min: -180,
      max: 180,
    );

    return LocationData(
      address:
          _parseString(
            map['address'],
          ) ??
          '',
      lat: parsedLat,
      lng: parsedLng,
    );
  }

  /// Crea LocationData desde cualquier valor dinámico.
  ///
  /// Si el valor no es un Map, devuelve una ubicación vacía.
  factory LocationData.fromDynamic(
    dynamic value,
  ) {
    if (value is Map) {
      return LocationData.fromMap(
        Map<String, dynamic>.from(
          value,
        ),
      );
    }

    return const LocationData(
      address: '',
    );
  }

  /// Convierte un valor dinámico a coordenada válida.
  static double? _parseCoordinate(
    dynamic value, {
    required double min,
    required double max,
  }) {
    double? parsed;

    if (value is num) {
      parsed = value.toDouble();
    } else if (value is String &&
        value.trim().isNotEmpty) {
      parsed = double.tryParse(
        value.trim(),
      );
    }

    if (parsed == null) {
      return null;
    }

    if (!parsed.isFinite) {
      return null;
    }

    if (parsed < min ||
        parsed > max) {
      return null;
    }

    return parsed;
  }

  /// Comprueba si el par de coordenadas es válido.
  static bool _isValidCoordinatePair(
    double? lat,
    double? lng,
  ) {
    if (lat == null ||
        lng == null) {
      return false;
    }

    if (!lat.isFinite ||
        !lng.isFinite) {
      return false;
    }

    if (lat < -90 ||
        lat > 90) {
      return false;
    }

    if (lng < -180 ||
        lng > 180) {
      return false;
    }

    return true;
  }

  /// Convierte cualquier valor a String limpio.
  static String? _parseString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final String result =
        value.toString().trim();

    if (result.isEmpty) {
      return null;
    }

    return result;
  }

  /// Crea una copia de la ubicación.
  ///
  /// clearLat permite borrar explícitamente la latitud.
  ///
  /// clearLng permite borrar explícitamente la longitud.
  LocationData copyWith({
    String? address,
    double? lat,
    double? lng,
    bool clearLat = false,
    bool clearLng = false,
  }) {
    return LocationData(
      address:
          address ?? this.address,
      lat: clearLat
          ? null
          : (lat ?? this.lat),
      lng: clearLng
          ? null
          : (lng ?? this.lng),
    );
  }

  @override
  String toString() {
    return 'LocationData('
        'address: $address, '
        'lat: $lat, '
        'lng: $lng'
        ')';
  }
}

/// ===========================================================================
/// MEMORY MODEL
/// ===========================================================================
///
/// Modelo principal de los recuerdos gastronómicos.
///
/// Estructura Firestore recomendada:
///
/// {
///   id: '...',
///   title: '...',
///   restaurantName: '...',
///   location: {
///     address: '...',
///     lat: 40.4168,
///     lng: -3.7038,
///   },
///   wouldReturn: true,
///   rating: 4.5,
///   imageUrls: [],
///   videoUrl: null,
///   date: Timestamp,
///   category: 'General',
///   specificFields: {},
/// }
///
/// REPRESENTACIÓN INTERNA
///
/// date:
///     DateTime
///
/// FIRESTORE
///
/// toFirestore():
///     DateTime -> Timestamp
///
/// JSON / SHAREDPREFERENCES
///
/// toJson():
///     DateTime -> String ISO-8601
///
/// Esto permite que StorageService utilice:
///
///     jsonEncode(memory.toJson())
///
/// sin provocar errores de serialización.
///
class MemoryModel {
  final String id;
  final String title;
  final String restaurantName;
  final LocationData location;
  final bool wouldReturn;
  final double rating;
  final List<String> imageUrls;
  final String? videoUrl;
  final DateTime date;
  final String category;
  final Map<String, dynamic> specificFields;

  const MemoryModel({
    required this.id,
    required this.title,
    required this.restaurantName,
    required this.location,
    required this.wouldReturn,
    required this.rating,
    required this.imageUrls,
    this.videoUrl,
    required this.date,
    this.category = 'General',
    this.specificFields = const <String, dynamic>{},
  });

  /// =========================================================================
  /// GETTERS
  /// =========================================================================

  /// Dirección preparada para mostrar en UI.
  ///
  /// Si la dirección está vacía o coincide con el nombre del restaurante,
  /// se evita mostrar el restaurante como si fuese una dirección real.
  String get displayAddress {
    final String address =
        location.address.trim();

    final String restaurant =
        restaurantName.trim();

    if (address.isEmpty) {
      return 'Ubicación no especificada';
    }

    if (restaurant.isNotEmpty &&
        address.toLowerCase() ==
            restaurant.toLowerCase()) {
      return 'Ubicación no especificada';
    }

    return address;
  }

  /// Indica si existe una dirección útil.
  bool get hasAddress {
    return location.hasAddress;
  }

  /// Indica si existen coordenadas válidas.
  bool get hasCoordinates {
    return location.hasCoordinates;
  }

  /// Alias explícito de hasCoordinates.
  bool get hasValidCoordinates {
    return location.hasCoordinates;
  }

  /// Devuelve las coordenadas como LatLng.
  LatLng? get coordinates {
    return location.coordinates;
  }

  /// Indica si la memoria fue creada en los últimos 5 minutos.
  ///
  /// Las fechas futuras no se consideran recientes.
  bool get isRecent {
    final DateTime now =
        DateTime.now();

    final Duration difference =
        now.difference(date);

    return difference.inMinutes >= 0 &&
        difference.inMinutes < 5;
  }

  /// =========================================================================
  /// FROM FIRESTORE
  /// =========================================================================

  /// Crea un MemoryModel desde un DocumentSnapshot.
  ///
  /// El ID del documento se utiliza como fallback si el mapa no contiene
  /// un ID válido.
  factory MemoryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>>
        snapshot,
  ) {
    final Map<String, dynamic> data =
        snapshot.data() ??
            <String, dynamic>{};

    return MemoryModel.fromMap(
      data,
      documentId: snapshot.id,
    );
  }

  /// =========================================================================
  /// FROM MAP
  /// =========================================================================

  /// Crea un MemoryModel desde cualquier Map compatible.
  ///
  /// Soporta tanto el formato actual como nombres de campos antiguos.
  factory MemoryModel.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    // -----------------------------------------------------------------------
    // ID
    // -----------------------------------------------------------------------

    final String parsedId =
        _firstNonEmptyString([
              map['id'],
              map['memoryId'],
              map['memory_id'],
              documentId,
            ]) ??
            '';

    // -----------------------------------------------------------------------
    // TITLE
    // -----------------------------------------------------------------------

    final String parsedTitle =
        _firstNonEmptyString([
              map['title'],
              map['name'],
              map['restaurantName'],
              map['restaurant_name'],
            ]) ??
            '';

    // -----------------------------------------------------------------------
    // RESTAURANT NAME
    // -----------------------------------------------------------------------

    final String parsedRestaurantName =
        _firstNonEmptyString([
              map['restaurantName'],
              map['restaurant_name'],
              map['title'],
              map['name'],
            ]) ??
            '';

    // -----------------------------------------------------------------------
    // DATE
    // -----------------------------------------------------------------------

    final DateTime parsedDate =
        _parseDate(
      map['date'] ??
          map['createdAt'] ??
          map['created_at'] ??
          map['timestamp'] ??
          map['updatedAt'] ??
          map['updated_at'],
    );

    // -----------------------------------------------------------------------
    // LOCATION
    // -----------------------------------------------------------------------

    final Map<String, dynamic>
        locationMap =
        _buildLocationMap(
      map,
    );

    // -----------------------------------------------------------------------
    // WOULD RETURN
    // -----------------------------------------------------------------------

    final bool parsedWouldReturn =
        _parseBool(
      map['wouldReturn'] ??
          map['would_return'] ??
          map['returnAgain'] ??
          map['return_again'],
    );

    // -----------------------------------------------------------------------
    // RATING
    // -----------------------------------------------------------------------

    final double parsedRating =
        _parseRating(
      map['rating'] ??
          map['score'],
    );

    // -----------------------------------------------------------------------
    // IMAGE URLS
    // -----------------------------------------------------------------------

    final List<String>
        parsedImageUrls =
        _parseStringList(
      map['imageUrls'] ??
          map['image_urls'] ??
          map['images'] ??
          map['image_paths'],
    );

    // -----------------------------------------------------------------------
    // VIDEO URL
    // -----------------------------------------------------------------------

    final String? parsedVideoUrl =
        _parseNullableString(
      map['videoUrl'] ??
          map['video_url'] ??
          map['video'],
    );

    // -----------------------------------------------------------------------
    // CATEGORY
    // -----------------------------------------------------------------------

    final String parsedCategory =
        _firstNonEmptyString([
              map['category'],
              map['type'],
            ]) ??
            'General';

    // -----------------------------------------------------------------------
    // SPECIFIC FIELDS
    // -----------------------------------------------------------------------

    final Map<String, dynamic>
        parsedSpecificFields =
        _parseMap(
      map['specificFields'] ??
          map['specific_fields'],
    );

    return MemoryModel(
      id: parsedId,
      title: parsedTitle,
      restaurantName:
          parsedRestaurantName,
      location:
          LocationData.fromMap(
        locationMap,
      ),
      wouldReturn:
          parsedWouldReturn,
      rating:
          parsedRating,
      imageUrls:
          List<String>.unmodifiable(
        parsedImageUrls,
      ),
      videoUrl:
          parsedVideoUrl,
      date:
          parsedDate,
      category:
          parsedCategory,
      specificFields:
          Map<String, dynamic>.unmodifiable(
        parsedSpecificFields,
      ),
    );
  }

  /// =========================================================================
  /// FROM JSON
  /// =========================================================================

  /// Crea un MemoryModel desde JSON previamente guardado.
  ///
  /// Es equivalente a fromMap(), pero se mantiene como API explícita
  /// para trabajar con StorageService.
  factory MemoryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return MemoryModel.fromMap(
      json,
    );
  }

  /// =========================================================================
  /// LOCATION
  /// =========================================================================

  /// Construye una ubicación compatible con múltiples formatos históricos.
  ///
  /// Soporta:
  ///
  /// 1. location: { address, lat, lng }
  /// 2. lat/lng directamente.
  /// 3. latitude/longitude directamente.
  /// 4. address directamente.
  /// 5. locationAddress.
  /// 6. location_address.
  static Map<String, dynamic>
      _buildLocationMap(
    Map<String, dynamic> map,
  ) {
    final Map<String, dynamic>
        locationMap =
        <String, dynamic>{};

    // -----------------------------------------------------------------------
    // LOCATION ANIDADA
    // -----------------------------------------------------------------------

    final dynamic rawLocation =
        map['location'];

    if (rawLocation is Map) {
      locationMap.addAll(
        Map<String, dynamic>.from(
          rawLocation,
        ),
      );
    }

    // -----------------------------------------------------------------------
    // LATITUD
    // -----------------------------------------------------------------------

    if (!_hasUsableValue(
          locationMap['lat'],
        ) &&
        !_hasUsableValue(
          locationMap['latitude'],
        )) {
      if (map.containsKey('lat')) {
        locationMap['lat'] =
            map['lat'];
      } else if (map.containsKey(
        'latitude',
      )) {
        locationMap['lat'] =
            map['latitude'];
      }
    }

    // -----------------------------------------------------------------------
    // LONGITUD
    // -----------------------------------------------------------------------

    if (!_hasUsableValue(
          locationMap['lng'],
        ) &&
        !_hasUsableValue(
          locationMap['longitude'],
        )) {
      if (map.containsKey('lng')) {
        locationMap['lng'] =
            map['lng'];
      } else if (map.containsKey(
        'longitude',
      )) {
        locationMap['lng'] =
            map['longitude'];
      }
    }

    // -----------------------------------------------------------------------
    // DIRECCIÓN
    // -----------------------------------------------------------------------

    if (!_hasUsableValue(
      locationMap['address'],
    )) {
      if (_hasUsableValue(
        map['address'],
      )) {
        locationMap['address'] =
            map['address'];
      } else if (_hasUsableValue(
        map['locationAddress'],
      )) {
        locationMap['address'] =
            map['locationAddress'];
      } else if (_hasUsableValue(
        map['location_address'],
      )) {
        locationMap['address'] =
            map['location_address'];
      }
    }

    return locationMap;
  }

  /// Comprueba si un valor puede considerarse útil.
  static bool _hasUsableValue(
    dynamic value,
  ) {
    if (value == null) {
      return false;
    }

    if (value is String) {
      return value.trim().isNotEmpty;
    }

    return true;
  }

  /// =========================================================================
  /// STRING HELPERS
  /// =========================================================================

  /// Devuelve el primer valor convertido a String no vacío.
  static String? _firstNonEmptyString(
    List<dynamic> values,
  ) {
    for (final dynamic value
        in values) {
      if (value == null) {
        continue;
      }

      final String stringValue =
          value.toString().trim();

      if (stringValue.isNotEmpty) {
        return stringValue;
      }
    }

    return null;
  }

  /// Convierte un valor a String nullable.
  static String? _parseNullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final String result =
        value.toString().trim();

    if (result.isEmpty) {
      return null;
    }

    return result;
  }

  /// =========================================================================
  /// RATING
  /// =========================================================================

  /// Convierte un valor a rating entre 0 y 5.
  ///
  /// Valores inválidos:
  ///     -> 0.0
  ///
  /// Valores inferiores a 0:
  ///     -> 0.0
  ///
  /// Valores superiores a 5:
  ///     -> 5.0
  static double _parseRating(
    dynamic value,
  ) {
    double parsed;

    if (value is num) {
      parsed =
          value.toDouble();
    } else if (value is String) {
      parsed =
          double.tryParse(
            value.trim(),
          ) ??
          0.0;
    } else {
      parsed = 0.0;
    }

    if (!parsed.isFinite) {
      return 0.0;
    }

    if (parsed < 0) {
      return 0.0;
    }

    if (parsed > 5) {
      return 5.0;
    }

    return parsed;
  }

  /// =========================================================================
  /// BOOLEAN
  /// =========================================================================

  /// Convierte diferentes representaciones a bool.
  static bool _parseBool(
    dynamic value,
  ) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final String normalized =
          value.trim().toLowerCase();

      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'si' ||
          normalized == 'sí' ||
          normalized == 'y';
    }

    return false;
  }

  /// =========================================================================
  /// DATE
  /// =========================================================================

  /// Convierte diferentes formatos de fecha a DateTime.
  ///
  /// Soporta:
  /// - Timestamp.
  /// - DateTime.
  /// - String ISO-8601.
  /// - String numérico.
  /// - Unix timestamp en segundos.
  /// - Unix timestamp en milisegundos.
  ///
  /// Si no existe una fecha válida:
  ///     DateTime.now()
  static DateTime _parseDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is num) {
      return _parseUnixTimestamp(
            value,
          ) ??
          DateTime.now();
    }

    if (value is String) {
      final String normalized =
          value.trim();

      if (normalized.isEmpty) {
        return DateTime.now();
      }

      // ---------------------------------------------------------------------
      // ISO-8601
      // ---------------------------------------------------------------------

      final DateTime? parsedDate =
          DateTime.tryParse(
        normalized,
      );

      if (parsedDate != null) {
        return parsedDate;
      }

      // ---------------------------------------------------------------------
      // TIMESTAMP NUMÉRICO EN STRING
      // ---------------------------------------------------------------------

      final num? numericValue =
          num.tryParse(
        normalized,
      );

      if (numericValue != null) {
        return _parseUnixTimestamp(
              numericValue,
            ) ??
            DateTime.now();
      }
    }

    return DateTime.now();
  }

  /// Convierte Unix timestamp a DateTime.
  ///
  /// Valores inferiores a 10^11:
  ///     segundos.
  ///
  /// Valores iguales o superiores:
  ///     milisegundos.
  static DateTime? _parseUnixTimestamp(
    num value,
  ) {
    final double numericValue =
        value.toDouble();

    if (!numericValue.isFinite) {
      return null;
    }

    try {
      if (numericValue.abs() <
          100000000000) {
        return DateTime
            .fromMillisecondsSinceEpoch(
          (numericValue * 1000)
              .round(),
        );
      }

      return DateTime
          .fromMillisecondsSinceEpoch(
        numericValue.round(),
      );
    } catch (_) {
      return null;
    }
  }

  /// =========================================================================
  /// STRING LIST
  /// =========================================================================

  /// Convierte un valor a List<String.
  ///
  /// Soporta:
  /// - List.
  /// - Set.
  /// - String individual.
  ///
  /// Los valores vacíos se eliminan.
  static List<String>
      _parseStringList(
    dynamic value,
  ) {
    if (value == null) {
      return <String>[];
    }

    Iterable<dynamic> values;

    if (value is List) {
      values = value;
    } else if (value is Set) {
      values = value;
    } else {
      final String? singleValue =
          _parseNullableString(
        value,
      );

      if (singleValue == null) {
        return <String>[];
      }

      return <String>[
        singleValue,
      ];
    }

    return values
        .where(
          (dynamic item) =>
              item != null,
        )
        .map(
          (dynamic item) =>
              item.toString().trim(),
        )
        .where(
          (String item) =>
              item.isNotEmpty,
        )
        .toList();
  }

  /// =========================================================================
  /// MAP
  /// =========================================================================

  /// Convierte un valor dinámico a Map<String, dynamic.
  static Map<String, dynamic>
      _parseMap(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  /// =========================================================================
  /// JSON SAFE CONVERSION
  /// =========================================================================

  /// Convierte recursivamente un valor a una estructura compatible con JSON.
  ///
  /// Soporta:
  /// - null
  /// - String
  /// - num
  /// - bool
  /// - DateTime
  /// - Timestamp
  /// - Map
  /// - Iterable
  ///
  /// Valores desconocidos:
  ///     -> String
  ///
  /// Esto evita que jsonEncode() falle si specificFields contiene
  /// accidentalmente DateTime, Timestamp u otros objetos.
  static dynamic _jsonSafeValue(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is String ||
        value is num ||
        value is bool) {
      return value;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Timestamp) {
      return value
          .toDate()
          .toIso8601String();
    }

    if (value is Map) {
      final Map<String, dynamic>
          result =
          <String, dynamic>{};

      value.forEach(
        (
          dynamic key,
          dynamic nestedValue,
        ) {
          result[key.toString()] =
              _jsonSafeValue(
            nestedValue,
          );
        },
      );

      return result;
    }

    if (value is Iterable) {
      return value
          .map(
            (dynamic item) =>
                _jsonSafeValue(
              item,
            ),
          )
          .toList();
    }

    return value.toString();
  }

  /// Convierte un Map completo a un Map JSON-safe.
  static Map<String, dynamic>
      _jsonSafeMap(
    Map<String, dynamic> map,
  ) {
    final dynamic safeValue =
        _jsonSafeValue(
      map,
    );

    if (safeValue
        is Map<String, dynamic>) {
      return safeValue;
    }

    return <String, dynamic>{};
  }

  /// =========================================================================
  /// TO MAP
  /// =========================================================================

  /// Representación general del modelo.
  ///
  /// Mantiene DateTime.
  ///
  /// Para JSON:
  ///     utilizar toJson()
  ///
  /// Para Firestore:
  ///     utilizar toFirestore()
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'restaurantName':
          restaurantName,
      'location':
          location.toMap(),
      'wouldReturn':
          wouldReturn,
      'rating':
          rating,
      'imageUrls':
          List<String>.from(
        imageUrls,
      ),
      'videoUrl':
          videoUrl,
      'date':
          date,
      'category':
          category,
      'specificFields':
          Map<String, dynamic>.from(
        specificFields,
      ),
    };
  }

  /// =========================================================================
  /// TO JSON
  /// =========================================================================

  /// Representación completamente compatible con jsonEncode().
  ///
  /// Este es el método que debe utilizar StorageService.
  ///
  /// DateTime:
  ///     -> ISO-8601
  ///
  /// specificFields:
  ///     -> conversión recursiva JSON-safe
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'restaurantName':
          restaurantName,
      'location':
          location.toJson(),
      'wouldReturn':
          wouldReturn,
      'rating':
          rating,
      'imageUrls':
          List<String>.from(
        imageUrls,
      ),
      'videoUrl':
          videoUrl,
      'date':
          date.toIso8601String(),
      'category':
          category,
      'specificFields':
          _jsonSafeMap(
        specificFields,
      ),
    };
  }

  /// =========================================================================
  /// TO FIRESTORE
  /// =========================================================================

  /// Representación preparada para guardar en Firestore.
  ///
  /// DateTime:
  ///     -> Timestamp
  ///
  /// specificFields se mantiene sin transformar para conservar los tipos
  /// nativos compatibles con Firestore.
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'restaurantName':
          restaurantName,
      'location':
          location.toMap(),
      'wouldReturn':
          wouldReturn,
      'rating':
          rating,
      'imageUrls':
          List<String>.from(
        imageUrls,
      ),
      'videoUrl':
          videoUrl,
      'date':
          Timestamp.fromDate(
        date,
      ),
      'category':
          category,
      'specificFields':
          Map<String, dynamic>.from(
        specificFields,
      ),
    };
  }

  /// =========================================================================
  /// COPY WITH
  /// =========================================================================

  /// Crea una copia modificando únicamente los campos indicados.
  ///
  /// clearVideoUrl:
  ///     elimina explícitamente el vídeo.
  MemoryModel copyWith({
    String? id,
    String? title,
    String? restaurantName,
    LocationData? location,
    bool? wouldReturn,
    double? rating,
    List<String>? imageUrls,
    String? videoUrl,
    bool clearVideoUrl = false,
    DateTime? date,
    String? category,
    Map<String, dynamic>? specificFields,
  }) {
    return MemoryModel(
      id:
          id ?? this.id,
      title:
          title ?? this.title,
      restaurantName:
          restaurantName ??
              this.restaurantName,
      location:
          location ?? this.location,
      wouldReturn:
          wouldReturn ??
              this.wouldReturn,
      rating:
          rating ??
              this.rating,
      imageUrls:
          List<String>.unmodifiable(
        imageUrls ??
            this.imageUrls,
      ),
      videoUrl:
          clearVideoUrl
              ? null
              : (videoUrl ??
                  this.videoUrl),
      date:
          date ?? this.date,
      category:
          category ??
              this.category,
      specificFields:
          Map<String, dynamic>.unmodifiable(
        specificFields ??
            this.specificFields,
      ),
    );
  }

  /// =========================================================================
  /// TOSTRING
  /// =========================================================================

  @override
  String toString() {
    return 'MemoryModel('
        'id: $id, '
        'title: $title, '
        'restaurantName: $restaurantName, '
        'location: $location, '
        'wouldReturn: $wouldReturn, '
        'rating: $rating, '
        'imageUrls: $imageUrls, '
        'videoUrl: $videoUrl, '
        'date: $date, '
        'category: $category, '
        'specificFields: $specificFields'
        ')';
  }
}

