import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens/app_colors.dart';

/// Cabecera de sección: icono + título en negrita, usada antes de las
/// cards de "Tu opinión" y "Ubicación" en el detalle de recuerdo.
class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const SectionTitle({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    // El título va en `Expanded`: a 19 puntos en w900, con el texto del
    // sistema ampliado —que es una opción de accesibilidad, no un caso
    // raro—, «Tu opinión» no cabe al lado del icono y la fila se desborda.
    // Dos líneas antes que un recorte: aquí el título es la etiqueta de una
    // sección entera, y media palabra no vale de etiqueta.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
