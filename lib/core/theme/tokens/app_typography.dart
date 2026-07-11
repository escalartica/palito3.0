import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static final TextStyle headlineLarge = GoogleFonts.playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF2C3E50),
  );

  // Nuevo estilo añadido para solucionar el error
  static final TextStyle headlineMedium = GoogleFonts.playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF2C3E50),
  );

  static final TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: const Color(0xFF2C3E50),
  );

  static final TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: const Color(0xFF7F8C8D),
  );

  static final TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF95A5A6),
    letterSpacing: 0.5,
  );
  static final TextStyle titleMedium = GoogleFonts.inter(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: const Color(0xFF2C3E50),
);

static final TextStyle bodyLarge = GoogleFonts.inter(
  fontSize: 16,
  fontWeight: FontWeight.w500,
  color: const Color(0xFF2C3E50),
);
}