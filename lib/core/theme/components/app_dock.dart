import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dock_provider.dart';

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

    return AnimatedSlide(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      offset: isVisible ? Offset.zero : const Offset(0, 1.5),
      child: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.black, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.white.withValues(alpha: 0.8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  final isSelected = currentIndex == index;

                  return GestureDetector(
                    onTap: () => onTap(index),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        items[index],
                        size: 28,
                        color: isSelected ? Colors.black : Colors.grey.shade600,
                      ),
                    ),
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