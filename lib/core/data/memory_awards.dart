import 'package:flutter/material.dart';

/// ===========================================================================
/// LOS PREMIOS DE UN RECUERDO
/// ===========================================================================
///
/// Distinciones que se ganan solas: no se piden, no se votan y no se pueden
/// marcar. Salen de lo que ya contestaste en el formulario, y por eso cuando
/// aparecen significan algo.
///
/// ── NO CONFUNDIR CON EL CHIP «PREMIO» ──
///
/// Seis categorías tienen un grupo de chips llamado `premio` donde tú eliges
/// la medalla a mano («Reina del vermut», «Obra maestra»). Eso es una opinión
/// tuya, y está bien que lo sea. Esto es otra cosa: aquí nadie elige nada, se
/// deduce de lo que contaste en otras preguntas. Una lo dices tú; la otra te
/// la has ganado sin saberlo.
///
/// ── DE DÓNDE SALE ──
///
/// El motor estaba escrito en `features/memory_results/logic/`, dentro de una
/// carpeta de 511 líneas en siete ficheros que **no importaba nadie**: código
/// terminado, con tres premios y sus condiciones, que nunca se ejecutó ni una
/// vez porque no había pantalla que lo llamara.
///
/// Antes de darlo por bueno se comprobó, chip por chip y slider por slider,
/// que cada condición se correspondía con un valor que los formularios
/// guardan de verdad — que es donde suele morir el código heredado. Las cinco
/// del original coincidían. Las doce que se añadieron después salieron de
/// leer las ocho fábricas y copiar las etiquetas exactas.
///
/// Lo único que no existía era `comentario_general`, que era el motivo de que
/// la parte de «insights» enseñara «Sin comentarios adicionales» pasara lo
/// que pasara: la nota se guarda en `description`.
///
/// ── POR QUÉ AQUÍ ──
///
/// Porque es aritmética sobre un mapa: sin widgets, sin contexto y sin
/// Firestore. Así se puede probar, y se prueba (`test/memory_awards_test.dart`).
/// Con condiciones que comparan cadenas de texto exactas, basta con que
/// alguien reescriba la etiqueta de un chip para que un premio deje de darse
/// en silencio. Eso es justo lo que le pasó a este código durante meses.
class MemoryAward {
  const MemoryAward({
    required this.id,
    required this.title,
    required this.reason,
    required this.icon,
  });

  final String id;
  final String title;

  /// Por qué se ha ganado. Un premio que no dice qué has hecho para
  /// merecerlo es un adorno.
  final String reason;

  final IconData icon;
}

/// ¿Vale [expected] para este campo?
///
/// Sirve igual para un chip de una sola opción (guarda un `String`) que para
/// uno de selección múltiple (guarda una `List`). Sin esto habría que
/// recordar de memoria cuál es cuál al escribir cada condición, y la primera
/// vez que alguien se equivocara el premio no saltaría nunca sin dar la cara.
bool _has(dynamic value, String expected) {
  if (value is String) return value == expected;
  if (value is Iterable) return value.contains(expected);
  return false;
}

/// Lee un número sin fiarse del tipo.
///
/// Los sliders guardan `double`, pero un recuerdo de una versión vieja, de
/// una migración o de una edición a mano puede traer un `int` o la cifra como
/// texto. El motor original hacía `(data['detalle'] ?? 0) >= 9` a pelo: con
/// un `String` dentro, eso no da un premio de menos — **lanza una excepción y
/// se lleva por delante la pantalla del recuerdo entera**.
bool _atLeast(dynamic value, double threshold) {
  if (value is num) return value >= threshold;
  if (value is String) {
    final double? n = double.tryParse(value.replaceAll(',', '.'));
    return n != null && n >= threshold;
  }
  return false;
}

/// Los premios que se ha ganado este recuerdo.
///
/// Lista vacía si ninguno, que es lo normal y lo que se busca: si se ganaran
/// siempre no serían premios. Casi todos piden **dos** condiciones a la vez,
/// precisamente para que no se regalen.
List<MemoryAward> awardsFor(Map<String, dynamic> f) {
  final List<MemoryAward> awards = <MemoryAward>[];

  void give(String id, String title, String reason, IconData icon) {
    awards.add(
      MemoryAward(id: id, title: title, reason: reason, icon: icon),
    );
  }

  // ── Decoración / Espacio ────────────────────────────────────────────────
  if (_has(f['limpieza'], 'Excelente') && _atLeast(f['detalle'], 9)) {
    give(
      'lugar_inmaculado',
      'Lugar inmaculado',
      'Limpieza excelente y un 9 o más en atención al detalle.',
      Icons.auto_awesome_rounded,
    );
  }

  if (_has(f['tiempo_espera'], 'Podría vivir aquí')) {
    give(
      'oasis_urbano',
      'Oasis urbano',
      'De los sitios de los que no apetece levantarse.',
      Icons.park_rounded,
    );
  }

  // ── Atención ────────────────────────────────────────────────────────────
  if (_has(f['espera'], 'Inmediato') && _atLeast(f['nota_atencion'], 9)) {
    give(
      'servicio_relampago',
      'Servicio relámpago',
      'Os atendieron al momento y con un 9 o más de nota.',
      Icons.bolt_rounded,
    );
  }

  // ── Croquetas ───────────────────────────────────────────────────────────
  if (_has(f['bechamel'], 'Muy cremosa') &&
      _has(f['rebozado'], 'Crujiente perfecto')) {
    give(
      'croqueta_de_manual',
      'Croqueta de manual',
      'Bechamel muy cremosa y rebozado crujiente perfecto: el libro.',
      Icons.menu_book_rounded,
    );
  }

  if (_has(f['sensacion'], 'Religiosas')) {
    give(
      'experiencia_religiosa',
      'Experiencia religiosa',
      'Lo dijisteis vosotros, no yo.',
      Icons.church_rounded,
    );
  }

  // ── Tortilla ────────────────────────────────────────────────────────────
  if (_has(f['interior'], 'Melosa') &&
      _has(f['al_cortar'], 'Fue pornografía gastronómica')) {
    give(
      'el_corte',
      'El corte',
      'Interior meloso y lo que pasó al cortarla.',
      Icons.cut_rounded,
    );
  }

  if (_has(f['personalidad'], 'La que haría tu abuela')) {
    give(
      'como_en_casa',
      'Como en casa',
      'La que haría tu abuela, que es el listón más alto que hay.',
      Icons.favorite_rounded,
    );
  }

  // ── Ensaladilla ─────────────────────────────────────────────────────────
  if (_has(f['tipo_mayonesa'], 'Casera espectacular') &&
      _has(f['estado_patata'], 'Equilibrada')) {
    give(
      'ensaladilla_mayuscula',
      'Ensaladilla mayúscula',
      'Mayonesa casera espectacular y la patata en su punto.',
      Icons.workspace_premium_rounded,
    );
  }

  if (_has(f['ultimo_bocado'], 'Pedimos otra')) {
    give(
      'pedimos_otra',
      'Nos supo a poco',
      'Se acabó y pedisteis otra. No hay mejor nota que esa.',
      Icons.replay_rounded,
    );
  }

  // ── Menú ────────────────────────────────────────────────────────────────
  if (_has(f['ritmo'], 'Perfecto') && _has(f['coherencia'], 'Sí, totalmente')) {
    give(
      'menu_redondo',
      'Menú redondo',
      'Ritmo perfecto y todos los platos contando lo mismo.',
      Icons.donut_large_rounded,
    );
  }

  if (_has(f['pelicula'], 'Ganaría un Oscar')) {
    give(
      'ganaria_un_oscar',
      'Ganaría un Oscar',
      'Vuestras palabras, no las mías.',
      Icons.movie_filter_rounded,
    );
  }

  // ── Postres ─────────────────────────────────────────────────────────────
  if (_has(f['textura'], 'Perfecta') && _has(f['perfil_sabor'], 'Equilibrado')) {
    give(
      'postre_de_pasteleria',
      'Postre de pastelería',
      'Textura perfecta y sabor equilibrado: eso no sale por casualidad.',
      Icons.cake_rounded,
    );
  }

  if (_has(f['ultima_cucharada'], 'Quería otro')) {
    give(
      'queria_otro',
      'Quería otro',
      'Se terminó antes de tiempo.',
      Icons.icecream_rounded,
    );
  }

  // ── Plato estrella ──────────────────────────────────────────────────────
  if (_has(f['coccion'], 'Perfecto') && _has(f['equilibrio'], 'Perfecto')) {
    give(
      'punto_y_equilibrio',
      'Punto y equilibrio',
      'Cocción perfecta y sabores equilibrados a la vez. Raro de ver.',
      Icons.balance_rounded,
    );
  }

  if (_has(f['harias_por_volver'], 'Haría un viaje solo')) {
    give(
      'vale_el_viaje',
      'Vale el viaje',
      'Dijisteis que haríais un viaje solo por repetirlo.',
      Icons.flight_takeoff_rounded,
    );
  }

  return awards;
}
