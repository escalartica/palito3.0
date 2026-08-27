import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kDark = Color(0xFF0F172A);

/// Pequeña píldora de texto usada para mostrar medallas/puntos de un
/// comensal en el modal de insignias. Extraído de gamer_page.dart.
class BadgePill extends StatelessWidget {
  const BadgePill({
    super.key,
    required this.text,
    required this.bgColor,
    this.textColor,
  });
  final String text;
  final Color bgColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: textColor ?? _kDark,
      ),
    ),
  );
}
