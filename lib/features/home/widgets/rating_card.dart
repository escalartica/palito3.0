import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/data/rating_scale.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/theme/tokens/app_colors.dart';
import 'animated_card.dart';
import 'icon_box.dart';

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
    final double progress = RatingScale.progress(rating);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

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
          Semantics(
            label: isRated
                ? 'Puntuación ${rating.toStringAsFixed(1)} sobre '
                      '${RatingScale.max.toStringAsFixed(0)}. '
                      '${RatingScale.qualitativeLabel(rating)}'
                : 'Este recuerdo no tiene puntuación',
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double value, Widget? child) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('0', style: _scaleStyle),
              Flexible(
                child: Text(
                  RatingScale.qualitativeLabel(rating),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(RatingScale.max.toStringAsFixed(0), style: _scaleStyle),
            ],
          ),
        ],
      ),
    );
  }

  // `grey.shade500` sobre blanco da 2,68:1 — por debajo del mínimo de WCAG AA.
  TextStyle get _scaleStyle => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );
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
        color: isRated ? AppColors.primary : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
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
