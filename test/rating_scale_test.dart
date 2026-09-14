import 'package:flutter_test/flutter_test.dart';

import 'package:palito_3_0/core/data/rating_scale.dart';

/// Estas pruebas fijan por escrito los dos fallos que hacían que toda la app
/// pareciera puntuada con ceros:
///
///  1. La ficha de detalle pintaba la nota en escala 0–10 sobre datos que se
///     guardan en 0–5, así que un 5/5 salía a media barra y rotulado
///     "Por mejorar".
///  2. La "Nota Media" del perfil dividía entre TODOS los recuerdos, incluidos
///     los que no tienen nota (todos los creados antes de que el formulario la
///     exigiera), así que tendía a 0,0.
void main() {
  group('escala', () {
    test('la nota máxima es 5, no 10', () {
      expect(RatingScale.max, 5.0);
    });

    test('la nota máxima llena la barra por completo', () {
      expect(RatingScale.progress(5.0), 1.0);
    });

    test('un 5 sobre 5 es la mejor etiqueta posible, no "Correcto"', () {
      expect(RatingScale.qualitativeLabel(5.0), 'Extraordinario');
      expect(RatingScale.qualitativeLabel(4.5), 'Extraordinario');
      expect(RatingScale.qualitativeLabel(4.0), 'Excelente');
      expect(RatingScale.qualitativeLabel(3.5), 'Muy bueno');
      expect(RatingScale.qualitativeLabel(2.5), 'Correcto');
      expect(RatingScale.qualitativeLabel(1.0), 'Por mejorar');
    });

    test('una nota fuera de rango no desborda la barra', () {
      expect(RatingScale.progress(99), 1.0);
      expect(RatingScale.progress(-3), 0.0);
    });
  });

  group('sin puntuar', () {
    test('0 significa "sin puntuar", no un cero', () {
      expect(RatingScale.isRated(0), isFalse);
      expect(RatingScale.qualitativeLabel(0), 'Sin puntuar');
    });

    test('un recuerdo sin nota no muestra "0.0"', () {
      expect(RatingScale.shortLabel(0), isNull);
      expect(RatingScale.shortLabel(4.5), '4.5');
    });
  });

  group('media', () {
    test('ignora los recuerdos sin puntuar', () {
      // Cuatro recuerdos heredados sin nota y uno de 4,5: la media debe ser
      // 4,5, no 0,9.
      final double? avg = RatingScale.average(<double>[0, 0, 0, 0, 4.5]);

      expect(avg, 4.5);
    });

    test('es null cuando no hay ninguno puntuado', () {
      expect(RatingScale.average(<double>[0, 0, 0]), isNull);
      expect(RatingScale.average(<double>[]), isNull);
    });

    test('promedia correctamente varios puntuados', () {
      expect(RatingScale.average(<double>[4, 5, 0, 3]), 4.0);
    });
  });
}
