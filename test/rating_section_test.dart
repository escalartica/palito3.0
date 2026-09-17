import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palito_3_0/features/memory_form/widgets/rating_section.dart';

/// La conversión de "dónde has tocado" a "qué nota es" es aritmética pura, y
/// es donde se cometen los errores de un punto: que tocar el borde izquierdo
/// dé cero (que aquí significa "sin puntuar", no "un cero"), o que el borde
/// derecho no llegue a cinco.
void main() {
  group('RatingSection.ratingAt', () {
    const double w = 300;

    test('el borde izquierdo da media estrella, nunca cero', () {
      expect(RatingSection.ratingAt(0, w), 0.5);
      expect(RatingSection.ratingAt(-50, w), 0.5);
    });

    test('el borde derecho da cinco', () {
      expect(RatingSection.ratingAt(w, w), 5.0);
      expect(RatingSection.ratingAt(w + 80, w), 5.0);
    });

    test('apuntar al centro de una estrella da esa estrella entera', () {
      // La frontera entre "media" y "entera" estaba clavada en el centro
      // geométrico de cada estrella, que es justo donde apunta el dedo: un
      // píxel a un lado daba 3,5 y al otro 4,0. Se vio probándolo en el
      // simulador, no leyendo el código.
      expect(RatingSection.ratingAt(w * 0.5, w), 3.0); // centro de la 3ª
      expect(RatingSection.ratingAt(w * 0.7, w), 4.0); // centro de la 4ª
      expect(RatingSection.ratingAt(w * 0.9, w), 5.0); // centro de la 5ª
      expect(RatingSection.ratingAt(w * 0.1, w), 1.0); // centro de la 1ª
    });

    test('la media estrella se pide en el borde izquierdo de cada una', () {
      expect(RatingSection.ratingAt(w * 0.42, w), 2.5); // entrando en la 3ª
      expect(RatingSection.ratingAt(w * 0.62, w), 3.5); // entrando en la 4ª
    });

    test('solo salen medias estrellas', () {
      for (double dx = 0; dx <= w; dx += 3) {
        final double v = RatingSection.ratingAt(dx, w);
        expect(v * 2, (v * 2).roundToDouble(), reason: 'dx=$dx dio $v');
        expect(v, inInclusiveRange(0.5, 5.0));
      }
    });

    test('tocar dentro de la primera estrella nunca pasa de una', () {
      // La primera estrella ocupa el primer quinto del ancho.
      expect(RatingSection.ratingAt(w * 0.05, w), 0.5);
      expect(RatingSection.ratingAt(w * 0.19, w), 1.0);
    });

    test('un ancho de cero no divide entre cero', () {
      expect(RatingSection.ratingAt(10, 0), 5.0);
    });
  });

  /// ═══════════════════════════════════════════════════════════════════════
  /// CON UN LECTOR DE PANTALLA ESCUCHANDO
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// El árbol de accesibilidad **solo se construye cuando hay alguien
  /// escuchando**. Por eso este fallo no salía probando la app a dedo, ni en
  /// las pruebas: las estrellas declaraban `value` y los gestos de subir y
  /// bajar, pero no `increasedValue` ni `decreasedValue`, y Flutter lo
  /// prohíbe —revienta con «A SemanticsNode with action "increase" needs to
  /// be annotated with either both "value" and "increasedValue" or neither»,
  /// y detrás un `'node.built': is not true`—.
  ///
  /// O sea: **abrir el formulario de un recuerdo con VoiceOver encendido
  /// rompía la app.** Y es justo el usuario para el que se escribió ese
  /// bloque de `Semantics`.
  ///
  /// `ensureSemantics()` enciende ese árbol en la prueba. Es la única forma
  /// de que esto se note sin un iPhone y un lector de pantalla delante.
  group('accesibilidad', () {
    testWidgets('el árbol de accesibilidad se construye sin romperse', (
      WidgetTester tester,
    ) async {
      // ── EL `handle` SE CIERRA AQUÍ DENTRO, NO EN UN `addTearDown` ──
      //
      // Es lo primero que se me ocurrió y está mal: `flutter_test` comprueba
      // que no queden `SemanticsHandle` vivos **al terminar el cuerpo de la
      // prueba**, y los `addTearDown` corren después de esa comprobación.
      // Resultado: la prueba fallaba con «A SemanticsHandle was active at
      // the end of the test» —un fallo mío de andamiaje— que tapaba
      // precisamente lo que venía a medir. Un rojo que no era el rojo que
      // buscaba.
      //
      // El `try/finally` es por lo mismo: si el árbol se rompe de verdad,
      // que se lea ESE error y no el del handle sin cerrar.
      final SemanticsHandle handle = tester.ensureSemantics();

      final AnimationController controlador = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(controlador.dispose);

      // Los tres estados que cambian qué gestos ofrece el nodo: sin puntuar
      // (solo se puede subir), a medias (las dos cosas) y al máximo (solo
      // se puede bajar).
      try {
        for (final (double nota, bool tocada) in <(double, bool)>[
          (0.0, false),
          (3.0, true),
          (5.0, true),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: RatingSection(
                  rating: nota,
                  hasInteracted: tocada,
                  ratingAnimationController: controlador,
                  onChanged: (double _) {},
                ),
              ),
            ),
          );
          await tester.pump();

          expect(
            tester.takeException(),
            isNull,
            reason: 'La puntuación $nota rompe el árbol de accesibilidad.',
          );
        }
      } finally {
        handle.dispose();
      }
    });
  });
}
