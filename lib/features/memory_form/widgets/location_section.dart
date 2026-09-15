import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'form_field_containers.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_animation.dart';
import '../../../core/theme/tokens/app_shape.dart';

/// Campo de ubicación del formulario de recuerdo: texto libre + botón de
/// GPS. El estado de la geolocalización (coordenadas actuales, si se
/// están obteniendo...) lo sigue gestionando `_MemoryFormPageState`; este
/// widget solo pinta el campo y reenvía sus eventos hacia arriba.
class LocationSection extends StatelessWidget {
  final TextEditingController controller;
  final bool isGettingLocation;
  final AnimationController gpsAnimationController;
  final VoidCallback onGpsTap;
  final ValueChanged<String>? onAddressChanged;

  const LocationSection({
    super.key,
    required this.controller,
    required this.isGettingLocation,
    required this.gpsAnimationController,
    required this.onGpsTap,
    this.onAddressChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel("Ubicación"),
        const SizedBox(height: 8),
        NeoContainer(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onAddressChanged,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  decoration: memoryFormInputDecoration(
                    "Escribe una ciudad o dirección",
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _GpsButton(
                  isGettingLocation: isGettingLocation,
                  animationController: gpsAnimationController,
                  onGpsTap: onGpsTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GpsButton extends StatelessWidget {
  final bool isGettingLocation;
  final AnimationController animationController;
  final VoidCallback onGpsTap;

  const _GpsButton({
    required this.isGettingLocation,
    required this.animationController,
    required this.onGpsTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isGettingLocation ? null : onGpsTap,
      child: AnimatedContainer(
        duration: AppAnimation.standard,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // Variante apagada del amarillo de marca mientras se obtiene la
          // ubicación, en vez de un amarillo suelto sin relación con
          // `AppColors.primary`.
          color: isGettingLocation
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.textPrimary, width: 2),
          boxShadow: isGettingLocation
              ? const []
              : const [
                  BoxShadow(
                    color: AppColors.textPrimary,
                    blurRadius: 0,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: RotationTransition(
          turns: animationController,
          child: Icon(
            isGettingLocation ? Icons.sync_rounded : Icons.my_location_rounded,
            color: AppColors.textPrimary,
            size: 18,
          ),
        ),
      ),
    );
  }
}
