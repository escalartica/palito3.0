import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dock_provider.dart';
import '../tokens/app_colors.dart';

// Paleta de colores neo-brutalista (alias locales sobre AppColors, la
// fuente única de verdad — ver core/theme/tokens/app_colors.dart).
const Color palitoDark = AppColors.textPrimary;
const Color palitoYellow = AppColors.primary;

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
    final bool isVisible = ref.watch(dockVisibleProvider);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      offset: isVisible ? Offset.zero : const Offset(0, 1.5),
      child: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palitoDark, width: 2.5),
          boxShadow: const [
            BoxShadow(color: palitoDark, offset: Offset(4, 4), blurRadius: 0),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              // El estado visual del Dock depende ÚNICAMENTE
              // de currentIndex.
              //
              // Si currentIndex no coincide con index,
              // el icono nunca se considera seleccionado.
              final bool isSelected = currentIndex == index;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!isSelected) HapticFeedback.selectionClick();
                  onTap(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? palitoYellow : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? palitoDark : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: palitoDark,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: isSelected ? 1 : 0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) => Transform.scale(
                      scale: 1 + (value * 0.18),
                      child: child,
                    ),
                    child: Icon(items[index], size: 26, color: palitoDark),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
