import 'package:flutter_test/flutter_test.dart';

import 'package:palito_3_0/core/models/memory_model.dart';
import 'package:palito_3_0/features/memory_form/controllers/memory_save_controller.dart';

MemoryModel _memoryWithLocation(LocationData location) {
  return MemoryModel(
    id: 'm1',
    title: 'Restaurante de prueba',
    restaurantName: 'Restaurante de prueba',
    location: location,
    wouldReturn: true,
    rating: 4.0,
    imageUrls: const <String>[],
    date: DateTime(2026, 1, 1),
  );
}

void main() {
  group('MemorySaveController.resolveKnownLocation', () {
    test(
        'reutiliza el GPS actual si su dirección coincide (sin '
        'distinguir mayúsculas) con la escrita', () {
      final result = MemorySaveController.resolveKnownLocation(
        addressText: 'Calle Mayor 1',
        currentGpsLocation: const LocationData(
          address: 'CALLE MAYOR 1',
          lat: 40.0,
          lng: -3.0,
        ),
        existingMemory: null,
      );

      expect(result?.lat, 40.0);
      expect(result?.lng, -3.0);
    });

    test('ignora el GPS actual si la dirección escrita es distinta', () {
      final result = MemorySaveController.resolveKnownLocation(
        addressText: 'Otra calle',
        currentGpsLocation: const LocationData(
          address: 'Calle Mayor 1',
          lat: 40.0,
          lng: -3.0,
        ),
        existingMemory: null,
      );

      expect(result, isNull);
    });

    test(
        'reutiliza las coordenadas del recuerdo existente si su '
        'dirección coincide con la escrita', () {
      final existing = _memoryWithLocation(
        const LocationData(
          address: 'Plaza Mayor',
          lat: 41.0,
          lng: -4.0,
        ),
      );

      final result = MemorySaveController.resolveKnownLocation(
        addressText: 'plaza mayor',
        currentGpsLocation: null,
        existingMemory: existing,
      );

      expect(result?.lat, 41.0);
      expect(result?.lng, -4.0);
    });

    test(
        'no reutiliza las coordenadas del recuerdo existente si la '
        'dirección ha cambiado (se corrigió a mano)', () {
      final existing = _memoryWithLocation(
        const LocationData(
          address: 'Dirección vieja',
          lat: 41.0,
          lng: -4.0,
        ),
      );

      final result = MemorySaveController.resolveKnownLocation(
        addressText: 'Dirección nueva',
        currentGpsLocation: null,
        existingMemory: existing,
      );

      expect(result, isNull);
    });

    test('prioriza el GPS actual sobre el recuerdo existente si ambos '
        'coinciden con la dirección escrita', () {
      final existing = _memoryWithLocation(
        const LocationData(
          address: 'Calle Mayor 1',
          lat: 41.0,
          lng: -4.0,
        ),
      );

      final result = MemorySaveController.resolveKnownLocation(
        addressText: 'Calle Mayor 1',
        currentGpsLocation: const LocationData(
          address: 'Calle Mayor 1',
          lat: 40.0,
          lng: -3.0,
        ),
        existingMemory: existing,
      );

      expect(result?.lat, 40.0);
      expect(result?.lng, -3.0);
    });

    test('devuelve null sin ninguna fuente de coordenadas disponible', () {
      final result = MemorySaveController.resolveKnownLocation(
        addressText: 'Calle sin coordenadas conocidas',
        currentGpsLocation: null,
        existingMemory: null,
      );

      expect(result, isNull);
    });
  });

  group('MemorySaveController.parseEmbeddedGpsCoordinates', () {
    test('reconoce el formato "GPS: lat, lng"', () {
      final result = MemorySaveController.parseEmbeddedGpsCoordinates(
        'GPS: 40.4168, -3.7038',
      );

      expect(result?.lat, 40.4168);
      expect(result?.lng, -3.7038);
    });

    test('no distingue mayúsculas/minúsculas ni espacios extra', () {
      final result = MemorySaveController.parseEmbeddedGpsCoordinates(
        'gps:40.4168,-3.7038',
      );

      expect(result?.lat, 40.4168);
      expect(result?.lng, -3.7038);
    });

    test('descarta coordenadas fuera de rango', () {
      final result = MemorySaveController.parseEmbeddedGpsCoordinates(
        'GPS: 200, -3.7038',
      );

      expect(result, isNull);
    });

    test('devuelve null para una dirección normal sin coordenadas', () {
      final result = MemorySaveController.parseEmbeddedGpsCoordinates(
        'Calle Mayor 1, Madrid',
      );

      expect(result, isNull);
    });
  });

  group('MemorySaveController.buildGeocodingQueries', () {
    test('añade ", España" si la dirección no la menciona ya', () {
      final queries = MemorySaveController.buildGeocodingQueries(
        'Calle Mayor 1',
      );

      expect(queries, ['Calle Mayor 1', 'Calle Mayor 1, España']);
    });

    test('no duplica "España" si ya está en la dirección', () {
      final queries = MemorySaveController.buildGeocodingQueries(
        'Calle Mayor 1, España',
      );

      expect(queries, ['Calle Mayor 1, España']);
    });

    test('no duplica "Spain" (en inglés) si ya está en la dirección', () {
      final queries = MemorySaveController.buildGeocodingQueries(
        'Main Street, Spain',
      );

      expect(queries, ['Main Street, Spain']);
    });

    test(
        'caso especial: "Medellín" antepone la pedanía de Badajoz, para '
        'no geocodificar por defecto a Colombia', () {
      final queries = MemorySaveController.buildGeocodingQueries('Medellín');

      expect(queries.first, 'Medellín, Badajoz, España');
      expect(queries, contains('Medellín'));
    });

    test('el caso especial de Medellín no distingue tilde/mayúsculas', () {
      final queries = MemorySaveController.buildGeocodingQueries('medellin');

      expect(queries.first, 'Medellín, Badajoz, España');
    });
  });
}
