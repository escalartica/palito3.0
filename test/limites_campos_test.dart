import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:palito_3_0/core/data/field_limits.dart';

/// ===========================================================================
/// EL CLIENTE Y EL SERVIDOR, DE ACUERDO
/// ===========================================================================
///
/// `firestore.rules` no viaja con la app: se despliega aparte. O sea que la
/// única forma de que un tope del servidor y el `maxLength` de un campo se
/// mantengan iguales es que algo los compare — porque quien edita las reglas
/// casi nunca está editando a la vez la pantalla.
///
/// El fallo que esto evita no es bonito: escribes un título largo, rellenas
/// el formulario, subes la foto, le das a guardar y la app dice «no se pudo
/// guardar». Sin decir qué. Con todo el trabajo hecho.
int? _limiteDeLaRegla(String reglas, String campo) {
  final RegExp re = RegExp(
    r'data\.' + campo + r'\.size\(\)\s*<=\s*(\d+)',
  );
  final RegExpMatch? m = re.firstMatch(reglas);
  return m == null ? null : int.parse(m.group(1)!);
}

void main() {
  late String reglas;

  setUpAll(() {
    final File f = File('firestore.rules');
    expect(
      f.existsSync(),
      isTrue,
      reason:
          'No encuentro firestore.rules en la raíz del proyecto. Si se ha '
          'movido, esta prueba deja de proteger nada.',
    );
    reglas = f.readAsStringSync();
  });

  test('el tope del título del recuerdo es el que acepta el servidor', () {
    final int? servidor = _limiteDeLaRegla(reglas, 'title');

    expect(
      servidor,
      isNotNull,
      reason:
          'La regla que limita el título ha desaparecido de firestore.rules. '
          'Si se ha quitado a propósito, quita también esta prueba; si no, '
          'el servidor ya no protege ese campo.',
    );
    expect(
      FieldLimits.tituloRecuerdo,
      servidor,
      reason:
          'El campo del plato acepta ${FieldLimits.tituloRecuerdo} '
          'caracteres y el servidor acepta $servidor. Quien escriba de más '
          'perderá el recuerdo entero con un «no se pudo guardar».',
    );
  });

  test('el tope del nombre de un diario es el que acepta el servidor', () {
    final int? servidor = _limiteDeLaRegla(reglas, 'name');

    expect(servidor, isNotNull);
    expect(
      FieldLimits.nombreDiario,
      servidor,
      reason:
          'El campo del nombre del diario y la regla `validName()` de '
          'firestore.rules dicen cosas distintas.',
    );
  });
}
