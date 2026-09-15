import 'package:flutter/material.dart';

/// ===========================================================================
/// LOS PREMIOS DE UN RECUERDO
/// ===========================================================================
///
/// Distinciones que se ganan solas: no se piden, no se votan y no se pueden
/// forzar. Salen de lo que ya contestaste en el formulario, y por eso cuando
/// aparecen significan algo.
///
/// ── DE DÓNDE SALE ESTO ──
///
/// Este motor ya estaba escrito, en `features/memory_results/logic/`, dentro
/// de una carpeta de 511 líneas en siete ficheros que **no importaba nadie**:
/// código terminado, con sus premios y sus condiciones, que nunca llegó a
/// ejecutarse ni una vez porque no había ninguna pantalla que lo llamara.
///
/// Antes de darlo por bueno se comprobó campo por campo que las condiciones
/// se correspondían con lo que los formularios guardan de verdad, que es
/// donde suele morir el código heredado:
///
/// | Condición                          | Dónde vive                        |
/// | ---------------------------------- | --------------------------------- |
/// | `limpieza == 'Excelente'`          | primer chip de Limpieza           |
/// | `detalle >= 9`                     | slider 0-10 de Atención al detalle|
/// | `espera == 'Inmediato'`            | primer chip de Tiempo de espera   |
/// | `nota_atencion >= 9`               | slider 0-10 de Nota de la atención|
/// | `tiempo_espera == 'Podría vivir aquí'` | último chip de Tiempo tras comer |
///
/// Las cinco coinciden exactamente. Lo único que no existía era
/// `comentario_general`, que era el motivo de que la parte de "insights"
/// enseñara "Sin comentarios adicionales" pasara lo que pasara: la nota se
/// guarda en `description`.
///
/// ── POR QUÉ AQUÍ Y NO ALLÍ ──
///
/// Porque es aritmética sobre un mapa: sin widgets, sin contexto y sin
/// Firestore. Así se puede probar, y de hecho se prueba
/// (`test/memory_awards_test.dart`). La versión anterior no tenía ni una
/// prueba, y con condiciones de este tipo —comparaciones con cadenas de
/// texto exactas— basta con que alguien reescriba un chip para que el premio
/// deje de darse sin que nadie se entere.
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

/// Lee un número de `specificFields` sin fiarse del tipo.
///
/// Los sliders guardan `double`, pero un recuerdo que venga de una versión
/// vieja, de una migración o de una edición a mano puede traer un `int` o
/// incluso la cifra como texto. El motor original hacía
/// `(data['detalle'] ?? 0) >= 9` a pelo: con un `String` dentro, eso no da un
/// premio de menos, **revienta la pantalla del recuerdo entera**.
double? _number(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

bool _atLeast(dynamic value, double threshold) {
  final double? n = _number(value);
  return n != null && n >= threshold;
}

/// Los premios que se ha ganado este recuerdo. Lista vacía si ninguno, que
/// es lo normal: si se ganaran siempre no serían premios.
List<MemoryAward> awardsFor(Map<String, dynamic> specificFields) {
  final List<MemoryAward> awards = <MemoryAward>[];

  if (specificFields['limpieza'] == 'Excelente' &&
      _atLeast(specificFields['detalle'], 9)) {
    awards.add(
      const MemoryAward(
        id: 'lugar_inmaculado',
        title: 'Lugar inmaculado',
        reason: 'Limpieza excelente y un 9 o más en atención al detalle.',
        icon: Icons.auto_awesome_rounded,
      ),
    );
  }

  if (specificFields['espera'] == 'Inmediato' &&
      _atLeast(specificFields['nota_atencion'], 9)) {
    awards.add(
      const MemoryAward(
        id: 'servicio_relampago',
        title: 'Servicio relámpago',
        reason: 'Os atendieron al momento y con un 9 o más de nota.',
        icon: Icons.bolt_rounded,
      ),
    );
  }

  if (specificFields['tiempo_espera'] == 'Podría vivir aquí') {
    awards.add(
      const MemoryAward(
        id: 'oasis_urbano',
        title: 'Oasis urbano',
        reason: 'De los sitios de los que no apetece levantarse.',
        icon: Icons.park_rounded,
      ),
    );
  }

  return awards;
}
