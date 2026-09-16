import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/data/rating_scale.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/theme/components/star_row.dart';
import '../../../core/theme/tokens/app_colors.dart';
import 'animated_card.dart';
import 'icon_box.dart';
import '../../../core/theme/tokens/app_shape.dart';

/// Card de puntuación del recuerdo: barra de progreso animada sobre la escala
/// real de la app (0 a 5 — ver [RatingScale]) con su etiqueta cualitativa.
///
/// Esta tarjeta pintaba antes una escala 0–10 sobre datos guardados en 0–5,
/// así que la nota máxima se veía a media barra y rotulada "Por mejorar".
class RatingCard extends StatelessWidget {
  const RatingCard({super.key, required this.memory});

  final MemoryModel memory;

  @override
  Widget build(BuildContext context) {
    final double rating = memory.rating.clamp(0.0, RatingScale.max).toDouble();
    final bool isRated = RatingScale.isRated(rating);

    return AnimatedCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const IconBox(
                      icon: Icons.star_rounded,
                      backgroundColor: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Puntuación',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RatingBadge(rating: rating, isRated: isRated),
            ],
          ),
          const SizedBox(height: 18),
          // Las MISMAS estrellas con las que se puso la nota. Aquí había una
          // barra de progreso con un "0" y un "5" a los lados: el dato se
          // pedía de una forma y se enseñaba de otra. Ver `star_row.dart`.
          Center(
            child: StarRow(
              rating: rating,
              isRated: isRated,
              size: 34,
              alignment: MainAxisAlignment.center,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              // Sin nota no hay veredicto que dar. `qualitativeLabel` de un
              // recuerdo sin puntuar devolvía igualmente una etiqueta, y la
              // tarjeta afirmaba una opinión que nadie había dado.
              isRated
                  ? RatingScale.qualitativeLabel(rating)
                  : 'Este recuerdo se guardó sin nota',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isRated
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating, required this.isRated});

  final double rating;
  final bool isRated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        // Opaco. Con `alpha: 0.10` pasaba el 90 % de la sombra navy y el
        // fondo acababa siendo EXACTAMENTE el mismo navy del texto: 1,00:1.
        // La pastilla "sin nota" no se leía en absoluto.
        color: isRated ? AppColors.primary : AppColors.tintMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.textPrimary, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.textPrimary,
            blurRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isRated ? Icons.star_rounded : Icons.star_border_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 5),
          Text(
            // "0.0" se lee como una valoración pésima; la mayoría de los
            // recuerdos anteriores a esta versión simplemente no tienen nota.
            RatingScale.shortLabel(rating) ?? 'Sin nota',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
