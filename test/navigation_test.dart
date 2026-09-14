import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palito_3_0/main.dart';
import 'package:palito_3_0/core/models/memory_model.dart';
import 'package:palito_3_0/core/providers/auth_provider.dart';
import 'package:palito_3_0/core/providers/household_provider.dart';
import 'package:palito_3_0/core/providers/memory_map_provider.dart';
import 'package:palito_3_0/core/services/memory_map_firestore_service.dart';
import 'package:palito_3_0/core/theme/components/app_dock.dart';
import 'package:palito_3_0/features/home/home_page.dart';
import 'package:palito_3_0/features/onboarding/name_page.dart';

class _FakeMemoryMapFirestoreService extends MemoryMapFirestoreService {
  _FakeMemoryMapFirestoreService() : super(groupId: 'test-group');

  @override
  Stream<List<MemoryModel>> getMemoryModelsStream() =>
      Stream<List<MemoryModel>>.value(<MemoryModel>[]);

  @override
  Future<void> saveMemoryModel(MemoryModel memory) async {}

  @override
  Future<void> deleteMemory(String memoryId) async {}
}

List<Override> _overrides(Map<String, dynamic> userDoc) => <Override>[
  memoryMapServiceProvider.overrideWithValue(_FakeMemoryMapFirestoreService()),
  currentUidProvider.overrideWithValue('test-uid'),
  currentUserDocProvider.overrideWith(
    (ref) => Stream<Map<String, dynamic>?>.value(userDoc),
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('el dock aparece en Inicio y tiene una pestaña de Inicio', (
    WidgetTester tester,
  ) async {
    // Antes, Mapa, Zona Gamer y Perfil eran rutas sueltas FUERA del shell:
    // el dock solo existía en Inicio, y además no tenía ninguna pestaña de
    // Inicio, así que desde las otras pantallas no había forma evidente de
    // volver.
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(<String, dynamic>{
          'groupIds': <String>['personal-group'],
          'personalGroupId': 'personal-group',
          'displayName': 'Sharon',
        }),
        child: const PalitoDeSaboresApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);

    final AppDock dock = tester.widget<AppDock>(find.byType(AppDock));

    expect(dock.items.length, 4);
    expect(
      dock.items.map((DockItem i) => i.label).toList(),
      containsAll(<String>['Inicio', 'Mapa', 'Zona Gamer', 'Perfil']),
    );

    // En Inicio, la pestaña seleccionada es Inicio (antes era -1: ninguna).
    expect(dock.currentIndex, 0);
  });

  testWidgets('sin nombre guardado, la app pide el nombre antes de entrar', (
    WidgetTester tester,
  ) async {
    // Apple solo entrega el nombre la PRIMERA vez que se autoriza la app.
    // Sin esta puerta, quien reinstalaba se quedaba con el prefijo de su
    // correo como nombre (`gdvcgp2gdt`) y sin ninguna pantalla donde
    // cambiarlo.
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(<String, dynamic>{
          'groupIds': <String>['personal-group'],
          'personalGroupId': 'personal-group',
          // sin displayName
        }),
        child: const PalitoDeSaboresApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NamePage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });
}
