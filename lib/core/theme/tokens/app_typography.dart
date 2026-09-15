import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Escala tipográfica de la marca.
///
/// Dos familias, con un reparto de trabajo fijo:
///   • **Outfit** (geométrica, con carácter) para todo lo que titula.
///   • **Inter**  (neutra, pensada para pantalla) para todo lo que se lee.
///
/// Antes solo `headlineLarge` y `bodyMedium` llegaban al `ThemeData`, así que
/// todo lo que pinta Material por su cuenta —diálogos, menús, `SnackBar`,
/// `DatePicker`, los textos de error de los formularios— salía en Roboto,
/// la fuente por defecto del sistema, en medio de una app hecha con Outfit e
/// Inter. Es de esos detalles que nadie sabe nombrar pero que hacen que una
/// app "no parezca acabada". Ahora la escala está completa y el tema la
/// aplica entera.
///
/// Los tamaños siguen una progresión de 4 en 4 (32/28/24/20/18/16/14/12/11)
/// en vez de los valores sueltos que había repartidos por las pantallas.
class AppTypography {
  // ─── Display / Headline: Outfit ──────────────────────────────────────
  static final TextStyle displayLarge = GoogleFonts.outfit(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.8,
    color: AppColors.textPrimary,
  );

  static final TextStyle headlineLarge = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.15,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
  );

  static final TextStyle headlineMedium = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  static final TextStyle headlineSmall = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  // ─── Títulos de sección: Outfit ──────────────────────────────────────
  static final TextStyle titleLarge = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static final TextStyle titleMedium = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static final TextStyle titleSmall = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  // ─── Cuerpo: Inter ───────────────────────────────────────────────────
  static final TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static final TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static final TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  // ─── Etiquetas y botones: Inter ──────────────────────────────────────
  static final TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static final TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
    color: AppColors.textSecondary,
  );

  /// Mayúsculas pequeñas de sección ("TUS GRUPOS", "ESTA SEMANA").
  /// 11 px es el mínimo legible con `letterSpacing` alto; por debajo, el
  /// espaciado hace más daño que bien.
  static final TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );

  /// Cifras de ancho fijo.
  ///
  /// Por defecto, Outfit e Inter dibujan cada dígito con su propio ancho: el
  /// 1 es estrecho, el 8 es ancho. Eso está bien en una frase y es un
  /// desastre en un número que cambia solo. Las cinco estadísticas del
  /// Perfil cuentan desde cero al abrir la pantalla, y la nota del
  /// formulario cambia mientras se arrastra el deslizador: en ambos casos el
  /// número entero se desplaza a izquierda y derecha en cada fotograma,
  /// como si temblara.
  ///
  /// `tabularFigures` le da a todos los dígitos el mismo ancho. El número se
  /// queda quieto y solo cambian las cifras. Es de esas cosas que nadie sabe
  /// nombrar y que separan una app de otra.
  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Escala completa lista para `ThemeData.textTheme`.
  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: headlineLarge,
    displaySmall: headlineMedium,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
