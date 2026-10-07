// test/fuentes_empaquetadas_test.dart
//
// ══ POR QUÉ EXISTE ESTA PRUEBA ══
//
// La app empaquetó durante días trece ficheros en `google_fonts/` con la
// extensión `.ttf` que NO eran TrueType: eran EOT, un formato de fuente de
// Internet Explorer. Skia no sabe leerlo, así que Flutter se los saltaba en
// silencio y pintaba toda la app con la Helvetica del sistema.
//
// No lo cazó nadie porque no hay error. No hay excepción, no hay aviso en
// consola, no hay nada rojo: la app arranca, se ve bien y simplemente no es
// la tipografía que se diseñó. Se descubrió ampliando una captura de pantalla
// y notando que la «r» de «Tus recuerdos» no era la de Outfit.
//
// Y es peor de lo que parece, porque `main.dart` pone
// `GoogleFonts.config.allowRuntimeFetching = false` a propósito —para que la
// app no dependa de la red—. Con esa línea puesta, si los ficheros locales no
// sirven no hay plan B: no se descargan, no hay red que valga, y la identidad
// visual entera desaparece sin decir ni mu.
//
// Un fichero de fuente se identifica por sus cuatro primeros bytes:
//
//     00 01 00 00   TrueType
//     74 72 75 65   'true'  (TrueType de Apple)
//     4F 54 54 4F   'OTTO'  (OpenType con curvas CFF)
//     77 4F 46 32   'wOF2'  (WOFF2 — vale en web, NO en Flutter)
//
// Un EOT empieza por su propio tamaño en bytes, así que el primer byte
// cambia con cada fichero y no se parece a ninguna de las firmas de arriba.
// Comprobarlo cuesta leer cuatro bytes por fuente.
//
// La prueba lee además `pubspec.yaml` para no fiarse de una lista escrita a
// mano aquí: si mañana se añade una fuente nueva a la carpeta, entra sola.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Las cuatro firmas que Flutter sabe cargar.
const Map<String, List<int>> _firmasValidas = <String, List<int>>{
  'TrueType': <int>[0x00, 0x01, 0x00, 0x00],
  "'true'": <int>[0x74, 0x72, 0x75, 0x65],
  "'OTTO'": <int>[0x4F, 0x54, 0x54, 0x4F],
};

/// WOFF y WOFF2 son formatos de web. Se listan aparte para poder decir en el
/// mensaje de error QUÉ es el fichero, en vez de un «formato desconocido»
/// que obligaría a investigar desde cero.
const Map<String, List<int>> _firmasDeWeb = <String, List<int>>{
  'WOFF (formato web, no vale en Flutter)': <int>[0x77, 0x4F, 0x46, 0x46],
  'WOFF2 (formato web, no vale en Flutter)': <int>[0x77, 0x4F, 0x46, 0x32],
};

bool _empiezaPor(Uint8List bytes, List<int> firma) {
  if (bytes.length < firma.length) return false;
  for (int i = 0; i < firma.length; i++) {
    if (bytes[i] != firma[i]) return false;
  }
  return true;
}

String _queEs(Uint8List bytes) {
  for (final MapEntry<String, List<int>> e in _firmasValidas.entries) {
    if (_empiezaPor(bytes, e.value)) return e.key;
  }
  for (final MapEntry<String, List<int>> e in _firmasDeWeb.entries) {
    if (_empiezaPor(bytes, e.value)) return e.key;
  }
  return 'formato desconocido (primeros bytes: '
      '${bytes.take(4).map((int b) => b.toRadixString(16).padLeft(2, '0')).join(' ')})';
}

void main() {
  test('las fuentes empaquetadas son TrueType de verdad, no EOT ni WOFF', () {
    final Directory carpeta = Directory('google_fonts');

    expect(
      carpeta.existsSync(),
      isTrue,
      reason:
          'No existe google_fonts/. Si se ha movido, hay que mover también '
          'esta prueba y la entrada de assets de pubspec.yaml.',
    );

    final List<File> fuentes =
        carpeta
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.toLowerCase().endsWith('.ttf'))
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path));

    expect(
      fuentes,
      isNotEmpty,
      reason:
          'google_fonts/ está vacía. Con '
          '`GoogleFonts.config.allowRuntimeFetching = false` en main.dart, '
          'eso deja la app entera con la tipografía del sistema.',
    );

    final List<String> rotas = <String>[];
    for (final File fuente in fuentes) {
      final Uint8List bytes = fuente.readAsBytesSync();
      final bool vale = _firmasValidas.values.any(
        (List<int> firma) => _empiezaPor(bytes, firma),
      );
      if (!vale) {
        rotas.add('  ${fuente.uri.pathSegments.last}: ${_queEs(bytes)}');
      }
    }

    expect(
      rotas,
      isEmpty,
      reason:
          'Estos ficheros tienen extensión .ttf pero no son fuentes que '
          'Flutter pueda cargar. La app arrancará igual y pintará con la '
          'tipografía del sistema sin dar ningún error:\n'
          '${rotas.join('\n')}\n\n'
          'Se arreglan bajando el TrueType de verdad. Los de Google Fonts '
          'están en github.com/google/fonts; los variables se convierten a '
          'pesos sueltos con `fonttools varLib.instancer`.',
    );
  });

  test('pubspec.yaml declara google_fonts/ como assets', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      pubspec.contains('google_fonts/'),
      isTrue,
      reason:
          'pubspec.yaml no declara google_fonts/ en assets. Sin esa línea '
          'los ficheros no viajan dentro de la app, y con '
          '`allowRuntimeFetching = false` tampoco se descargan: la app se '
          'queda sin tipografía y sin avisar.',
    );
  });
}
