import 'package:flutter/material.dart';

import 'mode_tab.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

const _kDark = AppColors.textPrimary;
const _kYellow = AppColors.primary;
const _kRed = AppColors.accent;

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
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: Border.all(color: _kDark, width: 2),
      boxShadow: const [
        BoxShadow(color: _kDark, offset: Offset(3, 3), blurRadius: 0),
      ],
    ),
    child: Row(
      children: [
        ModeTab(
          label: 'Ruleta',
          index: 0,
          selectedMode: selectedMode,
          activeColor: _kYellow,
          onTap: onSelect,
        ),
        ModeTab(
          label: 'Juicio picante',
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
