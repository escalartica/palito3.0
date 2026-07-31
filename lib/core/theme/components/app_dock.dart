import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dock_provider.dart';

// Paleta de colores neo-brutalista
const Color palitoDark = Color(0xFF1A1A1A);
const Color palitoYellow = Color(0xFFFFD400);

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
Widget build(
BuildContext context,
WidgetRef ref,
) {
final bool isVisible =
ref.watch(dockVisibleProvider);


return AnimatedSlide(
  duration: const Duration(
    milliseconds: 400,
  ),
  curve: Curves.easeOutCubic,
  offset: isVisible
      ? Offset.zero
      : const Offset(
          0,
          1.5,
        ),
  child: Container(
    margin: const EdgeInsets.only(
      left: 24,
      right: 24,
      bottom: 24,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(
        24,
      ),
      border: Border.all(
        color: palitoDark,
        width: 2.5,
      ),
      boxShadow: const [
        BoxShadow(
          color: palitoDark,
          offset: Offset(
            4,
            4,
          ),
          blurRadius: 0,
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 16,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround,
        children: List.generate(
          items.length,
          (index) {
            // El estado visual del Dock depende ÚNICAMENTE
            // de currentIndex.
            //
            // Si currentIndex no coincide con index,
            // el icono nunca se considera seleccionado.
            final bool isSelected =
                currentIndex == index;

            return GestureDetector(
              behavior:
                  HitTestBehavior.opaque,
              onTap: () => onTap(
                index,
              ),
              child: AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 200,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration:
                    BoxDecoration(
                  color: isSelected
                      ? palitoYellow
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color: isSelected
                        ? palitoDark
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  items[index],
                  size: 26,
                  color: palitoDark,
                ),
              ),
            );
          },
        ),
      ),
    ),
  ),
);


}
}
