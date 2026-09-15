import 'package:flutter/material.dart';

import '../../../core/theme/components/smart_image.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';
import '../../../core/theme/tokens/app_typography.dart';

class MemoryGalleryWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const MemoryGalleryWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Obtenemos la lista de URLs del modelo o el campo individual
    final List<dynamic>? imageUrls = data['imageUrls'];
    final String? imagePath = (imageUrls != null && imageUrls.isNotEmpty)
        ? imageUrls.first
        : data['image_path'];
    final String? videoPath = data['video_path'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Galería del Recuerdo", style: AppTypography.titleMedium),
        const SizedBox(height: 15),

        // Imagen Principal, enmarcada como el resto de tarjetas de la app.
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppBorder.normal,
            ),
            boxShadow: AppShadow.sm,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md - AppBorder.normal),
            child: (imagePath != null && imagePath.isNotEmpty)
                ? SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: SmartImage(imagePath: imagePath),
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    color: AppColors.surfaceWarm,
                    child: Icon(
                      Icons.image,
                      size: 50,
                      color: AppColors.textMuted,
                    ),
                  ),
          ),
        ),

        // Botón de Vídeo si existe
        if (videoPath != null && videoPath.isNotEmpty) ...[
          const SizedBox(height: 15),
          ListTile(
            onTap: () {
              // Lógica de navegación a vídeo
            },
            leading: const Icon(
              Icons.play_circle_fill,
              // Coral de marca: mismo lenguaje decorativo que el resto de
              // esta pantalla, en vez de un índigo de Material sin relación
              // con la paleta.
              color: AppColors.accent,
              size: 40,
            ),
            title: Text("Ver momento ambiente", style: AppTypography.bodyLarge),
            subtitle: Text(
              "Toca para revivir el sonido y el entorno",
              style: AppTypography.bodySmall,
            ),
            tileColor: AppColors.accent.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              side: BorderSide(
                color: AppColors.textPrimary,
                width: AppBorder.thin,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
