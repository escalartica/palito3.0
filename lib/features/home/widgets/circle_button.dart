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
          // 48x48 REALES.
          //
          // Eran 9 de relleno más un icono de 17: **35x35** de zona
          // pulsable, por debajo del mínimo de 44 de Apple. Lo sufre sobre
          // todo el botón de cerrar del visor a pantalla completa: si fallas
          // el toque, en vez de salir haces zoom en la foto.
          //
          // El círculo se ve igual de grande que antes; lo que crece es el
          // área que responde, que es invisible y es la que importa.
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
      ),
    );
  }
}
