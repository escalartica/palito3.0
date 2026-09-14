import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:palito_3_0/core/theme/components/neo_chip.dart';

/// El defecto que se ve en el vídeo: la etiqueta "Decepcionante" se partía a
/// mitad de palabra ("Decepcionant" / "e") en los formularios de recuerdo.
///
/// La causa era un umbral fijo de caracteres (`longestWord > 13 ? 2 : 3`) que
/// no miraba ni el ancho real de la pantalla ni el tamaño de letra del
/// sistema — y "Decepcionante" tiene exactamente 13 caracteres, así que caía
/// justo en la rama de 3 columnas donde no cabe.
void main() {
  // Ancho útil de la rejilla en un móvil de 360 dp:
  // 360 − 2 × AppSpacing.lg(24) = 312.
  const double anchoMovilPequeno = 312;

  group('columnsFor', () {
    test('"Decepcionante" no cabe en 3 columnas en un móvil pequeño', () {
      final int columns = NeoChip.columnsFor(const <String>[
        'Clásica',
        'Original',
        'Innovadora',
        'Decepcionante',
      ], maxWidth: anchoMovilPequeno);

      expect(columns, lessThan(3));
    });

    test('las etiquetas cortas siguen usando 3 columnas', () {
      final int columns = NeoChip.columnsFor(const <String>[
        'Meh',
        'Buenas',
        'Muy buenas',
        'Basura',
      ], maxWidth: anchoMovilPequeno);

      expect(columns, 3);
    });

    test('con el texto del sistema ampliado, bajan las columnas', () {
      final int normal = NeoChip.columnsFor(const <String>[
        'Equilibrada',
        'Muy cremosa',
        'Mazacote',
      ], maxWidth: anchoMovilPequeno);

      final int ampliado = NeoChip.columnsFor(
        const <String>['Equilibrada', 'Muy cremosa', 'Mazacote'],
        maxWidth: anchoMovilPequeno,
        textScaler: const TextScaler.linear(2.0),
      );

      expect(ampliado, lessThanOrEqualTo(normal));
    });

    test('nunca devuelve menos de 1 columna', () {
      final int columns = NeoChip.columnsFor(const <String>[
        'Supercalifragilisticoespialidoso',
      ], maxWidth: 120);

      expect(columns, greaterThanOrEqualTo(1));
    });

    test('sin ancho, la heurística es conservadora', () {
      // Sin poder medir, "Decepcionante" (13 caracteres) tiene que bajar a 2
      // columnas igualmente: el umbral antiguo de 13 lo dejaba en 3.
      expect(NeoChip.columnsFor(const <String>['Decepcionante']), lessThan(3));
    });

    test('una lista vacía no revienta', () {
      expect(NeoChip.columnsFor(const <String>[]), greaterThanOrEqualTo(1));
    });
  });

  group('altura del chip', () {
    test('cumple el objetivo táctil mínimo de 44 px', () {
      expect(NeoChip.minHeight, greaterThanOrEqualTo(44));
    });
  });
}
