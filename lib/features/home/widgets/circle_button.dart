import 'package:flutter/material.dart';

/// Botón "cristal oscuro": fondo negro semitransparente + icono blanco.
/// Sobre una fotografía el contraste puede variar mucho según la zona de
/// la imagen (cielos claros, mesas oscuras...) — un scrim oscuro con
/// icono blanco es el único par de colores que garantiza legibilidad
/// sobre cualquier foto, a diferencia de un chip blanco/oscuro fijo.
class CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const CircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 1.5),
        ),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
        ),
      ),
    );
  }
}
