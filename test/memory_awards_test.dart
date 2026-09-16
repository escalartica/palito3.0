import 'package:flutter_test/flutter_test.dart';
import 'package:palito_3_0/core/data/memory_awards.dart';

/// El motor de premios llevaba escrito desde el principio y **nunca se había
/// ejecutado**: vivía en una carpeta que no importaba nadie. Sus condiciones
/// comparan con etiquetas de chip exactas ('Excelente', 'Crujiente perfecto',
/// 'Fue pornografía gastronómica'), así que basta con que alguien reescriba
/// una etiqueta en una fábrica para que el premio deje de darse en silencio.
/// De ahí estas pruebas: son el contrato entre los formularios y los premios.
void main() {
  List<String> ids(Map<String, dynamic> data) =>
      awardsFor(data).map((MemoryAward a) => a.id).toList();

  group('lo básico', () {
    test('un recuerdo sin nada no gana nada', () {
      expect(awardsFor(<String, dynamic>{}), isEmpty);
    });

    test('todos los premios tienen id, título y motivo', () {
      final List<MemoryAward> all = awardsFor(<String, dynamic>{
        'limpieza': 'Excelente', 'detalle': 10,
        'tiempo_espera': 'Podría vivir aquí',
        'espera': 'Inmediato', 'nota_atencion': 10,
        'bechamel': 'Muy cremosa', 'rebozado': 'Crujiente perfecto',
        'sensacion': <String>['Religiosas'],
        'interior': 'Melosa', 'al_cortar': 'Fue pornografía gastronómica',
        'personalidad': 'La que haría tu abuela',
        'tipo_mayonesa': 'Casera espectacular', 'estado_patata': 'Equilibrada',
        'ultimo_bocado': 'Pedimos otra',
        'ritmo': 'Perfecto', 'coherencia': 'Sí, totalmente',
        'pelicula': 'Ganaría un Oscar',
        'textura': <String>['Perfecta'], 'perfil_sabor': <String>['Equilibrado'],
        'ultima_cucharada': 'Quería otro',
        'coccion': 'Perfecto', 'equilibrio': 'Perfecto',
        'harias_por_volver': 'Haría un viaje solo',
      });

      expect(all, hasLength(15));
      for (final MemoryAward a in all) {
        expect(a.id, isNotEmpty);
        expect(a.title, isNotEmpty);
        expect(a.reason, isNotEmpty);
      }
      expect(
        all.map((MemoryAward a) => a.id).toSet(),
        hasLength(15),
        reason: 'ningún id se repite',
      );
    });
  });

  group('las que piden dos condiciones no se regalan con una', () {
    final Map<String, Map<String, dynamic>> dobles =
        <String, Map<String, dynamic>>{
      'lugar_inmaculado': <String, dynamic>{
        'limpieza': 'Excelente',
        'detalle': 9,
      },
      'servicio_relampago': <String, dynamic>{
        'espera': 'Inmediato',
        'nota_atencion': 9,
      },
      'croqueta_de_manual': <String, dynamic>{
        'bechamel': 'Muy cremosa',
        'rebozado': 'Crujiente perfecto',
      },
      'el_corte': <String, dynamic>{
        'interior': 'Melosa',
        'al_cortar': 'Fue pornografía gastronómica',
      },
      'ensaladilla_mayuscula': <String, dynamic>{
        'tipo_mayonesa': 'Casera espectacular',
        'estado_patata': 'Equilibrada',
      },
      'menu_redondo': <String, dynamic>{
        'ritmo': 'Perfecto',
        'coherencia': 'Sí, totalmente',
      },
      'postre_de_pasteleria': <String, dynamic>{
        'textura': <String>['Perfecta'],
        'perfil_sabor': <String>['Equilibrado'],
      },
      'punto_y_equilibrio': <String, dynamic>{
        'coccion': 'Perfecto',
        'equilibrio': 'Perfecto',
      },
    };

    dobles.forEach((String id, Map<String, dynamic> completo) {
      test('$id pide las dos', () {
        expect(ids(completo), contains(id));

        for (final String key in completo.keys) {
          final Map<String, dynamic> aMedias =
              Map<String, dynamic>.from(completo)..remove(key);
          expect(
            ids(aMedias),
            isNot(contains(id)),
            reason: 'sin "$key" no debería darse',
          );
        }
      });
    });
  });

  group('umbrales y tipos', () {
    test('el 9 es el listón: con 8,9 no se gana', () {
      expect(
        ids(<String, dynamic>{'limpieza': 'Excelente', 'detalle': 8.9}),
        isEmpty,
      );
    });

    // El motor original hacía `(data['detalle'] ?? 0) >= 9` a pelo: con un
    // texto dentro no da un premio de menos, lanza una excepción y se lleva
    // por delante la pantalla del recuerdo.
    test('un número guardado como texto no revienta nada', () {
      for (final String raw in <String>['9', '9.5', '9,5', '10']) {
        expect(
          ids(<String, dynamic>{'limpieza': 'Excelente', 'detalle': raw}),
          contains('lugar_inmaculado'),
          reason: 'con "$raw"',
        );
      }
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

    test('un null no cuenta ni como cero ni como premio', () {
      expect(
        ids(<String, dynamic>{'limpieza': 'Excelente', 'detalle': null}),
        isEmpty,
      );
    });
  });

  group('selección múltiple', () {
    // `sensacion`, `textura` y `perfil_sabor` guardan listas. Escribir la
    // condición como si fueran texto es el error silencioso más fácil de
    // cometer aquí.
    test('una lista con la opción dentro cuenta', () {
      expect(
        ids(<String, dynamic>{
          'sensacion': <String>['Muy buenas', 'Religiosas'],
        }),
        contains('experiencia_religiosa'),
      );
    });

    test('una lista sin la opción no cuenta', () {
      expect(
        ids(<String, dynamic>{'sensacion': <String>['Meh', 'Mediocres']}),
        isEmpty,
      );
    });

    test('una lista vacía no cuenta', () {
      expect(ids(<String, dynamic>{'sensacion': <String>[]}), isEmpty);
    });

    test('el mismo campo como texto suelto también cuenta', () {
      expect(
        ids(<String, dynamic>{'sensacion': 'Religiosas'}),
        contains('experiencia_religiosa'),
      );
    });
  });

  group('un valor parecido pero distinto no vale', () {
    test('«Muy rápido» no es «Inmediato»', () {
      expect(
        ids(<String, dynamic>{'espera': 'Muy rápido', 'nota_atencion': 10}),
        isEmpty,
      );
    });

    test('«Una copa más» no es «Podría vivir aquí»', () {
      expect(ids(<String, dynamic>{'tiempo_espera': 'Una copa más'}), isEmpty);
    });

    test('«Bastante» no es «Sí, totalmente»', () {
      expect(
        ids(<String, dynamic>{'ritmo': 'Perfecto', 'coherencia': 'Bastante'}),
        isEmpty,
      );
    });
  });
}
