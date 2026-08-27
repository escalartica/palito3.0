import 'package:flutter/material.dart';

import 'mode_tab.dart';

const _kDark = Color(0xFF0F172A);
const _kYellow = Color(0xFFFFD400);
const _kRed = Color(0xFFFF4D29);

/// Selector de modo de juego (Ruleta Pro / Juicio Picante) de Zona Gamer.
/// Extraído de gamer_page.dart.
class ModeSelector extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.selectedMode,
    required this.onSelect,
  });
  final int selectedMode;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _kDark, width: 2),
      boxShadow: const [
        BoxShadow(color: _kDark, offset: Offset(3, 3), blurRadius: 0),
      ],
    ),
    child: Row(
      children: [
        ModeTab(
          label: '🎯 Ruleta Pro',
          index: 0,
          selectedMode: selectedMode,
          activeColor: _kYellow,
          onTap: onSelect,
        ),
        ModeTab(
          label: '🔥 Juicio Picante',
          index: 1,
          selectedMode: selectedMode,
          activeColor: _kRed,
          onTap: onSelect,
          activeTextColor: Colors.white,
        ),
      ],
    ),
  );
}
