import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palito_3_0/core/models/memory_model.dart';
import 'package:palito_3_0/core/providers/memory_map_provider.dart';
import 'package:palito_3_0/core/providers/memory_provider.dart';
import 'package:palito_3_0/core/services/memory_map_firestore_service.dart';

/// Doble de prueba controlable: a diferencia del de widget_test.dart (que
/// solo devuelve una lista fija), este expone un [StreamController] propio
/// para poder simular, desde el test, tanto nuevas emisiones de Firestore
/// como errores del stream — y registra qué se ha guardado/borrado para
/// poder comprobarlo.
class _ControllableFirestoreService extends MemoryMapFirestoreService {
  final StreamController<List<MemoryModel>> _controller =
      StreamController<List<MemoryModel>>.broadcast();

  final List<MemoryModel> savedMemories = <MemoryModel>[];
  final List<String> deletedIds = <String>[];

  @override
  Stream<List<MemoryModel>> getMemoryModelsStream() => _controller.stream;

  @override
  Future<void> saveMemoryModel(MemoryModel memory) async {
    savedMemories.add(memory);
  }

  @override
  Future<void> deleteMemory(String memoryId) async {
    deletedIds.add(memoryId);
  }

  void emit(List<MemoryModel> memories) => _controller.add(memories);

  void emitError(Object error) =>
      _controller.addError(error, StackTrace.current);

  Future<void> close() => _controller.close();
}

MemoryModel _memory({
  required String id,
  DateTime? date,
  String title = 'Restaurante de prueba',
}) {
  return MemoryModel(
    id: id,
    title: title,
    restaurantName: title,
    location: const LocationData(address: 'Calle Falsa 123'),
    wouldReturn: true,
    rating: 4.0,
    imageUrls: const <String>[],
    date: date ?? DateTime(2026, 1, 1),
  );
}

/// Deja correr la cola de microtasks pendiente — necesario porque una
/// emisión de [StreamController] atraviesa varias capas asíncronas
/// (Stream -> StreamProvider de Riverpod -> ref.listen de MemoryNotifier)
/// antes de que `state` quede actualizado.
Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  late _ControllableFirestoreService fakeService;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeService = _ControllableFirestoreService();
    container = ProviderContainer(
      overrides: [
        memoryMapServiceProvider.overrideWithValue(fakeService),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeService.close);
  });

  group('MemoryNotifier — CRUD', () {
    test('addMemory añade la memoria, la persiste y actualiza el estado',
        () async {
      final notifier = container.read(memoryProvider.notifier);
      final memory = _memory(id: 'm1');

      await notifier.addMemory(memory);

      expect(container.read(memoryProvider), [memory]);
      expect(fakeService.savedMemories, [memory]);
    });

    test(
        'addMemory con un ID ya existente actualiza en vez de duplicar '
        '(deduplicación por ID)', () async {
      final notifier = container.read(memoryProvider.notifier);

      await notifier.addMemory(_memory(id: 'm1', title: 'Original'));
      await notifier.addMemory(_memory(id: 'm1', title: 'Actualizado'));

      final state = container.read(memoryProvider);

      expect(state, hasLength(1));
      expect(state.single.title, 'Actualizado');
    });

    test('updateMemory reemplaza solo la memoria con ese ID', () async {
      final notifier = container.read(memoryProvider.notifier);

      await notifier.addMemory(_memory(id: 'm1', title: 'Uno'));
      await notifier.addMemory(_memory(id: 'm2', title: 'Dos'));

      await notifier.updateMemory(_memory(id: 'm1', title: 'Uno editado'));

      final state = container.read(memoryProvider);

      expect(
        state.firstWhere((m) => m.id == 'm1').title,
        'Uno editado',
      );
      expect(
        state.firstWhere((m) => m.id == 'm2').title,
        'Dos',
      );
    });

    test('removeMemory elimina solo la memoria indicada, local y remota',
        () async {
      final notifier = container.read(memoryProvider.notifier);

      await notifier.addMemory(_memory(id: 'm1'));
      await notifier.addMemory(_memory(id: 'm2'));

      await notifier.removeMemory('m1');

      final state = container.read(memoryProvider);

      expect(state.map((m) => m.id), ['m2']);
      expect(fakeService.deletedIds, ['m1']);
    });

    test('el estado se ordena siempre por fecha descendente', () async {
      final notifier = container.read(memoryProvider.notifier);

      await notifier.addMemory(
        _memory(id: 'antiguo', date: DateTime(2020, 1, 1)),
      );
      await notifier.addMemory(
        _memory(id: 'reciente', date: DateTime(2026, 1, 1)),
      );
      await notifier.addMemory(
        _memory(id: 'intermedio', date: DateTime(2023, 1, 1)),
      );

      final ids = container.read(memoryProvider).map((m) => m.id).toList();

      expect(ids, ['reciente', 'intermedio', 'antiguo']);
    });

    test('getMemoryById y latestMemory reflejan el estado actual', () async {
      final notifier = container.read(memoryProvider.notifier);

      expect(notifier.getMemoryById('m1'), isNull);
      expect(notifier.latestMemory, isNull);

      await notifier.addMemory(
        _memory(id: 'm1', date: DateTime(2020, 1, 1)),
      );
      await notifier.addMemory(
        _memory(id: 'm2', date: DateTime(2026, 1, 1)),
      );

      expect(notifier.getMemoryById('m1')?.id, 'm1');
      expect(notifier.latestMemory?.id, 'm2');
    });
  });

  group('MemoryNotifier — sincronización con Firestore', () {
    test(
        'una emisión del stream compartido con el mapa actualiza el estado '
        'y marca hasReceivedFirestoreData', () async {
      final notifier = container.read(memoryProvider.notifier);

      expect(notifier.hasReceivedFirestoreData, isFalse);

      fakeService.emit([_memory(id: 'remoto')]);
      await _flushMicrotasks();

      expect(notifier.hasReceivedFirestoreData, isTrue);
      expect(
        container.read(memoryProvider).map((m) => m.id),
        ['remoto'],
      );
    });

    test(
        'un error del stream activa hasStreamError, y se limpia solo en '
        'cuanto vuelven a llegar datos', () async {
      final notifier = container.read(memoryProvider.notifier);

      expect(notifier.hasStreamError, isFalse);

      fakeService.emitError(Exception('sin conexión'));
      await _flushMicrotasks();

      expect(notifier.hasStreamError, isTrue);

      fakeService.emit([_memory(id: 'recuperado')]);
      await _flushMicrotasks();

      expect(notifier.hasStreamError, isFalse);
      expect(
        container.read(memoryProvider).map((m) => m.id),
        ['recuperado'],
      );
    });

    test(
        'memoryProvider y el StreamProvider del mapa comparten la misma '
        'instancia de servicio (sin listener duplicado)', () {
      expect(
        container.read(memoryMapServiceProvider),
        same(fakeService),
      );
    });
  });
}
