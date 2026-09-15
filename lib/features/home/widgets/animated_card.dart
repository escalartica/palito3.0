import 'package:flutter/material.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

/// Card blanca con borde grueso y sombra "dura" — el contenedor base
/// reutilizado por casi todas las secciones del detalle de recuerdo
/// (lugar, puntuación, variedades, opinión, ubicación...).
class AnimatedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AnimatedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.textPrimary, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.textPrimary,
            blurRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
