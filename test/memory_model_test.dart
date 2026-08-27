import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:palito_3_0/core/models/memory_model.dart';

void main() {
  group('LocationData', () {
    test('acepta coordenadas nulas sin lanzar y hasCoordinates es false', () {
      const location = LocationData(address: 'Calle Falsa 123');

      expect(location.hasCoordinates, isFalse);
      expect(location.hasAddress, isTrue);
      expect(location.coordinates, isNull);
    });

    test('fromMap soporta lat/lng y latitude/longitude', () {
      final fromLatLng = LocationData.fromMap({
        'address': 'Madrid',
        'lat': 40.4168,
        'lng': -3.7038,
      });

      final fromLatitudeLongitude = LocationData.fromMap({
        'address': 'Madrid',
        'latitude': 40.4168,
        'longitude': -3.7038,
      });

      expect(fromLatLng.hasCoordinates, isTrue);
      expect(fromLatitudeLongitude.hasCoordinates, isTrue);
      expect(fromLatLng.lat, fromLatitudeLongitude.lat);
    });

    test('descarta coordenadas fuera de rango', () {
      final location = LocationData.fromMap({
        'address': 'Inválido',
        'lat': 200.0,
        'lng': -3.7038,
      });

      expect(location.hasCoordinates, isFalse);
    });
  });

  group('MemoryModel.fromMap', () {
    test('recuerda el caso base: guardar ubicación manual sin coordenadas', () {
      // Regresión del bug donde fallaba la geocodificación de una
      // dirección escrita a mano: el recuerdo debe poder representarse
      // igualmente, solo sin pin en el mapa.
      final memory = MemoryModel.fromMap({
        'id': 'abc123',
        'title': 'Bar Manolo',
        'restaurantName': 'Bar Manolo',
        'location': {'address': 'Calle Mayor 1, Madrid'},
        'rating': 4.5,
        'date': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(memory.hasAddress, isTrue);
      expect(memory.hasCoordinates, isFalse);
    });

    test('soporta nombres de campo antiguos (snake_case / alias)', () {
      final memory = MemoryModel.fromMap({
        'memory_id': 'legacy-1',
        'restaurant_name': 'Casa Pepe',
        'address': 'Sevilla',
        'lat': 37.3891,
        'lng': -5.9845,
        'would_return': 'sí',
        'score': '3.9',
        'image_paths': 'https://example.com/foto.jpg',
      });

      expect(memory.id, 'legacy-1');
      expect(memory.restaurantName, 'Casa Pepe');
      expect(memory.wouldReturn, isTrue);
      expect(memory.rating, closeTo(3.9, 0.001));
      expect(memory.imageUrls, ['https://example.com/foto.jpg']);
      expect(memory.hasCoordinates, isTrue);
    });

    test('el rating se acota siempre entre 0 y 5', () {
      final tooHigh = MemoryModel.fromMap({
        'id': '1',
        'title': 'x',
        'restaurantName': 'x',
        'rating': 999,
      });
      final negative = MemoryModel.fromMap({
        'id': '2',
        'title': 'x',
        'restaurantName': 'x',
        'rating': -5,
      });
      final invalid = MemoryModel.fromMap({
        'id': '3',
        'title': 'x',
        'restaurantName': 'x',
        'rating': 'no-es-un-numero',
      });

      expect(tooHigh.rating, 5.0);
      expect(negative.rating, 0.0);
      expect(invalid.rating, 0.0);
    });

    test('parsea Timestamp, ISO-8601 y epoch en segundos/milisegundos', () {
      final fromTimestamp = MemoryModel.fromMap({
        'id': '1',
        'title': 'x',
        'restaurantName': 'x',
        'date': Timestamp.fromDate(DateTime.utc(2025, 6, 1)),
      });

      final fromIso = MemoryModel.fromMap({
        'id': '2',
        'title': 'x',
        'restaurantName': 'x',
        'date': '2025-06-01T00:00:00.000Z',
      });

      final fromEpochSeconds = MemoryModel.fromMap({
        'id': '3',
        'title': 'x',
        'restaurantName': 'x',
        'date': 1748736000, // 2025-06-01T00:00:00Z en segundos
      });

      expect(fromTimestamp.date.toUtc().year, 2025);
      expect(fromIso.date.toUtc().month, 6);
      expect(fromEpochSeconds.date.toUtc().day, 1);
    });

    test('nunca lanza excepción con un mapa vacío o con basura', () {
      expect(
        () => MemoryModel.fromMap(<String, dynamic>{}),
        returnsNormally,
      );

      expect(
        () => MemoryModel.fromMap({
          'rating': ['no', 'es', 'un', 'rating'],
          'location': 'no-es-un-mapa',
          'imageUrls': 12345,
        }),
        returnsNormally,
      );
    });

    test('toJson/fromJson hacen un round-trip fiel', () {
      final original = MemoryModel.fromMap({
        'id': 'roundtrip-1',
        'title': 'Croquetas de jamón',
        'restaurantName': 'Taberna del Puerto',
        'location': {
          'address': 'Puerto de Santa María',
          'lat': 36.5928,
          'lng': -6.2166,
        },
        'wouldReturn': true,
        'rating': 4.5,
        'imageUrls': ['https://example.com/a.jpg'],
        'category': 'Croquetas',
        'date': DateTime.utc(2026, 3, 4).toIso8601String(),
        'specificFields': {'crujiente': true},
      });

      final restored = MemoryModel.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.location.lat, original.location.lat);
      expect(restored.location.lng, original.location.lng);
      expect(restored.wouldReturn, original.wouldReturn);
      expect(restored.rating, original.rating);
      expect(restored.imageUrls, original.imageUrls);
      expect(restored.category, original.category);
      expect(restored.date, original.date);
      expect(restored.specificFields, original.specificFields);
    });
  });
}
