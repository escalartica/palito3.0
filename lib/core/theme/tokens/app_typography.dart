import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Solo `headlineLarge` y `bodyMedium` llegan a usarse de verdad (en
/// `AppTheme.lightTheme`); el resto de estilos no está referenciado en
/// ningún sitio porque cada pantalla define su propio `TextStyle` con
/// `GoogleFonts.outfit`/`.inter` directamente en vez de heredar del tema
/// — se mantienen igualmente alineados con la marca real (antes usaban
/// Playfair Display y un navy ligeramente distinto, `#2C3E50`, que no es
/// el que la app usa en ningún otro sitio) para que si algún día se
/// referencian no contradigan al resto de la interfaz.
class AppTypography {
  static final TextStyle headlineLarge = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle headlineMedium = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static final TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static final TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static final TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  static final TextStyle titleMedium = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static final TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}
