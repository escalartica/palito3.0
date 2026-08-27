import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kDark = Color(0xFF0F172A);

/// Estadística compacta (etiqueta + valor) mostrada en el panel Pro de
/// Zona Gamer. Extraído de gamer_page.dart.
class ProStat extends StatelessWidget {
  const ProStat({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label, value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: valueColor ?? _kDark,
        ),
      ),
    ],
  );
}
