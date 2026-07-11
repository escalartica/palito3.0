import 'package:flutter/material.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/theme/tokens/app_typography.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shadows.dart';


class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                "Explora",
                style: AppTypography.headlineLarge,
                textAlign: TextAlign.center,
              ),
            ),
            // Placeholder hasta definir el nuevo componente de navegación de categorías
            Expanded(
              child: Center(
                child: Text(
                  "Sección en construcción",
                  style: AppTypography.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}