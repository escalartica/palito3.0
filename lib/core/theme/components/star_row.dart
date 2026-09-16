import 'package:flutter/material.dart';

import '../../data/rating_scale.dart';
import '../tokens/app_colors.dart';

/// ===========================================================================
/// LAS ESTRELLAS
/// ===========================================================================
///
/// Una sola implementación del dibujo, para el formulario (donde se tocan) y
/// para la ficha del recuerdo (donde solo se leen).
///
/// POR QUÉ EXISTE. Al pasar la puntuación de un tirador a estrellas se cambió
/// el formulario y se dejó la ficha como estaba: una **barra de progreso de 0
/// a 5**. O sea que el mismo número se pedía de una forma y se enseñaba de
/// otra — pones cuatro estrellas y al abrir el recuerdo te encuentras una
/// barra amarilla a cuatro quintos con un "0" a la izquierda y un "5" a la
/// derecha. No es que la barra estuviera mal: es que eran dos idiomas para
/// el mismo dato, y eso es exactamente lo que hace que una app se sienta a
/// medio hacer.
///
/// Y está en un solo sitio a propósito. Este proyecto ya ha pagado dos veces
/// el precio de tener el mismo widget copiado en dos pantallas: las copias
/// divergen y el fallo aparece en una sola de ellas.
/// ===========================================================================

/// Una estrella. [fill] es 0 (vacía), 1 (media) o 2 (entera).
class Star extends StatelessWidget {
  const Star({super.key, required this.fill, this.size = 40});

  final int fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (fill > 0)
            Icon(
              fill == 2 ? Icons.star_rounded : Icons.star_half_rounded,
              size: size,
              color: AppColors.primary,
            ),
          // El contorno va SIEMPRE, encima del relleno. El amarillo de marca
          // sobre blanco mide 1,43:1; con el contorno navy, la estrella se
          // distingue del fondo pase lo que pase con el color.
          Icon(
            Icons.star_outline_rounded,
            size: size,
            color: fill > 0 ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

/// Las cinco estrellas de una nota, solo para leer.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.rating,
    this.size = 28,
    this.isRated = true,
    this.alignment = MainAxisAlignment.start,
  });

  final double rating;
  final double size;

  /// Sin nota, las cinco salen vacías aunque `rating` valga 0 por dentro.
  /// Cinco estrellas apagadas dicen "no puntuado"; cinco estrellas con un
  /// cero dicen "le has puesto un cero", que en una app de comida es una
  /// acusación.
  final bool isRated;

  final MainAxisAlignment alignment;

  /// Cuánto se rellena la estrella [index] (empezando en 1) con esta nota.
  /// Misma regla que usa el formulario: media a partir de x,5.
  static int fillFor(double rating, int index) {
    if (rating >= index) return 2;
    if (rating >= index - 0.5) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isRated
          ? 'Puntuación ${RatingScale.shortLabel(rating) ?? ""} sobre '
                '${RatingScale.max.toStringAsFixed(0)}'
          : 'Sin puntuación',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: alignment,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 1; i <= RatingScale.max.toInt(); i++)
              Star(fill: isRated ? fillFor(rating, i) : 0, size: size),
          ],
        ),
      ),
    );
  }
}
