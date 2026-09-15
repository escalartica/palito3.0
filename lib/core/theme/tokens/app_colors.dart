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
  /// El lienzo de la app. Un solo blanco cálido.
  ///
  /// Había TRES fondos casi iguales conviviendo: `#F4F4F8` (gris frío) como
  /// valor del tema, `#FDFBF7` en Inicio y el formulario, y `#FFFDF5` en
  /// Perfil. Ninguna pantalla usaba el del tema, y el salto de tono entre
  /// Inicio y Perfil se veía al cambiar de pestaña. Ahora es uno.
  static const Color background = Color(0xFFFDFBF7);
  static const Color surface = Colors.white;
  static const Color surfaceWarm = Color(0xFFFFFDF5);
  static const Color textPrimary = Color(0xFF0F172A); // Navy oscuro

  // ─────────────────────────────────────────────────────── TINTES OPACOS ──
  //
  // POR QUÉ SON OPACOS Y NO `color.withValues(alpha: 0.12)`.
  //
  // Una `BoxDecoration` pinta primero la SOMBRA y después el fondo. Con el
  // lenguaje de esta app —sombras macizas, `blurRadius: 0`, desplazadas unos
  // pocos píxeles— esa sombra es un rectángulo navy del tamaño de la caja.
  // Si el fondo que va encima lleva alpha, la sombra **se ve a través**.
  //
  // Al 12 % de alpha pasa el 88 % del navy. La tarjeta de "RECOMENDACIÓN"
  // del detalle tenía que ser verde pálido y salía casi negra: el texto
  // navy encima medía **1,11:1** cuando debía medir 14,73:1. En la pastilla
  // de "sin nota" era todavía peor, **1,00:1** — fondo y texto exactamente
  // del mismo color, texto invisible.
  //
  // Se ve como "zonas oscuras donde no se lee lo que pone", que es justo
  // como lo describió quien lo sufrió.
  //
  // La solución no es subir el alpha: es no tener alpha. Cada tinte de aquí
  // es el color ya mezclado con la superficie sobre la que se usa.

  /// Verde de acierto al 12 % sobre el fondo crema. Navy encima: 14,73:1.
  static const Color tintSuccess = Color(0xFFE2ECE2);

  /// Navy al 10 % sobre blanco, para estados apagados. Navy encima: 14,56:1.
  static const Color tintMuted = Color(0xFFE7E8EA);

  /// Amarillo de marca al 15 % sobre blanco. Navy encima: 16,84:1.
  static const Color tintPrimary = Color(0xFFFFF9D9);

  /// Rojo de error al 12 % sobre blanco, para avisos y acciones destructivas.
  /// El rojo de error encima mide 4,54:1; el navy, 14,90:1.
  static const Color tintError = Color(0xFFF7E7E6);

  /// Coral al 30 % sobre blanco, para el "No" del formulario. El botón usaba
  /// `accent.withValues(alpha: 0.3)` y al marcarlo salía granate oscuro con
  /// el texto navy encima: **1,47:1**, ilegible. Opaco mide 12,29:1.
  static const Color tintAccent = Color(0xFFFFCABF);
  static const Color accent = Color(0xFFFF4D29); // Coral (rellenos, decorativo)

  // --- Texto ----------------------------------------------------------

  /// Texto secundario. Antes era `#7F8C8D` (3,48:1 sobre blanco → no cumple).
  /// 5,94:1 sobre blanco.
  static const Color textSecondary = Color(0xFF5A6572);

  /// Texto terciario / pistas. 4,6:1 sobre blanco. Sustituye a los
  /// `Colors.grey.shade400` (1,9:1) repartidos por Gamer y el detalle.
  static const Color textMuted = Color(0xFF6E7683);

  /// Gris secundario para texto sobre el amarillo de marca. [textSecondary]
  /// mide 5,93:1 sobre blanco pero solo 4,14:1 sobre `primary`: el mismo
  /// token pasa o no pasa según dónde caiga. Este mide 5,10:1 sobre amarillo
  /// y 7,30:1 sobre blanco.
  static const Color textSecondaryOnPrimary = Color(0xFF4E5765);

  /// Coral SOLO para texto y bordes de CTA sobre fondo claro: el coral de
  /// marca `#FF4D29` da 3,31:1 sobre blanco y no cumple AA para texto.
  /// 4,70:1 sobre blanco.
  static const Color accentText = Color(0xFFD63A17);

  /// Lo que se escribe encima del amarillo de marca. Material generaba
  /// `onPrimary: white` (1,43:1 sobre #FFD400), ilegible en cualquier
  /// componente que usara los roles del tema en vez de colores a mano.
  static const Color onPrimary = textPrimary;

  /// Lo que se escribe encima del coral.
  ///
  /// Navy, no blanco. Blanco sobre el coral de marca `#FF4D29` mide **3,32:1**
  /// y el mínimo de WCAG AA para texto es 4,5:1 — es decir, el rótulo del
  /// botón principal de "Crear grupo" y "Entrar con un código" no cumplía.
  /// El navy sobre ese mismo coral mide **5,12:1**, y además es lo que hace
  /// la app en todas partes: texto oscuro sobre color, nunca al revés.
  ///
  /// Para ICONOS sobre coral el blanco sí vale (los elementos gráficos solo
  /// necesitan 3:1), y por eso el botón flotante redondo lo conserva.
  static const Color onAccent = textPrimary;

  // --- Estados --------------------------------------------------------
  static const Color error = Color(0xFFC0392B); // 5,4:1 sobre blanco
  static const Color success = Color(0xFF1E7E45); // 5,3:1 sobre blanco
}
