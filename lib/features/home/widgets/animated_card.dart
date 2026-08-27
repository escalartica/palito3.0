import 'package:flutter/material.dart';

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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF0F172A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0F172A),
            blurRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
