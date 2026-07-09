import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dock_provider.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_shadows.dart';

class AppDock extends ConsumerWidget {
  final List<IconData> items;
  final int currentIndex;
  final Function(int) onTap;

  const AppDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(dockVisibleProvider);

    // 1. Positioned es hijo directo del Stack en main.dart
    return Positioned(
      bottom: 30,
      left: 30,
      right: 30,
      // 2. La animación envuelve el contenido que vive DENTRO de esa posición
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                boxShadow: [AppShadows.cardShadow],
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  return IconButton(
                    icon: Icon(
                      items[index],
                      color: currentIndex == index ? AppColors.primary : AppColors.textSecondary,
                    ),
                    onPressed: () => onTap(index),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}