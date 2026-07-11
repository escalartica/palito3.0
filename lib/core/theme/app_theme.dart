import 'package:flutter/material.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_typography.dart';

class AppTheme {
  static const double borderWidth = 3.0;
  static const double borderRadius = 16.0;
  static const Offset shadowOffset = Offset(4, 4);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        surfaceContainerLow: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      
      // CORRECCIÓN: Usamos CardThemeData en lugar de CardTheme
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.black, width: borderWidth),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
      ),
      
      textTheme: TextTheme(
        headlineLarge: AppTypography.headlineLarge,
        bodyMedium: AppTypography.bodyMedium,
      ),
    );
  }
}

/// Esta clase es la que usarás en tus Widgets para mantener la identidad "sticker"
class AppStyles {
  static BoxDecoration get stickerDecoration => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: Colors.black, width: AppTheme.borderWidth),
    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
    boxShadow: const [
      BoxShadow(
        color: Colors.black,
        offset: AppTheme.shadowOffset,
      ),
    ],
  );
}