import 'package:flutter/material.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_typography.dart';

class AppTheme {
  /// Grosor del borde neobrutalista. Los componentes usaban 1.5, 2, 2.5 y 3
  /// según el archivo; estas dos constantes son las únicas admitidas.
  static const double borderWidth = 2.0;
  static const double borderWidthThin = 1.5;
  static const double borderRadius = 16.0;
  static const Offset shadowOffset = Offset(3, 3);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // Los roles `on*` se declaran a mano: si se dejan a Material,
      // `onPrimary` se resuelve a blanco sobre el amarillo de marca (1,43:1),
      // y cualquier componente estándar (ElevatedButton, Chip, Checkbox) sale
      // ilegible. Hoy no se nota porque todas las pantallas pintan sus
      // colores a mano, que es justo el problema de fondo.
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.accent,
        onSecondary: AppColors.onAccent,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerLow: AppColors.background,
        error: AppColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.textPrimary, width: borderWidth),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
      ),

      // Los diálogos y snackbars sí usan los roles del tema, así que aquí sí
      // importa que estén bien.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),

      textTheme: TextTheme(
        headlineLarge: AppTypography.headlineLarge,
        bodyMedium: AppTypography.bodyMedium,
      ),
    );
  }
}

/// Identidad "sticker" reutilizable. Ahora usa los tokens de marca en vez de
/// `Colors.black`, que no es ningún color de esta paleta.
class AppStyles {
  static BoxDecoration get stickerDecoration => BoxDecoration(
    color: AppColors.surface,
    border: Border.all(
      color: AppColors.textPrimary,
      width: AppTheme.borderWidth,
    ),
    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
    boxShadow: const <BoxShadow>[
      BoxShadow(
        color: AppColors.textPrimary,
        offset: AppTheme.shadowOffset,
        blurRadius: 0,
      ),
    ],
  );
}
