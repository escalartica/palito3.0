import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/components/smart_image.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';
import '../../../core/theme/tokens/app_animation.dart';

/// Recuadro de foto del formulario de recuerdo: muestra la miniatura
/// recién elegida, la foto ya guardada (vía [SmartImage]) o un estado
/// vacío invitando a añadir una. Tocar cualquiera de los tres estados
/// dispara [onTap] (en `_MemoryFormPageState`, esto abre el selector de
/// fuente cámara/galería).
class PhotoSection extends StatelessWidget {
  final VoidCallback onTap;
  final AnimationController photoAnimationController;
  final XFile? tempMediaFile;
  final Uint8List? tempMediaBytes;
  final String? existingImagePath;

  const PhotoSection({
    super.key,
    required this.onTap,
    required this.photoAnimationController,
    required this.tempMediaFile,
    required this.tempMediaBytes,
    required this.existingImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        tempMediaFile != null ||
        (existingImagePath != null && existingImagePath!.isNotEmpty);

    return GestureDetector(
      onTap: onTap,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.0).animate(
          CurvedAnimation(
            parent: photoAnimationController,
            curve: AppAnimation.pop,
          ),
        ),
        child: AnimatedContainer(
          duration: AppAnimation.slow,
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceWarm,
            border: Border.all(color: AppColors.textPrimary, width: 2),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: const [
              BoxShadow(
                color: AppColors.textPrimary,
                blurRadius: 0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            // 2 pt menos que el radio exterior (AppRadius.md): con el mismo
            // radio, el borde grueso deja una franja recta visible en las
            // esquinas en vez de seguir la curva.
            borderRadius: BorderRadius.circular(AppRadius.md - 2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (tempMediaBytes != null)
                  Image.memory(tempMediaBytes!, fit: BoxFit.cover)
                else if (existingImagePath != null &&
                    existingImagePath!.isNotEmpty)
                  SmartImage(imagePath: existingImagePath, fit: BoxFit.cover)
                else
                  const _EmptyPhotoState(),

                if (hasImage)
                  const Positioned(
                    bottom: 12,
                    right: 12,
                    child: _ChangePhotoBadge(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPhotoState extends StatelessWidget {
  const _EmptyPhotoState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: AppAnimation.slow,
          curve: AppAnimation.pop,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textPrimary, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.textPrimary,
                  blurRadius: 0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 24,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Añadir foto del plato o lugar",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ChangePhotoBadge extends StatelessWidget {
  const _ChangePhotoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.textPrimary, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.textPrimary,
            blurRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text(
            "Cambiar foto",
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
