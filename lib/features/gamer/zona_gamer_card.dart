import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/theme/tokens/app_animation.dart';

class ZonaGamerCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final VoidCallback onTap;

  const ZonaGamerCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  State<ZonaGamerCard> createState() => _ZonaGamerCardState();
}

class _ZonaGamerCardState extends State<ZonaGamerCard> {
  static const Offset _restOffset = Offset(4, 4);
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final currentShadowOffset = _pressed ? Offset.zero : _restOffset;
    final translation = _pressed ? _restOffset : Offset.zero;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: AppAnimation.press,
        curve: AppAnimation.enter,
        transform: Matrix4.translationValues(translation.dx, translation.dy, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          // Color plano. El degradado era el único de esta pantalla y no
          // encaja con un lenguaje de bordes duros y sombras macizas: lo que
          // da profundidad aquí es el desplazamiento, no el difuminado.
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.textPrimary, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary,
              offset: currentShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _pressed ? 0.85 : 1),
                  duration: AppAnimation.press,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            AnimatedSlide(
              duration: AppAnimation.fast,
              curve: AppAnimation.enter,
              offset: _pressed ? const Offset(0.15, 0) : Offset.zero,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
