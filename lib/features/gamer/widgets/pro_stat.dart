import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/tokens/app_colors.dart';

/// Un dato suelto del panel "Cómo va la mesa": icono, número y etiqueta.
///
/// El icono era un emoji dentro del texto de la etiqueta ('👥 Comensales'),
/// que se ve distinto en cada versión de iOS, no hereda el color y el lector
/// de pantalla lee en alto ("cara sonriente", "rayo"). Ahora es un icono de
/// verdad, y el número va antes que la etiqueta porque el número es el dato.
class ProStat extends StatelessWidget {
  const ProStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 17, color: AppColors.textSecondary),
            const SizedBox(height: 5),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
