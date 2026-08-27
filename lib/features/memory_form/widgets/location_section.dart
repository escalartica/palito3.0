import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'form_field_containers.dart';

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
                    color: const Color(0xFF0F172A),
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
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isGettingLocation
              ? const Color(0xFFFFE77A)
              : const Color(0xFFFFD400),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF0F172A), width: 2),
          boxShadow: isGettingLocation
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: RotationTransition(
          turns: animationController,
          child: Icon(
            isGettingLocation ? Icons.sync_rounded : Icons.my_location_rounded,
            color: const Color(0xFF0F172A),
            size: 18,
          ),
        ),
      ),
    );
  }
}
