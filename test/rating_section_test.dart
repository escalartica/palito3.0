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
}
