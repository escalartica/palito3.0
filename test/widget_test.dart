import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palito_3_0/main.dart';
import 'package:palito_3_0/core/models/memory_model.dart';
import 'package:palito_3_0/core/providers/auth_provider.dart';
import 'package:palito_3_0/core/providers/memory_map_provider.dart';
import 'package:palito_3_0/core/services/memory_map_firestore_service.dart';
import 'package:palito_3_0/core/providers/household_provider.dart';
import 'package:palito_3_0/features/auth/sign_in_page.dart';
import 'package:palito_3_0/features/home/home_page.dart';

/// Doble de prueba: sobreescribe todos los métodos que
/// [MemoryNotifier] realmente invoca, así que nunca llega a tocar
/// `FirebaseFirestore.instance` / `FirebaseAuth.instance` (los tests no
/// corren en un dispositivo con Firebase inicializado).
class _FakeMemoryMapFirestoreService
    extends MemoryMapFirestoreService {
  _FakeMemoryMapFirestoreService() : super(groupId: 'test-group');

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
    'sin sesión, la app se construye y muestra la pantalla de inicio '
    'de sesión',
    (WidgetTester tester) async {
      // Construimos la aplicación dentro de ProviderScope, igual que en
      // main(), pero sustituyendo memoryMapServiceProvider (la única
      // dependencia real de Firestore, compartida por memoryProvider y
      // por el mapa) por un doble de prueba, y authStateChangesProvider
      // por "sin sesión" — sin esto, el router leería
      // FirebaseAuth.instance.authStateChanges() directamente, que no
      // funciona sin Firebase inicializado.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            memoryMapServiceProvider.overrideWithValue(
              _FakeMemoryMapFirestoreService(),
            ),
            authStateChangesProvider.overrideWith(
              (ref) => Stream<User?>.value(null),
            ),
          ],
          child: const PalitoDeSaboresApp(),
        ),
      );

      // Esperamos a que se completen las animaciones y
      // las construcciones iniciales de los widgets.
      await tester.pumpAndSettle();

      // Sin sesión, el redirect de GoRouter debe llevar a SignInPage —
      // no a Home. Comprobamos algo específico de esa pantalla (el
      // nombre de la app aparece también en Home, así que por sí solo
      // no distinguiría entre las dos).
      expect(
        find.text('Palito de Sabores'),
        findsOneWidget,
      );

      expect(
        find.byType(SignInPage),
        findsOneWidget,
      );

      expect(
        find.byType(HomePage),
        findsNothing,
      );
    },
  );

  testWidgets(
    'con sesión, muestra Home directamente (sin puerta de configuración '
    'de grupo, aunque solo tenga su grupo personal)',
    (WidgetTester tester) async {
      // No existe ninguna puerta de onboarding obligatoria: todo el
      // mundo tiene ya su grupo personal en cuanto su documento de
      // usuario existe (ver AuthService), así que iniciar sesión lleva
      // siempre directo a Home. Compartir con alguien (crear/unirse a
      // otro grupo) es una acción opcional posterior desde Perfil, no
      // parte de este flujo.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            memoryMapServiceProvider.overrideWithValue(
              _FakeMemoryMapFirestoreService(),
            ),
            currentUidProvider.overrideWithValue('test-uid'),
            currentUserDocProvider.overrideWith(
              (ref) => Stream.value(<String, dynamic>{
                'groupIds': ['personal-group'],
                'personalGroupId': 'personal-group',
                'displayName': 'Test',
              }),
            ),
          ],
          child: const PalitoDeSaboresApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(SignInPage), findsNothing);
    },
  );
}
