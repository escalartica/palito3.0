import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palito_3_0/core/data/storage_service.dart';
import 'package:palito_3_0/core/models/memory_model.dart';

MemoryModel _sampleMemory(String id) {
  return MemoryModel(
    id: id,
    title: 'Croquetas de Casa Paco',
    restaurantName: 'Casa Paco',
    location: const LocationData(
      address: 'Madrid',
      lat: 40.4168,
      lng: -3.7038,
    ),
    wouldReturn: true,
    rating: 4.5,
    imageUrls: const ['https://example.com/a.jpg'],
    date: DateTime.utc(2026, 1, 15),
    category: 'Croquetas',
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService', () {
    test('loadMemories devuelve una lista vacía si no hay nada guardado', () async {
      final memories = await StorageService.loadMemories();

      expect(memories, isEmpty);
    });

    test('saveMemory añade y loadMemories recupera lo guardado', () async {
      await StorageService.saveMemory(_sampleMemory('m1'));

      final memories = await StorageService.loadMemories();

      expect(memories, hasLength(1));
      expect(memories.first.id, 'm1');
      expect(memories.first.title, 'Croquetas de Casa Paco');
    });

    test(
      'guardar más de 5 recuerdos no borra ninguno de los anteriores '
      '(no existe límite de almacenamiento)',
      () async {
        for (var i = 0; i < 8; i++) {
          await StorageService.saveMemory(_sampleMemory('m$i'));
        }

        final memories = await StorageService.loadMemories();

        expect(memories, hasLength(8));
        expect(
          memories.map((m) => m.id).toSet(),
          {'m0', 'm1', 'm2', 'm3', 'm4', 'm5', 'm6', 'm7'},
        );
      },
    );

    test('saveMemory con el mismo ID actualiza en vez de duplicar', () async {
      await StorageService.saveMemory(_sampleMemory('m1'));

      final updated = _sampleMemory('m1');
      await StorageService.saveMemory(
        MemoryModel(
          id: updated.id,
          title: 'Título actualizado',
          restaurantName: updated.restaurantName,
          location: updated.location,
          wouldReturn: updated.wouldReturn,
          rating: updated.rating,
          imageUrls: updated.imageUrls,
          date: updated.date,
          category: updated.category,
        ),
      );

      final memories = await StorageService.loadMemories();

      expect(memories, hasLength(1));
      expect(memories.first.title, 'Título actualizado');
    });

    test('deleteMemory elimina solo el recuerdo indicado', () async {
      await StorageService.saveMemory(_sampleMemory('m1'));
      await StorageService.saveMemory(_sampleMemory('m2'));

      await StorageService.deleteMemory('m1');

      final memories = await StorageService.loadMemories();

      expect(memories, hasLength(1));
      expect(memories.first.id, 'm2');
    });
  });
}
