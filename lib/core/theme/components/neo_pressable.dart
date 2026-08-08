import 'package:flutter/material.dart';

/// Superficie "sticker" neobrutalista: borde grueso + sombra dura sin
/// difuminado que, al pulsar, se desplaza físicamente hasta cubrir la
/// sombra (el "mechanical press" propio del neobrutalismo). Nada de blur:
/// la profundidad la da el desplazamiento, no el difuminado.
class NeoPressable extends StatefulWidget {
  const NeoPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 20,
    this.borderWidth = 2,
    this.borderColor = const Color(0xFF0F172A),
    this.shadowColor = const Color(0xFF0F172A),
    this.shadowOffset = const Offset(4, 4),
    this.color,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final double borderWidth;
  final Color borderColor;
  final Color shadowColor;
  final Offset shadowOffset;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  State<NeoPressable> createState() => _NeoPressableState();
}

class _NeoPressableState extends State<NeoPressable> {
  bool _pressed = false;

  bool get _isInteractive => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (!_isInteractive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final restingOffset = widget.shadowOffset;
    final currentShadowOffset = _pressed ? Offset.zero : restingOffset;
    final translation = _pressed ? restingOffset : Offset.zero;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(translation.dx, translation.dy, 0),
        padding: widget.padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.color ?? Colors.white,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.borderColor,
            width: widget.borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor,
              offset: currentShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
