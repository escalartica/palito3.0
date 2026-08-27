import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cabecera de sección: icono + título en negrita, usada antes de las
/// cards de "Tu opinión" y "Ubicación" en el detalle de recuerdo.
class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const SectionTitle({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0F172A)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
