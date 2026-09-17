import 'package:flutter/material.dart';

import 'mode_tab.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

const _kDark = AppColors.textPrimary;
const _kYellow = AppColors.primary;
const _kRed = AppColors.accent;

/// Selector de modo de juego (Ruleta / Juicio picante) de la ruleta.
///
/// ── YA NO ES UNA ISLA ──
///
/// Era una pastilla blanca con su borde y su sombra, flotando encima del
/// panel de la partida. Pero este control no es una cosa aparte: **elige qué
/// hace ese panel**. Tenerlo como bloque independiente daba cuatro objetos
/// apilados con el mismo peso —nota, selector, panel y botón—, que es la
/// razón real de que la pantalla se leyera como una lista de cajas en vez de
/// como una pantalla.
///
/// Ahora va dentro de la tarjeta del panel, a lo ancho y pegado a su borde
/// superior, con una línea navy debajo. Es una cabecera de pestañas de toda
/// la vida: el relleno de color marca el modo justo donde antes había un
/// filete decorativo, y la app tiene un borde menos que dibujar.
class ModeSelector extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.selectedMode,
    required this.onSelect,
  });
  final int selectedMode;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        children: <Widget>[
          ModeTab(
            // "Quién elige", no "Ruleta": con la pestaña llamándose ya
            // "La ruleta", este modo repetía la palabra en el nivel de
            // abajo — la misma palabra para dos cosas distintas, que es el
            // fallo que este proyecto ya ha pagado con "Plato Estrella".
            //
            // Y de paso los dos modos pasan a decir QUÉ HACEN: uno señala
            // quién elige el plato, el otro a quién le cae el reto. Antes
            // uno nombraba el mecanismo y el otro el resultado.
            label: 'Quién elige',
            index: 0,
            selectedMode: selectedMode,
            activeColor: _kYellow,
            onTap: onSelect,
          ),
          ModeTab(
            label: 'Juicio picante',
            index: 1,
            selectedMode: selectedMode,
            activeColor: _kRed,
            onTap: onSelect,
          ),
        ],
      ),
      // La línea que separa la cabecera del escenario. Navy y del mismo
      // grosor que los bordes de la app: es un borde, no un adorno.
      Container(height: AppBorder.thin, color: _kDark),
    ],
  );
}
