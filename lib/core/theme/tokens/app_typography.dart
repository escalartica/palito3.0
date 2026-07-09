import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // Usaremos una fuente tipo "Serif" para títulos (estilo diario gastronómico) 
  // y una "Sans" para legibilidad.
  
  static final TextStyle headlineLarge = GoogleFonts.playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF2C3E50),
  );

  static final TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: const Color(0xFF2C3E50),
  );

  // Añadido: Estilo para textos secundarios pequeños (fechas, etiquetas)
  static final TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: const Color(0xFF7F8C8D), // Un color gris más suave para que no compita
  );

  static final TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF95A5A6),
    letterSpacing: 0.5,
  );
}