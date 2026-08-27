import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'animated_card.dart';
import 'icon_box.dart';

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
                backgroundColor: Color(0xFFFFD400),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SABORES DEL SURTIDO',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
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
            final String valoracion =
                variedad['valoracion']?.toString() ?? '';

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
                  color: const Color(0xFFFFFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.12),
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
                          color: const Color(0xFF0F172A),
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
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        valoracion,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
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
    const positivas = {
      'Buenas',
      'Muy buenas',
      'Emocionantes',
      'Religiosas',
    };
    const negativas = {'Mediocres', 'Basura'};

    if (positivas.contains(valoracion)) {
      return const Color(0xFFD4F4DD);
    }

    if (negativas.contains(valoracion)) {
      return const Color(0xFFFFD9D2);
    }

    return const Color(0xFFF0F0F0);
  }
}
