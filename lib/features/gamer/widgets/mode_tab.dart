import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kDark = Color(0xFF0F172A);

/// Pestaña individual dentro de [ModeSelector] (p.ej. "Ruleta Pro" o
/// "Juicio Picante"). Extraído de gamer_page.dart.
class ModeTab extends StatelessWidget {
  const ModeTab({
    super.key,
    required this.label,
    required this.index,
    required this.selectedMode,
    required this.activeColor,
    required this.onTap,
    this.activeTextColor,
  });
  final String label;
  final int index, selectedMode;
  final Color activeColor;
  final Color? activeTextColor;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedMode == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: isSelected ? Border.all(color: _kDark, width: 2) : null,
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: _kDark,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected
                    ? (activeTextColor ?? _kDark)
                    : Colors.grey.shade500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
