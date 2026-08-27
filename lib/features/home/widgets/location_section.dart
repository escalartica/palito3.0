import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/memory_model.dart';
import 'animated_card.dart';
import 'icon_box.dart';
import 'section_title.dart';

/// Sección de ubicación del recuerdo: dirección y, si están disponibles,
/// las coordenadas exactas.
class LocationSection extends StatelessWidget {
  final MemoryModel memory;

  const LocationSection({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    final hasCoordinates =
        memory.location.lat != null && memory.location.lng != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          icon: Icons.location_on_rounded,
          title: 'Ubicación',
        ),

        const SizedBox(height: 12),

        AnimatedCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBox(
                    icon: Icons.location_on_rounded,
                    backgroundColor: Color(0xFFFFD400),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      memory.location.address,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),

              if (hasCoordinates) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        size: 16,
                        color: Color(0xFF0F172A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${memory.location.lat!.toStringAsFixed(5)}, '
                          '${memory.location.lng!.toStringAsFixed(5)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
