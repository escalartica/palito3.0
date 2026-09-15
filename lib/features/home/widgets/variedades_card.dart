import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'animated_card.dart';
import 'icon_box.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

/// Card de "sabores del surtido" (croquetas variadas): cada sabor con su
/// propia valoración, en vez del volcado genérico de specificFields que
/// quedaría como un Map.toString() feo.
class VariedadesCard extends StatelessWidget {
  final List<Map<String, dynamic>> variedades;

  const VariedadesCard({super.key, required this.variedades});

  @override
  Widget build(BuildContext context) {
    return AnimatedCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(
                icon: Icons.dining_outlined,
                backgroundColor: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SABORES DEL SURTIDO',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(variedades.length, (index) {
            final variedad = variedades[index];
            final String sabor = variedad['sabor']?.toString() ?? '';
            final String valoracion = variedad['valoracion']?.toString() ?? '';

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == variedades.length - 1 ? 0 : 10,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sabor,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _colorForValoracion(valoracion),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text(
                        valoracion,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Color aproximado según la valoración de un sabor del surtido, para dar
  // un vistazo rápido de qué variedades funcionaron y cuáles no sin tener
  // que leer cada etiqueta.
  Color _colorForValoracion(String valoracion) {
    const positivas = {'Buenas', 'Muy buenas', 'Emocionantes', 'Religiosas'};
    const negativas = {'Mediocres', 'Basura'};

    if (positivas.contains(valoracion)) {
      return AppColors.success.withValues(alpha: 0.18);
    }

    if (negativas.contains(valoracion)) {
      return AppColors.accent.withValues(alpha: 0.21);
    }

    return AppColors.textPrimary.withValues(alpha: 0.06);
  }
}
