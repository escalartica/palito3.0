import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';

// Paleta neo-brutalista (alias locales sobre AppColors, la fuente única de
// verdad — ver core/theme/tokens/app_colors.dart).
const Color palitoDark = AppColors.textPrimary;
const Color palitoYellow = AppColors.primary;

/// Una pestaña del dock. El texto no se pinta —el dock es solo de iconos—
/// pero es imprescindible para VoiceOver/TalkBack: antes la barra de
/// navegación principal de la app era literalmente invisible para un lector
/// de pantalla (tres `GestureDetector` con un `Icon` pelado dentro).
class DockItem {
  const DockItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Barra de navegación flotante.
///
/// Ya no decide ni su posición (el `margin` inferior lo pone quien lo coloca,
/// para que no haya dos márgenes sumándose sin que nadie lo sepa) ni su
/// visibilidad (la decide la pantalla que lo contiene). Solo se dibuja.
class AppDock extends StatelessWidget {
  const AppDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<DockItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Alto real del dock, para que quien lo coloque pueda reservar el hueco
  /// exacto por debajo (el FAB de Inicio y el final de la lista lo usan).
  static const double height = 68;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palitoDark, width: 2.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: palitoDark, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: List<Widget>.generate(items.length, (int index) {
            final DockItem item = items[index];
            final bool isSelected = currentIndex == index;

            return Expanded(
              child: Semantics(
                button: true,
                selected: isSelected,
                label: item.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (!isSelected) HapticFeedback.selectionClick();
                    onTap(index);
                  },
                  child: Center(
                    child: AnimatedContainer(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      // 48x48 mínimo: el área táctil anterior era de 42 px de
                      // alto, por debajo del mínimo de iOS (44) y de Android
                      // (48).
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
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
                            ? const <BoxShadow>[
                                BoxShadow(
                                  color: palitoDark,
                                  offset: Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: ExcludeSemantics(
                        child: Icon(item.icon, size: 24, color: palitoDark),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
