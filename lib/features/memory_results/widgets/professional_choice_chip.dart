import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfessionalChoiceChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const ProfessionalChoiceChip({
    super.key,
    required this.label,
    this.icon, // El icono ahora es opcional y profesional
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD400) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          // Borde más grueso si está seleccionado
          border: Border.all(
            color: const Color(0xFF0F172A),
            width: isSelected ? 2.0 : 1.0,
          ),
          // Sombra dura estilo neobrutalista solo al seleccionar
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: const Color(0xFF0F172A)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF0F172A),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
