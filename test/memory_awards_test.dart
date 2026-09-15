import 'package:flutter_test/flutter_test.dart';
import 'package:palito_3_0/core/data/memory_awards.dart';

/// El motor de premios llevaba escrito desde el principio y **nunca se había
/// ejecutado**: vivía en una carpeta que no importaba nadie. Sus condiciones
/// comparan con cadenas de texto exactas ('Excelente', 'Inmediato', 'Podría
/// vivir aquí'), así que basta con que alguien reescriba la etiqueta de un
/// chip para que el premio deje de darse en silencio. De ahí estas pruebas.
void main() {
  group('awardsFor', () {
    List<String> ids(Map<String, dynamic> data) =>
        awardsFor(data).map((MemoryAward a) => a.id).toList();

    test('un recuerdo sin nada no gana nada', () {
      expect(awardsFor(<String, dynamic>{}), isEmpty);
    });

    test('Lugar inmaculado pide las dos condiciones, no una', () {
      expect(ids(<String, dynamic>{'limpieza': 'Excelente'}), isEmpty);
      expect(ids(<String, dynamic>{'detalle': 10}), isEmpty);
      expect(
        ids(<String, dynamic>{'limpieza': 'Excelente', 'detalle': 9}),
        contains('lugar_inmaculado'),
      );
    });

    test('el 9 es el listón: con 8,9 no se gana', () {
      expect(
        ids(<String, dynamic>{'limpieza': 'Excelente', 'detalle': 8.9}),
        isEmpty,
      );
    });

    test('Servicio relámpago', () {
      expect(
        ids(<String, dynamic>{'espera': 'Inmediato', 'nota_atencion': 9.5}),
        contains('servicio_relampago'),
      );
      expect(
        ids(<String, dynamic>{'espera': 'Muy rápido', 'nota_atencion': 10}),
        isEmpty,
      );
    });

    test('Oasis urbano con una sola condición', () {
      expect(
        ids(<String, dynamic>{'tiempo_espera': 'Podría vivir aquí'}),
        contains('oasis_urbano'),
      );
      expect(
        ids(<String, dynamic>{'tiempo_espera': 'Una copa más'}),
        isEmpty,
      );
    });

    test('se pueden ganar varios a la vez', () {
      expect(
        ids(<String, dynamic>{
          'limpieza': 'Excelente',
          'detalle': 10,
          'espera': 'Inmediato',
          'nota_atencion': 10,
          'tiempo_espera': 'Podría vivir aquí',
        }),
        hasLength(3),
      );
    });

    // La versión original hacía `(data['detalle'] ?? 0) >= 9` a pelo: con un
    // texto dentro eso no da un premio de menos, lanza una excepción y se
    // lleva por delante la pantalla del recuerdo.
    test('un número guardado como texto no revienta nada', () {
      expect(
        ids(<String, dynamic>{'limpieza': 'Excelente', 'detalle': '9.5'}),
        contains('lugar_inmaculado'),
      );
      expect(
        ids(<String, dynamic>{'limpieza': 'Excelente', 'detalle': '9,5'}),
        contains('lugar_inmaculado'),
      );
    });

    test('un tipo imposible tampoco revienta', () {
      expect(
        ids(<String, dynamic>{
          'limpieza': 'Excelente',
          'detalle': <String>['esto no debería estar aquí'],
        }),
        isEmpty,
      );
    });

    test('un null donde iba un número no se cuenta como cero ni como premio', () {
      expect(
        ids(<String, dynamic>{'limpieza': 'Excelente', 'detalle': null}),
        isEmpty,
      );
    });
  });
}
