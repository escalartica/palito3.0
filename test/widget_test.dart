import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palito_3_0/main.dart';
import 'package:palito_3_0/core/models/memory_model.dart';
import 'package:palito_3_0/core/providers/memory_map_provider.dart';
import 'package:palito_3_0/core/services/memory_map_firestore_service.dart';

/// Doble de prueba: sobreescribe todos los métodos que
/// [MemoryNotifier] realmente invoca, así que nunca llega a tocar
/// `FirebaseFirestore.instance` / `FirebaseAuth.instance` (los tests no
/// corren en un dispositivo con Firebase inicializado).
class _FakeMemoryMapFirestoreService
    extends MemoryMapFirestoreService {
  _FakeMemoryMapFirestoreService() : super(householdId: 'test-household');

  @override
  Stream<List<MemoryModel>> getMemoryModelsStream() =>
      Stream.value(<MemoryModel>[]);

  @override
  Future<void> saveMemoryModel(MemoryModel memory) async {}

  @override
  Future<void> deleteMemory(String memoryId) async {}
}

void main() {
  setUp(() {
    // MemoryNotifier también cachea en SharedPreferences; el mock de
    // valores iniciales evita que intente hablar con el canal nativo real.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'La aplicación Palito de Sabores se construye correctamente',
    (WidgetTester tester) async {
      // Construimos la aplicación dentro de ProviderScope, igual que en
      // main(), pero sustituyendo memoryMapServiceProvider (la única
      // dependencia real de Firestore, compartida por memoryProvider y
      // por el mapa) por un doble de prueba.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            memoryMapServiceProvider.overrideWithValue(
              _FakeMemoryMapFirestoreService(),
            ),
          ],
          child: const PalitoDeSaboresApp(),
        ),
      );

      // Esperamos a que se completen las animaciones y
      // las construcciones iniciales de los widgets.
      await tester.pumpAndSettle();

      // Verificamos que la aplicación se ha construido
      // correctamente comprobando su título.
      expect(
        find.text('Palito de Sabores'),
        findsOneWidget,
      );
    },
  );
}
