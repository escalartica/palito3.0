import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/memory_model.dart';

/// ===========================================================================
/// MEMORY MAP FIRESTORE SERVICE
/// ===========================================================================
///
/// Fuente principal:
///
/// groups/{groupId}/memories/{memoryId}
///
/// Colección secundaria:
///
/// groups/{groupId}/locations/{memoryId}
///
/// La colección `memories` es la fuente principal de verdad.
///
/// `locations` se mantiene sincronizada como estructura secundaria para:
///
/// - compatibilidad,
/// - migraciones,
/// - consultas específicas,
/// - funcionalidades relacionadas con mapas.
///
/// ===========================================================================

class MemoryMapFirestoreService {
  MemoryMapFirestoreService({
    required this.groupId,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _injectedFirestore = firestore,
        _injectedAuth = auth;

  /// ID del grupo activo del usuario (`groups/{groupId}`), resuelto
  /// por `activeGroupIdProvider` a partir de su sesión. Null si el
  /// usuario ha iniciado sesión pero todavía no se conoce ningún grupo.
  final String? groupId;

  // Se resuelven de forma perezosa (getters, no campos finales) para no
  // tocar los singletons de Firebase en el momento de construir el
  // servicio. Esto permite instanciar la clase (p. ej. en un subtipo de
  // prueba que sobreescribe todos los métodos que los usan) antes de que
  // Firebase.initializeApp() se haya ejecutado, como ocurre en tests.
  final FirebaseFirestore? _injectedFirestore;
  final FirebaseAuth? _injectedAuth;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  // ==========================================================================
  // CONFIGURACIÓN
  // ==========================================================================

  static const String _groupsCollection = 'groups';
  static const String _memoriesCollection = 'memories';
  static const String _locationsCollection = 'locations';

  // ==========================================================================
  // USUARIO ACTUAL
  // ==========================================================================

  User? get _currentUser => _auth.currentUser;

  String? get _currentUserId {
    final String? uid = _currentUser?.uid;

    if (uid == null || uid.trim().isEmpty) {
      return null;
    }

    return uid.trim();
  }

  // ==========================================================================
  // REFERENCIAS
  // ==========================================================================

  // Todas las lecturas/escrituras usan groupId como segmento de ruta
  // (no el uid del usuario) para que los recuerdos se compartan entre
  // todos los miembros del grupo. Requiere tanto sesión iniciada como
  // pertenencia a un grupo — sin ninguna de las dos, no hay colección
  // válida a la que apuntar.
  CollectionReference<Map<String, dynamic>>?
      get _userMemoriesCollection {
    if (_currentUserId == null || groupId == null) {
      return null;
    }

    return _firestore
        .collection(_groupsCollection)
        .doc(groupId)
        .collection(_memoriesCollection);
  }

  CollectionReference<Map<String, dynamic>>?
      get _userLocationsCollection {
    if (_currentUserId == null || groupId == null) {
      return null;
    }

    return _firestore
        .collection(_groupsCollection)
        .doc(groupId)
        .collection(_locationsCollection);
  }

  // ==========================================================================
  // UTILIDADES
  // ==========================================================================

  double? _parseDouble(
    dynamic value,
  ) {
    if (value is num) {
      final double result = value.toDouble();

      if (!result.isFinite) {
        return null;
      }

      return result;
    }

    if (value is String) {
      final String normalized = value.trim();

      if (normalized.isEmpty) {
        return null;
      }

      final double? result = double.tryParse(
        normalized,
      );

      if (result == null || !result.isFinite) {
        return null;
      }

      return result;
    }

    return null;
  }

  bool _areValidCoordinates(
    double? lat,
    double? lng,
  ) {
    if (lat == null || lng == null) {
      return false;
    }

    if (!lat.isFinite || !lng.isFinite) {
      return false;
    }

    return lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  String _parseString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final String result = value.toString().trim();

    if (result.isEmpty) {
      return fallback;
    }

    return result;
  }

  Map<String, dynamic> _parseMap(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  List<String> _parseStringList(
    dynamic value,
  ) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .where(
          (dynamic item) => item != null,
        )
        .map(
          (dynamic item) => item.toString().trim(),
        )
        .where(
          (String item) => item.isNotEmpty,
        )
        .toList();
  }

  bool _parseBool(
    dynamic value,
  ) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final String normalized = value
          .trim()
          .toLowerCase();

      switch (normalized) {
        case 'true':
        case '1':
        case 'yes':
        case 'y':
        case 'si':
        case 'sí':
        case 's':
          return true;

        case 'false':
        case '0':
        case 'no':
        case 'n':
          return false;
      }
    }

    return false;
  }

  Timestamp? _parseTimestamp(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value;
    }

    if (value is DateTime) {
      return Timestamp.fromDate(
        value,
      );
    }

    if (value is String) {
      final String normalized = value.trim();

      if (normalized.isEmpty) {
        return null;
      }

      final DateTime? parsed =
          DateTime.tryParse(
        normalized,
      );

      if (parsed == null) {
        return null;
      }

      return Timestamp.fromDate(
        parsed,
      );
    }

    return null;
  }

  bool _hasUsableValue(
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

  // ==========================================================================
  // AUTENTICACIÓN
  // ==========================================================================

  bool _ensureAuthenticated({
    required String operation,
  }) {
    final User? user = _currentUser;

    if (user == null) {
      debugPrint(
        '⚠️ MemoryMapFirestoreService: '
        'no hay usuario autenticado. '
        'Operación: $operation',
      );

      return false;
    }

    debugPrint(
      '👤 Firebase Auth: '
      'uid=${user.uid} | '
      'anonymous=${user.isAnonymous}',
    );

    return true;
  }

  void _logAuthState() {
    final User? user = _currentUser;

    if (user == null) {
      debugPrint(
        '⚠️ MemoryMapFirestoreService: '
        'FirebaseAuth.currentUser == null',
      );

      return;
    }

    debugPrint(
      '👤 Usuario Firebase actual: ${user.uid}',
    );

    debugPrint(
      '📧 Email usuario Firebase: '
      '${user.email ?? '(sin email)'}',
    );

    debugPrint(
      '👤 Usuario anónimo: ${user.isAnonymous}',
    );
  }

  // ==========================================================================
  // NORMALIZACIÓN DE LOCATION
  // ==========================================================================

  Map<String, dynamic> _normalizeLocation(
    Map<String, dynamic> data,
  ) {
    final Map<String, dynamic> location =
        _parseMap(
      data['location'],
    );

    // ------------------------------------------------------------------------
    // ADDRESS
    // ------------------------------------------------------------------------

    String address = _parseString(
      location['address'],
    );

    if (address.isEmpty) {
      address = _parseString(
        data['address'],
      );
    }

    if (address.isEmpty) {
      address = _parseString(
        data['locationAddress'],
      );
    }

    // ------------------------------------------------------------------------
    // LATITUDE
    // ------------------------------------------------------------------------

    double? lat = _parseDouble(
      location['lat'],
    );

    lat ??= _parseDouble(
      data['lat'],
    );

    // ------------------------------------------------------------------------
    // LONGITUDE
    // ------------------------------------------------------------------------

    double? lng = _parseDouble(
      location['lng'],
    );

    lng ??= _parseDouble(
      data['lng'],
    );

    // ------------------------------------------------------------------------
    // VALIDACIÓN
    // ------------------------------------------------------------------------

    if (!_areValidCoordinates(
      lat,
      lng,
    )) {
      lat = null;
      lng = null;
    }

    return <String, dynamic>{
      'address': address,
      'lat': lat,
      'lng': lng,
    };
  }

  // ==========================================================================
  // NORMALIZAR DOCUMENTO MEMORY
  // ==========================================================================

  Map<String, dynamic> _normalizeMemoryDocument(
    String documentId,
    Map<String, dynamic> rawData,
  ) {
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(
      rawData,
    );

    // ------------------------------------------------------------------------
    // ID
    // ------------------------------------------------------------------------

    data['id'] = documentId;

    // ------------------------------------------------------------------------
    // LOCATION
    // ------------------------------------------------------------------------

    data['location'] = _normalizeLocation(
      data,
    );

    // ------------------------------------------------------------------------
    // TITLE
    // ------------------------------------------------------------------------

    String title = _parseString(
      data['title'],
    );

    if (title.isEmpty) {
      title = _parseString(
        data['restaurantName'],
      );
    }

    if (title.isEmpty) {
      title = _parseString(
        data['name'],
      );
    }

    data['title'] = title;

    // ------------------------------------------------------------------------
    // RESTAURANT NAME
    // ------------------------------------------------------------------------

    String restaurantName = _parseString(
      data['restaurantName'],
    );

    if (restaurantName.isEmpty) {
      restaurantName = title;
    }

    data['restaurantName'] = restaurantName;

    // ------------------------------------------------------------------------
    // CATEGORY
    // ------------------------------------------------------------------------

    data['category'] = _parseString(
      data['category'],
      fallback: 'General',
    );

    // ------------------------------------------------------------------------
    // RATING
    // ------------------------------------------------------------------------

    double? rating = _parseDouble(
      data['rating'] ??
          data['score'],
    );

    rating ??= 0.0;

    if (rating < 0) {
      rating = 0.0;
    }

    if (rating > 5) {
      rating = 5.0;
    }

    data['rating'] = rating;

    // ------------------------------------------------------------------------
    // WOULD RETURN
    // ------------------------------------------------------------------------

    data['wouldReturn'] = _parseBool(
      data['wouldReturn'] ??
          data['would_return'],
    );

    // ------------------------------------------------------------------------
    // IMAGES
    // ------------------------------------------------------------------------

    data['imageUrls'] = _parseStringList(
      data['imageUrls'] ??
          data['images'] ??
          data['image_paths'],
    );

    // ------------------------------------------------------------------------
    // VIDEO
    // ------------------------------------------------------------------------

    final String videoUrl = _parseString(
      data['videoUrl'] ??
          data['video'] ??
          data['video_url'],
    );

    data['videoUrl'] = videoUrl.isEmpty
        ? null
        : videoUrl;

    // ------------------------------------------------------------------------
    // SPECIFIC FIELDS
    // ------------------------------------------------------------------------

    data['specificFields'] = _parseMap(
      data['specificFields'] ??
          data['specific_fields'],
    );

    return data;
  }

  // ==========================================================================
  // MEMORY MODEL -> FIRESTORE
  // ==========================================================================

  // ==========================================================================
  // FIRESTORE -> MEMORY MODEL
  // ==========================================================================

  MemoryModel _memoryModelFromFirestoreDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> rawData =
        document.data() ??
            <String, dynamic>{};

    final Map<String, dynamic> normalizedData =
        _normalizeMemoryDocument(
      document.id,
      rawData,
    );

    return MemoryModel.fromMap(
      normalizedData,
    );
  }

  // ==========================================================================
  // OBTENER UNA MEMORIA
  // ==========================================================================

  Future<MemoryModel?> getMemoryById(
    String memoryId,
  ) async {
    if (!_ensureAuthenticated(
      operation: 'getMemoryById',
    )) {
      return null;
    }

    final String normalizedMemoryId =
        memoryId.trim();

    if (normalizedMemoryId.isEmpty) {
      return null;
    }

    final CollectionReference<Map<String, dynamic>>?
        collection =
        _userMemoriesCollection;

    if (collection == null) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          document =
          await collection
              .doc(normalizedMemoryId)
              .get();

      if (!document.exists) {
        return null;
      }

      return _memoryModelFromFirestoreDocument(
        document,
      );
    } catch (
      e,
      stack
    ) {
      debugPrint(
        '❌ Error obteniendo memoria '
        '$normalizedMemoryId: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // STREAM PRINCIPAL DE MEMORIAS PARA MAPA
  // ==========================================================================

  Stream<List<Map<String, dynamic>>>
      getMemoriesStream() {
    final CollectionReference<Map<String, dynamic>>?
        collection =
        _userMemoriesCollection;

    if (collection == null) {
      debugPrint(
        '⚠️ getMemoriesStream: '
        'no hay usuario autenticado.',
      );

      return Stream.value(
        <Map<String, dynamic>>[],
      );
    }

    _logAuthState();

    debugPrint(
      '🗺️ Iniciando stream Firestore:',
    );

    debugPrint(
      '📁 groups/$groupId/$_memoriesCollection',
    );

    return collection.snapshots().map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final List<Map<String, dynamic>> result =
            <Map<String, dynamic>>[];

        int memoriesWithCoordinates = 0;

        debugPrint(
          '============================================================',
        );

        debugPrint(
          '🗺️ FIRESTORE SNAPSHOT DE MEMORIAS',
        );

        debugPrint(
          '📄 Documentos recibidos: '
          '${snapshot.docs.length}',
        );

        for (
          final QueryDocumentSnapshot<
              Map<String, dynamic>> doc
          in snapshot.docs
        ) {
          try {
            final Map<String, dynamic> rawData =
                Map<String, dynamic>.from(
              doc.data(),
            );

            final Map<String, dynamic> data =
                _normalizeMemoryDocument(
              doc.id,
              rawData,
            );

            final Map<String, dynamic> location =
                _parseMap(
              data['location'],
            );

            final double? lat =
                _parseDouble(
              location['lat'],
            );

            final double? lng =
                _parseDouble(
              location['lng'],
            );

            final String title =
                _parseString(
              data['title'],
              fallback: '(sin título)',
            );

            final String address =
                _parseString(
              location['address'],
              fallback: '(sin dirección)',
            );

            if (_areValidCoordinates(
              lat,
              lng,
            )) {
              memoriesWithCoordinates++;
            } else {
              debugPrint(
                '⚠️ MEMORIA SIN COORDENADAS: '
                '${doc.id} "$title" ($address) — '
                'location original: ${rawData['location']}, '
                'lat: ${rawData['lat']}, lng: ${rawData['lng']}',
              );
            }

            result.add(
              data,
            );
          } catch (
            e,
            stack
          ) {
            debugPrint(
              '❌ Error procesando memoria '
              '${doc.id}: $e',
            );

            debugPrintStack(
              stackTrace: stack,
            );
          }
        }

        debugPrint(
          '============================================================',
        );

        debugPrint(
          '🗺️ RESULTADO MAPA',
        );

        debugPrint(
          '📄 Memorias normalizadas: '
          '${result.length}',
        );

        debugPrint(
          '📍 Memorias con coordenadas: '
          '$memoriesWithCoordinates/'
          '${result.length}',
        );

        debugPrint(
          '============================================================',
        );

        return result;
      },
    );
  }

  // ==========================================================================
  // STREAM DE MEMORY MODEL
  // ==========================================================================

  Stream<List<MemoryModel>>
      getMemoryModelsStream() {
    final CollectionReference<Map<String, dynamic>>?
        collection =
        _userMemoriesCollection;

    if (collection == null) {
      debugPrint(
        '⚠️ getMemoryModelsStream: '
        'no hay usuario autenticado.',
      );

      return Stream.value(
        <MemoryModel>[],
      );
    }

    return collection.snapshots().map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final List<MemoryModel> result =
            <MemoryModel>[];

        for (
          final QueryDocumentSnapshot<
              Map<String, dynamic>> doc
          in snapshot.docs
        ) {
          try {
            result.add(
              _memoryModelFromFirestoreDocument(
                doc,
              ),
            );
          } catch (
            e,
            stack
          ) {
            debugPrint(
              '❌ Error convirtiendo memoria '
              '${doc.id} a MemoryModel: $e',
            );

            debugPrintStack(
              stackTrace: stack,
            );
          }
        }

        debugPrint(
          '🧠 MemoryModels recibidos '
          'de Firestore: '
          '${result.length}',
        );

        return result;
      },
    );
  }

  // ==========================================================================
  // GUARDAR MEMORY MODEL
  // ==========================================================================

  Future<void> saveMemoryModel(
    MemoryModel memory,
  ) async {
    final String memoryId =
        memory.id.trim();

    if (memoryId.isEmpty) {
      throw ArgumentError(
        'No se puede guardar una memoria sin ID.',
      );
    }

    await saveMemory(
      memoryId: memoryId,
      memoryData: memory.toFirestore(),
    );
  }

  // ==========================================================================
  // ACTUALIZAR SOLO COORDENADAS
  // ==========================================================================

  /// Actualiza únicamente `location.lat`/`location.lng` de una memoria ya
  /// existente, sin tocar el resto del documento.
  ///
  /// Se usa para persistir el resultado de una geocodificación (ver
  /// [MemoryGeocodingService]) y así no tener que repetirla en cada
  /// arranque de la app para la misma dirección — a diferencia de
  /// [saveMemory], que reescribe el documento completo a partir de un
  /// mapa de datos nuevo, esto es una actualización parcial mínima.
  Future<void> updateMemoryCoordinates({
    required String memoryId,
    required double lat,
    required double lng,
  }) async {
    if (!_ensureAuthenticated(
      operation: 'updateMemoryCoordinates',
    )) {
      return;
    }

    final String normalizedMemoryId =
        memoryId.trim();

    if (normalizedMemoryId.isEmpty) {
      return;
    }

    final CollectionReference<
            Map<String, dynamic>>?
        memoriesCollection =
        _userMemoriesCollection;

    if (memoriesCollection == null) {
      return;
    }

    await memoriesCollection
        .doc(
      normalizedMemoryId,
    )
        .update(
      <String, dynamic>{
        'location.lat': lat,
        'location.lng': lng,
      },
    );
  }

  // ==========================================================================
  // GUARDAR MEMORIA + LOCATION
  // ==========================================================================

  Future<void> saveMemory({
    required String memoryId,
    required Map<String, dynamic> memoryData,
  }) async {
    if (!_ensureAuthenticated(
      operation: 'saveMemory',
    )) {
      return;
    }

    final String normalizedMemoryId =
        memoryId.trim();

    if (normalizedMemoryId.isEmpty) {
      throw ArgumentError(
        'memoryId no puede estar vacío.',
      );
    }

    try {
      final CollectionReference<
              Map<String, dynamic>>?
          memoriesCollection =
          _userMemoriesCollection;

      final CollectionReference<
              Map<String, dynamic>>?
          locationsCollection =
          _userLocationsCollection;

      if (memoriesCollection == null) {
        throw StateError(
          'No se pudo obtener la colección de memorias.',
        );
      }

      if (locationsCollection == null) {
        throw StateError(
          'No se pudo obtener la colección de localizaciones.',
        );
      }

      // ======================================================================
      // REFERENCIAS
      // ======================================================================

      final DocumentReference<
              Map<String, dynamic>>
          memoryReference =
          memoriesCollection.doc(
        normalizedMemoryId,
      );

      final DocumentReference<
              Map<String, dynamic>>
          locationReference =
          locationsCollection.doc(
        normalizedMemoryId,
      );

      // ======================================================================
      // TRANSACCIÓN
      // ======================================================================
      //
      // Lee ambos documentos y escribe el resultado dentro de la misma
      // transacción para evitar una condición de carrera si los 2
      // dispositivos del grupo editan el mismo recuerdo a la vez (leer
      // con .get() y escribir después con un batch, como se hacía antes,
      // deja una ventana entre lectura y escritura sin ninguna garantía
      // de atomicidad).

      await _firestore.runTransaction(
        (
          Transaction transaction,
        ) async {
      // ======================================================================
      // OBTENER DOCUMENTOS EXISTENTES
      // ======================================================================

      final DocumentSnapshot<
              Map<String, dynamic>>
          existingMemory =
          await transaction.get(
        memoryReference,
      );

      final DocumentSnapshot<
              Map<String, dynamic>>
          existingLocation =
          await transaction.get(
        locationReference,
      );

      // ======================================================================
      // COPIA DE DATOS
      // ======================================================================

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(
        memoryData,
      );

      // ======================================================================
      // ID
      // ======================================================================

      data['id'] =
          normalizedMemoryId;

      // ======================================================================
      // LOCATION
      // ======================================================================

      final Map<String, dynamic> location =
          _normalizeLocation(
        data,
      );

      data['location'] =
          location;

      // ======================================================================
      // TITLE
      // ======================================================================

      String title =
          _parseString(
        data['title'],
      );

      if (title.isEmpty) {
        title =
            _parseString(
          data['restaurantName'],
        );
      }

      data['title'] =
          title;

      // ======================================================================
      // RESTAURANT NAME
      // ======================================================================

      String restaurantName =
          _parseString(
        data['restaurantName'],
      );

      if (restaurantName.isEmpty) {
        restaurantName =
            title;
      }

      data['restaurantName'] =
          restaurantName;

      // ======================================================================
      // CATEGORY
      // ======================================================================

      data['category'] =
          _parseString(
        data['category'],
        fallback: 'General',
      );

      // ======================================================================
      // WOULD RETURN
      // ======================================================================

      data['wouldReturn'] =
          _parseBool(
        data['wouldReturn'] ??
            data['would_return'],
      );

      // ======================================================================
      // RATING
      // ======================================================================

      double? rating =
          _parseDouble(
        data['rating'] ??
            data['score'],
      );

      rating ??= 0.0;

      if (rating < 0) {
        rating = 0.0;
      }

      if (rating > 5) {
        rating = 5.0;
      }

      data['rating'] =
          rating;

      // ======================================================================
      // IMÁGENES
      // ======================================================================

      data['imageUrls'] =
          _parseStringList(
        data['imageUrls'] ??
            data['images'] ??
            data['image_paths'],
      );

      // ======================================================================
      // VIDEO
      // ======================================================================

      final String videoUrl =
          _parseString(
        data['videoUrl'] ??
            data['video'] ??
            data['video_url'],
      );

      data['videoUrl'] =
          videoUrl.isEmpty
              ? null
              : videoUrl;

      // ======================================================================
      // SPECIFIC FIELDS
      // ======================================================================

      data['specificFields'] =
          _parseMap(
        data['specificFields'] ??
            data['specific_fields'],
      );

      // ======================================================================
      // DATE
      // ======================================================================
      //
      // Prioridad:
      //
      // 1. Fecha explícita válida enviada por el modelo.
      // 2. Fecha existente en Firestore.
      // 3. serverTimestamp() si es una memoria nueva.
      //
      // Así, editar una memoria no cambia su fecha original.
      //

      final Timestamp? parsedDate =
          _parseTimestamp(
        data['date'],
      );

      if (parsedDate != null) {
        data['date'] =
            parsedDate;
      } else if (existingMemory.exists) {
        final dynamic existingDate =
            existingMemory.data()?['date'];

        if (_hasUsableValue(
          existingDate,
        )) {
          data['date'] =
              existingDate;
        } else {
          data['date'] =
              FieldValue.serverTimestamp();
        }
      } else {
        data['date'] =
            FieldValue.serverTimestamp();
      }

      // ======================================================================
      // UPDATED AT
      // ======================================================================

      data['updatedAt'] =
          FieldValue.serverTimestamp();

      // ======================================================================
      // CREATED AT
      // ======================================================================

      if (!existingMemory.exists) {
        data['createdAt'] =
            FieldValue.serverTimestamp();
      }

      // ======================================================================
      // LOCATION SECUNDARIO
      // ======================================================================

      final Map<String, dynamic>
          locationData =
          <String, dynamic>{
        'id':
            normalizedMemoryId,
        'address':
            location['address'],
        'lat':
            location['lat'],
        'lng':
            location['lng'],
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      if (!existingLocation.exists) {
        locationData['createdAt'] =
            FieldValue.serverTimestamp();
      }

      // ======================================================================
      // ESCRITURA (dentro de la misma transacción)
      // ======================================================================

      // ----------------------------------------------------------------------
      // MEMORIA PRINCIPAL
      // ----------------------------------------------------------------------

      transaction.set(
        memoryReference,
        data,
        SetOptions(
          merge: true,
        ),
      );

      // ----------------------------------------------------------------------
      // LOCATION SECUNDARIO
      // ----------------------------------------------------------------------

      transaction.set(
        locationReference,
        locationData,
        SetOptions(
          merge: true,
        ),
      );

      debugPrint(
        '✅ Memoria guardada correctamente.',
      );

      debugPrint(
        '   ID: $normalizedMemoryId',
      );

      debugPrint(
        '   Usuario: $_currentUserId',
      );

      debugPrint(
        '   Título: $title',
      );

      debugPrint(
        '   Restaurante: $restaurantName',
      );

      debugPrint(
        '   Categoría: ${data['category']}',
      );

      // ======================================================================
      // LOG COORDENADAS
      // ======================================================================

      final double? lat =
          _parseDouble(
        location['lat'],
      );

      final double? lng =
          _parseDouble(
        location['lng'],
      );

      if (_areValidCoordinates(
        lat,
        lng,
      )) {
        debugPrint(
          '📍 Coordenadas guardadas correctamente:',
        );

        debugPrint(
          '   Lat: $lat',
        );

        debugPrint(
          '   Lng: $lng',
        );
      } else {
        debugPrint(
          '⚠️ Memoria guardada sin coordenadas válidas.',
        );

        debugPrint(
          '   Location: $location',
        );
      }

      debugPrint(
        '📍 Localización secundaria sincronizada.',
      );
        },
      );
    } catch (
      e,
      stack
    ) {
      debugPrint(
        '❌ Error al guardar recuerdo '
        'en Firestore: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // ELIMINAR MEMORIA + LOCATION
  // ==========================================================================

  Future<void> deleteMemory(
    String memoryId,
  ) async {
    if (!_ensureAuthenticated(
      operation: 'deleteMemory',
    )) {
      return;
    }

    final String normalizedMemoryId =
        memoryId.trim();

    if (normalizedMemoryId.isEmpty) {
      throw ArgumentError(
        'memoryId no puede estar vacío.',
      );
    }

    try {
      final CollectionReference<
              Map<String, dynamic>>?
          memoriesCollection =
          _userMemoriesCollection;

      final CollectionReference<
              Map<String, dynamic>>?
          locationsCollection =
          _userLocationsCollection;

      if (memoriesCollection == null) {
        throw StateError(
          'No se pudo obtener la colección de memorias.',
        );
      }

      if (locationsCollection == null) {
        throw StateError(
          'No se pudo obtener la colección de localizaciones.',
        );
      }

      final WriteBatch batch =
          _firestore.batch();

      batch.delete(
        memoriesCollection.doc(
          normalizedMemoryId,
        ),
      );

      batch.delete(
        locationsCollection.doc(
          normalizedMemoryId,
        ),
      );

      await batch.commit();

      debugPrint(
        '🗑️ Memoria eliminada correctamente:',
      );

      debugPrint(
        '   ID: $normalizedMemoryId',
      );

      debugPrint(
        '   Usuario: $_currentUserId',
      );
    } catch (
      e,
      stack
    ) {
      debugPrint(
        '❌ Error al eliminar recuerdo: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // STREAM DE LOCATIONS
  // ==========================================================================

  Stream<List<Map<String, dynamic>>>
      getLocationsStream() {
    final CollectionReference<Map<String, dynamic>>?
        collection =
        _userLocationsCollection;

    if (collection == null) {
      debugPrint(
        '⚠️ getLocationsStream: '
        'no hay usuario autenticado.',
      );

      return Stream.value(
        <Map<String, dynamic>>[],
      );
    }

    _logAuthState();

    debugPrint(
      '📍 Iniciando stream de localizaciones:',
    );

    debugPrint(
      '📁 groups/$groupId/$_locationsCollection',
    );

    return collection.snapshots().map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final List<Map<String, dynamic>> result =
            <Map<String, dynamic>>[];

        int validCoordinates = 0;

        debugPrint(
          '📍 Documentos de localizaciones: '
          '${snapshot.docs.length}',
        );

        for (
          final QueryDocumentSnapshot<
              Map<String, dynamic>> doc
          in snapshot.docs
        ) {
          try {
            final Map<String, dynamic> rawData =
                Map<String, dynamic>.from(
              doc.data(),
            );

            final Map<String, dynamic>
                normalizedLocation =
                _normalizeLocation(
              rawData,
            );

            final double? lat =
                _parseDouble(
              normalizedLocation['lat'],
            );

            final double? lng =
                _parseDouble(
              normalizedLocation['lng'],
            );

            final Map<String, dynamic> data =
                <String, dynamic>{
              ...rawData,
              'id':
                  doc.id,
              'address':
                  normalizedLocation['address'],
              'lat':
                  lat,
              'lng':
                  lng,
            };

            if (_areValidCoordinates(
              lat,
              lng,
            )) {
              validCoordinates++;
            } else {
              data['lat'] =
                  null;

              data['lng'] =
                  null;
            }

            result.add(
              data,
            );
          } catch (
            e,
            stack
          ) {
            debugPrint(
              '❌ Error procesando localización '
              '${doc.id}: $e',
            );

            debugPrintStack(
              stackTrace: stack,
            );
          }
        }

        debugPrint(
          '📍 Localizaciones normalizadas: '
          '${result.length}',
        );

        debugPrint(
          '📍 Localizaciones con coordenadas válidas: '
          '$validCoordinates/'
          '${result.length}',
        );

        return result;
      },
    );
  }

  // ==========================================================================
  // GUARDAR LOCATION DESDE MEMORY MODEL
  // ==========================================================================

  Future<void> saveLocationFromMemory(
    MemoryModel memory,
  ) async {
    final String locationId =
        memory.id.trim();

    if (locationId.isEmpty) {
      throw ArgumentError(
        'No se puede guardar una localización sin ID.',
      );
    }

    await saveLocation(
      locationId: locationId,
      locationData:
          memory.location.toMap(),
    );
  }

  // ==========================================================================
  // GUARDAR LOCATION
  // ==========================================================================

  Future<void> saveLocation({
    required String locationId,
    required Map<String, dynamic> locationData,
  }) async {
    if (!_ensureAuthenticated(
      operation: 'saveLocation',
    )) {
      return;
    }

    final String normalizedLocationId =
        locationId.trim();

    if (normalizedLocationId.isEmpty) {
      throw ArgumentError(
        'locationId no puede estar vacío.',
      );
    }

    try {
      final CollectionReference<
              Map<String, dynamic>>?
          collection =
          _userLocationsCollection;

      if (collection == null) {
        throw StateError(
          'No se pudo obtener la colección de localizaciones.',
        );
      }

      final DocumentReference<
              Map<String, dynamic>>
          reference =
          collection.doc(
        normalizedLocationId,
      );

      final DocumentSnapshot<
              Map<String, dynamic>>
          existing =
          await reference.get();

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(
        locationData,
      );

      // ======================================================================
      // NORMALIZAR
      // ======================================================================

      final Map<String, dynamic>
          normalizedLocation =
          _normalizeLocation(
        data,
      );

      data['id'] =
          normalizedLocationId;

      data['address'] =
          normalizedLocation['address'];

      data['lat'] =
          normalizedLocation['lat'];

      data['lng'] =
          normalizedLocation['lng'];

      // ======================================================================
      // METADATOS
      // ======================================================================

      data['updatedAt'] =
          FieldValue.serverTimestamp();

      if (!existing.exists) {
        data['createdAt'] =
            FieldValue.serverTimestamp();
      }

      // ======================================================================
      // GUARDAR
      // ======================================================================

      await reference.set(
        data,
        SetOptions(
          merge: true,
        ),
      );

      debugPrint(
        '📍 Localización guardada correctamente.',
      );

      debugPrint(
        '   ID: $normalizedLocationId',
      );

      debugPrint(
        '   Usuario: $_currentUserId',
      );

      final double? lat =
          _parseDouble(
        data['lat'],
      );

      final double? lng =
          _parseDouble(
        data['lng'],
      );

      if (_areValidCoordinates(
        lat,
        lng,
      )) {
        debugPrint(
          '📍 Coordenadas:',
        );

        debugPrint(
          '   Lat: $lat',
        );

        debugPrint(
          '   Lng: $lng',
        );
      } else {
        debugPrint(
          '⚠️ Localización guardada '
          'sin coordenadas válidas.',
        );
      }
    } catch (
      e,
      stack
    ) {
      debugPrint(
        '❌ Error al guardar localización '
        'en Firestore: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // ELIMINAR LOCATION SECUNDARIO
  // ==========================================================================

  Future<void> deleteLocation(
    String locationId,
  ) async {
    if (!_ensureAuthenticated(
      operation: 'deleteLocation',
    )) {
      return;
    }

    final String normalizedLocationId =
        locationId.trim();

    if (normalizedLocationId.isEmpty) {
      throw ArgumentError(
        'locationId no puede estar vacío.',
      );
    }

    try {
      final CollectionReference<
              Map<String, dynamic>>?
          collection =
          _userLocationsCollection;

      if (collection == null) {
        throw StateError(
          'No se pudo obtener la colección de localizaciones.',
        );
      }

      await collection
          .doc(
            normalizedLocationId,
          )
          .delete();

      debugPrint(
        '🗑️ Localización secundaria eliminada:',
      );

      debugPrint(
        '   ID: $normalizedLocationId',
      );
    } catch (
      e,
      stack
    ) {
      debugPrint(
        '❌ Error al eliminar localización: $e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }
}