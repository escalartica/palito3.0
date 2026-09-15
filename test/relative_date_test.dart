import 'package:flutter_test/flutter_test.dart';
import 'package:palito_3_0/core/utils/relative_date.dart';

void main() {
  group('relativeDate', () {
    DateTime hace(int dias) => DateTime.now().subtract(Duration(days: dias));

    test('hoy y ayer tienen nombre propio', () {
      expect(relativeDate(DateTime.now()), 'Hoy');
      expect(relativeDate(hace(1)), 'Ayer');
    });

    test('cuenta en días la primera semana', () {
      expect(relativeDate(hace(3)), 'Hace 3 días');
      expect(relativeDate(hace(6)), 'Hace 6 días');
    });

    test('pasa a semanas y a meses', () {
      expect(relativeDate(hace(8)), 'Hace una semana');
      expect(relativeDate(hace(21)), 'Hace 3 semanas');
      expect(relativeDate(hace(45)), 'Hace un mes');
      expect(relativeDate(hace(120)), 'Hace 4 meses');
    });

    test('a partir del año da la fecha, porque "hace 14 meses" no dice nada', () {
      final DateTime vieja = DateTime(2020, 3, 7);
      expect(relativeDate(vieja), '7/3/2020');
    });

    // El reloj del móvil lo pone el usuario: una fecha futura puede llegar.
    test('una fecha futura no produce "hace -3 días"', () {
      final DateTime manana = DateTime.now().add(const Duration(days: 3));
      expect(relativeDate(manana), 'Hoy');
    });

    // Ayer a las 23:00 desde hoy a la 1:00 son dos horas, pero es "Ayer".
    test('compara días de calendario, no horas sueltas', () {
      final DateTime ayerTarde = DateTime.now()
          .subtract(const Duration(days: 1))
          .copyWith(hour: 23, minute: 30);

      expect(relativeDate(ayerTarde), 'Ayer');
    });
  });
}
