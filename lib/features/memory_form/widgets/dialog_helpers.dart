import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fila seleccionable del bottom sheet "Seleccionar fotografía" (cámara /
/// galería) abierto por `_MemoryFormPageState._showImageSourceDialog`.
class ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const ImageSourceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD400),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0F172A), width: 2),
        ),
        child: Icon(icon, color: const Color(0xFF0F172A)),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A),
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Botón de acción del diálogo de confirmación "¿Guardar con puntuación
/// 0?" (`_MemoryFormPageState._confirmZeroRating`).
class DialogButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final VoidCallback onTap;

  const DialogButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF0F172A),
              blurRadius: 0,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
