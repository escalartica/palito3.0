import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// ===========================================================================
/// LA BARRA DE PROGRESO DE LA APP
/// ===========================================================================
///
/// Una sola, porque había tres escritas a mano en tres ficheros distintos y
/// las tres tenían el mismo fallo de fondo.
///
/// El fallo: la barra se rellenaba con el color de quien fuera —el amarillo
/// de marca, el color de un comensal— sobre una pista gris clara. El amarillo
/// sobre esa pista mide **1,17:1**. Es decir: el trozo lleno y el trozo vacío
/// eran, a efectos prácticos, el mismo color, y el único dato que la barra
/// existe para dar —cuánto llevas— no se podía ver. Con `LinearProgressIndicator`
/// pasaba igual, solo que sin poder arreglarlo.
///
/// Aquí el relleno lleva su propio contorno navy. La **forma** se lee aunque
/// el color no llegue, que es la única manera de que una barra funcione con
/// cualquier color encima, a pleno sol o con la vista cansada. Y con el
/// progreso a cero no se pinta nada: un relleno de ancho cero con borde
/// dibujaba una astilla navy en el borde izquierdo que parecía progreso.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.value,
    required this.color,
    this.height = 10,
  });

  /// De 0 a 1. Se recorta, así que un valor fuera de rango no rompe nada.
  final double value;

  /// Color del relleno.
  final Color color;

  final double height;

  @override
  Widget build(BuildContext context) {
    final double v = value.isNaN ? 0 : value.clamp(0.0, 1.0);
    final BorderRadius radius = BorderRadius.circular(height);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.tintMuted,
        borderRadius: radius,
        border: Border.all(color: AppColors.textPrimary, width: 1),
      ),
      child: v <= 0
          ? null
          : FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: radius,
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: 1,
                  ),
                ),
              ),
            ),
    );
  }
}
