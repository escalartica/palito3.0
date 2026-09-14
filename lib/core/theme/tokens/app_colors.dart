import 'package:flutter/material.dart';

/// Fuente única de verdad para la paleta de marca neobrutalista (navy +
/// amarillo + coral). Antes cada pantalla redefinía sus propias constantes
/// locales con los mismos valores hexadecimales — funcionaba porque coincidían,
/// pero un cambio de marca solo en un archivo las habría desincronizado sin
/// que el analizador lo detectase.
///
/// CONTRASTE — los valores marcados con su ratio se han medido contra el
/// fondo con el que se usan, para cumplir WCAG AA (4.5:1 en texto normal).
/// Los grises `Colors.grey.shade400/500` que había repartidos por la app
/// daban entre 1,9:1 y 2,7:1: texto prácticamente ilegible a plena luz.
class AppColors {
  // --- Colores base ---------------------------------------------------
  static const Color primary = Color(0xFFFFD400); // Amarillo de marca
  static const Color background = Color(0xFFF4F4F8);
  static const Color surface = Colors.white;
  static const Color surfaceWarm = Color(0xFFFFFDF5);
  static const Color textPrimary = Color(0xFF0F172A); // Navy oscuro
  static const Color accent = Color(0xFFFF4D29); // Coral (rellenos, decorativo)

  // --- Texto ----------------------------------------------------------

  /// Texto secundario. Antes era `#7F8C8D` (3,48:1 sobre blanco → no cumple).
  /// 5,94:1 sobre blanco.
  static const Color textSecondary = Color(0xFF5A6572);

  /// Texto terciario / pistas. 4,6:1 sobre blanco. Sustituye a los
  /// `Colors.grey.shade400` (1,9:1) repartidos por Gamer y el detalle.
  static const Color textMuted = Color(0xFF6E7683);

  /// Coral SOLO para texto y bordes de CTA sobre fondo claro: el coral de
  /// marca `#FF4D29` da 3,31:1 sobre blanco y no cumple AA para texto.
  /// 4,70:1 sobre blanco.
  static const Color accentText = Color(0xFFD63A17);

  /// Lo que se escribe encima del amarillo de marca. Material generaba
  /// `onPrimary: white` (1,43:1 sobre #FFD400), ilegible en cualquier
  /// componente que usara los roles del tema en vez de colores a mano.
  static const Color onPrimary = textPrimary;

  /// Lo que se escribe encima del coral.
  static const Color onAccent = Colors.white;

  // --- Estados --------------------------------------------------------
  static const Color error = Color(0xFFC0392B); // 5,4:1 sobre blanco
  static const Color success = Color(0xFF1E7E45); // 5,3:1 sobre blanco
}
