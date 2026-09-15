import 'package:flutter/material.dart';

import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';
import '../../../core/theme/tokens/app_typography.dart';

class MemoryInsightsWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const MemoryInsightsWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Joyas de la Experiencia", style: AppTypography.titleMedium),
        const SizedBox(height: 15),

        // Fila de datos creativos
        _insightTile(
          Icons.movie_filter,
          "Película",
          data['pelicula'] ?? "Sin definir",
        ),
        _insightTile(
          Icons.music_note,
          "Banda Sonora",
          data['banda_sonora'] ?? "Sin definir",
        ),
        _insightTile(
          Icons.person,
          "Personalidad",
          data['personalidad'] ?? "Sin definir",
        ),

        const SizedBox(height: 15),
        Text("Comentario General", style: AppTypography.labelLarge),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          // Relleno cálido + borde navy fino: la misma caja de "nota" que
          // usa el resto de la app, en vez de un gris sin origen.
          decoration: BoxDecoration(
            color: AppColors.surfaceWarm,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppBorder.thin,
            ),
          ),
          child: Text(
            data['comentario_general'] ?? "Sin comentarios adicionales.",
            style: AppTypography.bodyMedium.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _insightTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Coral: el color de marca reservado para rellenos e iconografía
          // decorativa, nunca para texto (no cumple contraste AA).
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Text("$title: ", style: AppTypography.labelLarge),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
