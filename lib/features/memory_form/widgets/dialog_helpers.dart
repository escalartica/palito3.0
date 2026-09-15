import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

/// Fila seleccionable del bottom sheet "Seleccionar fotografía" (cámara /
/// galería) abierto por `_MemoryFormPageState._showImageSourceDialog`.
class ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const ImageSourceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textPrimary, width: 2),
        ),
        child: Icon(icon, color: AppColors.textPrimary),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}
