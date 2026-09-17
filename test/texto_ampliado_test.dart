import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palito_3_0/core/models/memory_model.dart';
import 'package:palito_3_0/core/providers/auth_provider.dart';
import 'package:palito_3_0/core/providers/household_provider.dart';
import 'package:palito_3_0/core/providers/gamer_provider.dart';
import 'package:palito_3_0/core/providers/memory_map_provider.dart';
import 'package:palito_3_0/core/services/gamer_firestore_service.dart';
import 'package:palito_3_0/core/services/memory_map_firestore_service.dart';
import 'package:palito_3_0/core/theme/components/app_dock.dart';
import 'package:palito_3_0/features/home/widgets/section_title.dart';
import 'package:palito_3_0/main.dart';

/// ===========================================================================
/// LA APP CON EL TEXTO DEL SISTEMA AMPLIADO
/// ===========================================================================
///
/// POR QUÉ ESTA PRUEBA. El día que la escribí encontré, MIRANDO LA PANTALLA,
/// un `OVERFLOWED BY 0.0965 PIXELS` que llevaba horas saliendo en todas mis
/// capturas sin que lo identificara. Ni `flutter analyze` ni las 137 pruebas
/// lo veían: un desbordamiento no es un error de tipos, es un resultado de
/// medir, y solo existe cuando algo se mide de verdad.
///
/// Y ese apareció con el texto normal. Con el texto ampliado —Ajustes →
/// Accesibilidad → Pantalla y tamaño del texto, que no es un caso raro sino
/// la primera cosa que toca cualquiera que no ve de cerca— hay mucho más
/// sitio donde no cabe.
///
/// CÓMO FUNCIONA. Un desbordamiento de `Row`/`Column` se comunica como un
/// `FlutterError` durante el layout. En una prueba, eso llega a
/// `tester.takeException()`. O sea que la prueba no comprueba píxeles: deja
/// que Flutter mida y pregunta si se ha quejado.
///
/// EL TAMAÑO MÁS DURO es el iPhone SE (320 de ancho) con el texto al 310 %,
/// que es el tope de los tamaños de accesibilidad de iOS. Si cabe ahí, cabe
/// en todo.
class _FakeMemoryMapFirestoreService extends MemoryMapFirestoreService {
  _FakeMemoryMapFirestoreService(this._memories) : super(groupId: 'test-group');

  final List<MemoryModel> _memories;

  @override
  Stream<List<MemoryModel>> getMemoryModelsStream() =>
      Stream<List<MemoryModel>>.value(_memories);

  @override
  Future<void> saveMemoryModel(MemoryModel memory) async {}

  @override
  Future<void> deleteMemory(String memoryId) async {}

  // El Mapa lo pide al abrirse. Sin esto, tocar la pestaña Mapa se va a
  // Firestore de verdad y la prueba falla por una cosa que no está
  // midiendo.
  @override
  Stream<List<Map<String, dynamic>>> getLocationsStream() =>
      Stream<List<Map<String, dynamic>>>.value(<Map<String, dynamic>>[]);
}

/// La ruleta y el Perfil leen la cuenta y las estadísticas. Se finge lo justo
/// para que las dos pantallas se pinten: nada de esto se está midiendo, lo
/// que se mide es que quepan.
class _FakeGamerService extends GamerFirestoreService {
  _FakeGamerService() : super(groupId: 'grupo-de-prueba');

  @override
  String? get currentUid => 'test-uid';

  // Emite un valor en vez de quedarse callado: un stream que nunca emite
  // deja el Perfil en «cargando» para siempre, y entonces se estaría
  // midiendo un esqueleto en vez de la pantalla.
  @override
  Stream<GamerStats?> getGamerStatsStream() =>
      Stream<GamerStats?>.value(null);

  // `decisions` y `streak` son opcionales desde que la mesa sincroniza la
  // fila de cada comensal con cuenta: quien lleva el móvil sabe los puntos de
  // todos, pero no cuántas tiradas ha hecho cada uno por su cuenta. Este
  // `fake` tiene que declararlos igual o no compila.
  @override
  Future<void> updatePlayerStats({
    required String playerKey,
    required String uid,
    required int score,
    int? decisions,
    int? streak,
    List<String> unlockedChallenges = const <String>[],
    String? displayName,
  }) async {}

  @override
  Future<void> logGameSessionEvent({
    required String winnerName,
    required String eventDetail,
    required int pointsAwarded,
  }) async {}
}

List<Override> _overrides(List<MemoryModel> memories) => <Override>[
  memoryMapServiceProvider.overrideWithValue(
    _FakeMemoryMapFirestoreService(memories),
  ),
  gamerServiceProvider.overrideWithValue(_FakeGamerService()),
  // UN DIARIO CON VARIAS PERSONAS, no uno vacío.
  //
  // Es donde la app tiene más texto de longitud impredecible junta: nombres
  // que escribe cada cual, un contador de miembros, y las filas de «quién
  // está en cada uno». Con un grupo de una sola persona esas pantallas
  // enseñan su versión corta y no se prueba nada.
  activeGroupDocProvider.overrideWith(
    (ref) => Stream<Map<String, dynamic>?>.value(<String, dynamic>{
      'name': 'Los del jueves',
      'isPersonal': false,
      'createdBy': 'test-uid',
      'members': <String>['test-uid', 'uid-2', 'uid-3', 'uid-4'],
      'memberProfiles': <String, dynamic>{
        'test-uid': <String, dynamic>{'displayName': 'Sharon'},
        'uid-2': <String, dynamic>{'displayName': 'Juan Antonio'},
        'uid-3': <String, dynamic>{
          'displayName': 'María de los Remedios Fernández',
        },
        'uid-4': <String, dynamic>{'displayName': 'Pedro'},
      },
    }),
  ),
  currentUidProvider.overrideWithValue('test-uid'),
  currentUserDocProvider.overrideWith(
    (ref) => Stream<Map<String, dynamic>?>.value(<String, dynamic>{
      'groupIds': <String>['personal-group'],
      'personalGroupId': 'personal-group',
      'displayName': 'Sharon',
    }),
  ),
];

/// Los tamaños que de verdad hay ahí fuera, del más apretado al más ancho.
const List<(String, Size)> _pantallas = <(String, Size)>[
  ('iPhone SE', Size(320, 568)),
  ('iPhone 16 Pro', Size(393, 852)),
];

/// 1,0 es el tamaño de fábrica. 3,1 es el tope de accesibilidad de iOS.
const List<double> _escalas = <double>[1.0, 3.1];

/// Recuerdos de verdad, y uno a propósito con el nombre más largo que cabe
/// escribir.
///
/// Con la lista VACÍA esta prueba no valía de mucho: Inicio enseña entonces
/// su estado vacío, que son cuatro líneas centradas, y lo que hay que medir
/// son las tarjetas —foto, título, diario, categoría, nota y fecha, todo en
/// una fila de 288 puntos—. El estado fácil pasaba y el difícil no se
/// probaba.
List<MemoryModel> _recuerdos() => <MemoryModel>[
  MemoryModel(
    id: '1',
    title: 'Croquetas',
    restaurantName: 'Bar Pepe',
    location: const LocationData(address: 'Calle Falsa 123'),
    wouldReturn: true,
    rating: 4.5,
    imageUrls: const <String>[],
    date: DateTime(2026, 9, 15),
    category: 'Croquetas',
  ),
  MemoryModel(
    id: '2',
    // Un nombre absurdamente largo no es un capricho: la app deja
    // escribirlo, así que alguien lo escribirá, y la fila de la tarjeta
    // tiene que aguantarlo igual que aguanta «Bar Pepe».
    title:
        'Surtido de croquetas de jamón ibérico de bellota con alioli de ajo '
        'negro y pimentón de La Vera',
    restaurantName:
        'Restaurante La Taberna del Puerto de Santa María de los Remedios',
    location: const LocationData(address: 'Avenida Muy Larga 456'),
    wouldReturn: false,
    rating: 2.0,
    imageUrls: const <String>[],
    date: DateTime(2026, 8, 1),
    category: 'Croquetas',
  ),
  MemoryModel(
    id: '3',
    title: 'Tortilla',
    restaurantName: 'Casa Esteban',
    location: const LocationData(address: 'Plaza Mayor 1'),
    wouldReturn: true,
    rating: 5.0,
    imageUrls: const <String>[],
    date: DateTime(2026, 9, 1),
    category: 'Tortilla',
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  for (final (String nombre, Size tamano) in _pantallas) {
    for (final double escala in _escalas) {
      testWidgets('Inicio cabe en $nombre al ${(escala * 100).round()} %', (
        WidgetTester tester,
      ) async {
        tester.view
          ..devicePixelRatio = 3.0
          ..physicalSize = tamano * 3.0
          // El área del sistema: sin esto la prueba mide una pantalla sin
          // isla dinámica ni indicador de inicio, y se pierde justo el hueco
          // donde el contenido y el reloj se pisan.
          ..padding = const FakeViewPadding(top: 59 * 3.0, bottom: 34 * 3.0);
        addTearDown(tester.view.reset);

        tester.platformDispatcher.textScaleFactorTestValue = escala;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        // ── Y CON UN LECTOR DE PANTALLA ESCUCHANDO ──
        //
        // El árbol de accesibilidad solo se construye cuando hay alguien
        // escuchando, así que todo lo que esté mal declarado ahí es
        // invisible en las pruebas normales y en el uso a dedo. En las
        // estrellas de puntuación había un nodo mal formado que **rompía la
        // app con VoiceOver encendido** y llevaba ahí desde siempre; se
        // encontró de casualidad, porque el puente de accesibilidad del
        // simulador lo enciende.
        //
        // De casualidad, una vez. Encendido aquí, en cada tamaño de letra y
        // en cada pantalla, no hace falta la casualidad.
        //
        // Se cierra DENTRO del cuerpo y no en un `addTearDown`:
        // `flutter_test` comprueba que no queden handles vivos al terminar
        // el cuerpo, y los `addTearDown` corren después.
        final SemanticsHandle semantica = tester.ensureSemantics();

        Object? problema;
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: _overrides(_recuerdos()),
              child: const PalitoDeSaboresApp(),
            ),
          );
          await tester.pumpAndSettle();
          problema = tester.takeException();
        } finally {
          // Pase lo que pase: un handle sin cerrar genera su propio error y
          // taparía el que de verdad importa.
          semantica.dispose();
        }

        expect(
          problema,
          isNull,
          reason:
              'Inicio se rompe con $nombre al '
              '${(escala * 100).round()} % de texto y el lector de pantalla '
              'encendido.',
        );
      });
    }
  }

  /// ═════════════════════════════════════════════════════════════════════
  /// INICIO, LA RULETA Y PERFIL — NO SOLO INICIO
  /// ═════════════════════════════════════════════════════════════════════
  ///
  /// Hasta aquí la prueba solo medía Inicio, y lo decía. Llegar a las otras
  /// costaba fingir la cuenta y el diario activo, que es lo que hacen los
  /// dos «fakes» de arriba — y el diario tiene CUATRO personas a propósito,
  /// con nombres de todas las longitudes, porque es donde la app junta más
  /// texto que escribe cada cual.
  ///
  /// Se recorren en el tamaño más duro —iPhone SE con el texto al 310 %— y
  /// con el lector de pantalla encendido, que es donde salen las dos cosas
  /// que no se ven de otra forma: lo que no cabe y lo que está mal
  /// declarado.
  ///
  /// El Mapa se queda fuera, y el porqué está escrito abajo, en su sitio.
  testWidgets('Inicio, La ruleta y Perfil caben en un iPhone SE al 310 %', (
    WidgetTester tester,
  ) async {
    tester.view
      ..devicePixelRatio = 3.0
      ..physicalSize = const Size(320, 568) * 3.0
      ..padding = const FakeViewPadding(top: 59 * 3.0, bottom: 34 * 3.0);
    addTearDown(tester.view.reset);

    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final SemanticsHandle semantica = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(_recuerdos()),
          child: const PalitoDeSaboresApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Inicio');

      // El dock declara cada pestaña con su nombre en el árbol de
      // accesibilidad (`Semantics(label: item.label)`), así que se puede
      // buscar por ahí en vez de por el texto que se pinta —que cambia:
      // «La ruleta» se acorta a «Ruleta» cuando no cabe—.
      //
      // ── POR QUÉ EL MAPA NO ESTÁ EN ESTA LISTA ──
      //
      // Porque no se queda quieto nunca, y no por un fallo: al abrirse
      // arranca la resolución de coordenadas de cada recuerdo y el mapa pide
      // sus teselas por red. En una prueba toda petición HTTP devuelve 400 y
      // la geocodificación no responde, así que el árbol no llega a
      // silenciarse jamás y `pumpAndSettle` agota su plazo. Se comprobó
      // leyendo la salida entera: no había ningún desbordamiento, solo un
      // «pumpAndSettle timed out».
      //
      // Se deja fuera a propósito y dicho en voz alta, en vez de fingir que
      // está cubierto. El Mapa es además la pantalla con menos texto de las
      // cuatro —un mapa a sangre y dos controles flotantes—, o sea la que
      // menos tiene que perder con la letra grande. Verificarla pide otra
      // herramienta: mirarla.
      for (final String pestana in <String>['La ruleta', 'Perfil']) {
        final Finder boton = find.descendant(
          of: find.byType(AppDock),
          matching: find.bySemanticsLabel(pestana),
        );

        expect(
          boton,
          findsOneWidget,
          reason: 'No encuentro la pestaña $pestana en el dock.',
        );

        await tester.tap(boton, warnIfMissed: false);

        // Fotogramas contados en vez de `pumpAndSettle`: basta con que la
        // transición termine y la pantalla se mida, y así una animación que
        // no para —un esqueleto de carga, por ejemplo— no tumba la prueba
        // por algo que no está midiendo.
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }

        expect(
          tester.takeException(),
          isNull,
          reason:
              '$pestana se rompe en un iPhone SE al 310 % de texto con el '
              'lector de pantalla encendido.',
        );
      }
    } finally {
      semantica.dispose();
    }
  });

  testWidgets('la cabecera de sección aguanta el texto al 310 %', (
    WidgetTester tester,
  ) async {
    // El caso concreto que falló: 19 puntos en w900 al lado de un icono, en
    // 320 de ancho. «Tu opinión» no cabía.
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: Column(
              children: <Widget>[
                SectionTitle(icon: Icons.favorite, title: 'Tu opinión'),
                SectionTitle(icon: Icons.place, title: 'Ubicación'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
