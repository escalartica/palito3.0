import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// ===========================================================================
/// EL SUBRAYADO DE ROTULADOR
/// ===========================================================================
///
/// Un trazo de marcador por detrás de una palabra. No un rectángulo: un
/// trazo, con los bordes desiguales, los extremos redondeados y una
/// inclinación de medio grado.
///
/// POR QUÉ NO UN RECTÁNGULO. Un rectángulo de color detrás de un texto es un
/// `Chip`, y el cerebro lo lee como interfaz: una etiqueta, un estado, algo
/// del sistema. Un trazo con el borde superior ligeramente distinto del
/// inferior lo lee como lo que es — alguien ha pasado un rotulador por
/// encima para señalar esto. Y señalar a mano es un gesto humano, no una
/// función de una app.
///
/// DÓNDE SE USA Y DÓNDE NO. En una cosa por pantalla, como mucho. El
/// rotulador funciona porque dice "esto de aquí". Si hay tres, no dice nada.
/// ===========================================================================
class MarkerHighlight extends StatelessWidget {
  const MarkerHighlight({
    super.key,
    required this.child,
    this.color = AppColors.primary,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
  });

  final Widget child;

  /// El amarillo de marca por defecto, que es el que se comporta como un
  /// rotulador de verdad: deja leer el texto oscuro que hay encima.
  final Color color;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MarkerPainter(color: color),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    // El trazo no llega arriba del todo ni baja hasta el fondo: un rotulador
    // pasa por el cuerpo de las letras, no por la caja entera.
    final double top = size.height * 0.28;
    final double bottom = size.height * 0.96;

    // Medio grado de inclinación. Suficiente para que no parezca alineado a
    // regla, poco para que no parezca torcido por error.
    final double tilt = size.height * 0.035;

    final Path path = Path()
      ..moveTo(0, top + tilt)
      // Borde superior: una curva muy suave, no una recta.
      ..quadraticBezierTo(size.width * 0.5, top - tilt * 0.6, size.width, top)
      ..lineTo(size.width, bottom - tilt)
      // Borde inferior, con la curva al revés para que los dos bordes no
      // sean paralelos — es ahí donde se pierde el aspecto de rectángulo.
      ..quadraticBezierTo(
        size.width * 0.5,
        bottom + tilt * 0.8,
        0,
        bottom + tilt * 0.3,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MarkerPainter old) => old.color != color;
}
