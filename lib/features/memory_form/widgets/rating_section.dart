import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'form_field_containers.dart';

/// Slider de puntuación general (0-5) del formulario de recuerdo. El
/// diálogo de confirmación al guardar con puntuación 0 sigue viviendo en
/// `_MemoryFormPageState`, ya que solo se dispara al guardar, no al mover
/// el slider.
class RatingSection extends StatelessWidget {
  final double rating;
  final AnimationController ratingAnimationController;
  final ValueChanged<double> onChanged;

  const RatingSection({
    super.key,
    required this.rating,
    required this.ratingAnimationController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel("Puntuación general"),
        const SizedBox(height: 8),
        NeoContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFF0F172A),
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: const Color(0xFFFFD400),
                    overlayColor: const Color(
                      0xFFFFD400,
                    ).withValues(alpha: 0.2),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: rating,
                    // El resto de la app (tarjetas, mapa, MemoryModel)
                    // trata la puntuación en escala 0-5 — con max:10 aquí,
                    // cualquier valor por encima de 5 se recortaba en
                    // silencio al guardar en Firestore, mostrando un
                    // número distinto al que se acababa de elegir.
                    min: 0,
                    max: 5,
                    divisions: 10,
                    onChanged: onChanged,
                  ),
                ),
              ),
              ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                  CurvedAnimation(
                    parent: ratingAnimationController,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD400),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0F172A),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    rating.toStringAsFixed(1),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
