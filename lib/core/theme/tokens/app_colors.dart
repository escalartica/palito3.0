import 'package:flutter/material.dart';

/// Fuente única de verdad para la paleta de marca neobrutalista (navy +
/// amarillo + coral). Antes cada pantalla redefinía sus propias constantes
/// locales con los mismos valores hexadecimales ("palitoDark"/"palitoYellow"
/// en app_dock.dart, home_widgets.dart y memory_card.dart; "colorTextMain"
/// con el mismo valor en home_page.dart) — funcionaba porque coincidían,
/// pero un cambio de marca solo en un archivo las habría desincronizado
/// sin que el analizador lo detectase.
class AppColors {
  // Colores base (paleta de marca real, neobrutalista)
  static const Color primary = Color(0xFFFFD400); // Amarillo de marca
  static const Color background = Color(0xFFF4F4F8);
  static const Color surface = Colors.white;
  static const Color surfaceWarm = Color(0xFFFFFDF5);
  static const Color textPrimary = Color(0xFF0F172A); // Navy oscuro
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color accent = Color(0xFFFF4D29); // Coral (acciones/CTA)

  // Colores para estados
  static const Color error = Color(0xFFE74C3C);
  static const Color success = Color(0xFF27AE60);
}