import 'package:flutter/material.dart';

import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';
import '../../../core/theme/tokens/app_typography.dart';

class MemoryHeroCard extends StatelessWidget {
  final String nombreRestaurante;
  final double score;
  final bool volverias;

  const MemoryHeroCard({
    super.key,
    required this.nombreRestaurante,
    required this.score,
    required this.volverias,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      // Borde grueso + sombra maciza sin difuminar: la misma superficie
      // "sticker" que el resto de tarjetas de la app, en vez de la sombra
      // difuminada de Material que traía esta pantalla.
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.textPrimary,
          width: AppBorder.normal,
        ),
        boxShadow: AppShadow.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("RESTAURANTE", style: AppTypography.labelSmall),
                const SizedBox(height: 4),
                Text(nombreRestaurante, style: AppTypography.headlineSmall),
                const SizedBox(height: 12),
                _indicatorChip(
                  volverias ? "Volvería sin duda" : "No repetiría",
                  volverias ? AppColors.success : AppColors.error,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppBorder.thin,
              ),
            ),
            child: Column(
              children: [
                Text(
                  score.toStringAsFixed(1),
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
                Text(
                  "SCORE",
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicatorChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color, width: AppBorder.thin),
      ),
      child: Text(
        text,
        style: AppTypography.labelMedium.copyWith(color: color),
      ),
    );
  }
}
