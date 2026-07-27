import 'package:flutter/material.dart';
import '../../../core/data/categories.dart';
import '../../../core/theme/tokens/app_typography.dart';
import '../../../core/theme/tokens/app_radius.dart';
import '../../../core/theme/tokens/app_shadows.dart';


class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;

  const CategoryCard({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [AppShadows.cardShadow],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(category.iconPath, width: 48, height: 48),
            const SizedBox(height: 12),
            Text(category.name, style: AppTypography.bodyMedium),
          ],
        ),
      ),
    );
  }
}