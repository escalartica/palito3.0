import 'package:flutter/material.dart';

/// Contenedor cuadrado con icono y borde grueso — el pequeño "sello"
/// visual que acompaña la cabecera de cada card de sección (puntuación,
/// lugar, variedades, ubicación...) en el detalle de recuerdo.
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;

  const IconBox({
    super.key,
    required this.icon,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF0F172A), width: 2),
      ),
      child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
    );
  }
}
