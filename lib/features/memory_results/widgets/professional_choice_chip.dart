import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens/app_animation.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

class ProfessionalChoiceChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const ProfessionalChoiceChip({
    super.key,
    required this.label,
    this.icon, // El icono ahora es opcional y profesional
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: AppAnimation.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          // Borde más grueso si está seleccionado
          border: Border.all(
            color: AppColors.textPrimary,
            width: isSelected ? 2.0 : 1.0,
          ),
          // Sombra dura estilo neobrutalista solo al seleccionar
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: AppColors.textPrimary,
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
