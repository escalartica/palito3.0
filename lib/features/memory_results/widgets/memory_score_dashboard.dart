import 'package:flutter/material.dart';

import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';
import '../../../core/theme/tokens/app_typography.dart';

class MemoryScoreDashboard extends StatelessWidget {
  final Map<String, dynamic> data;

  const MemoryScoreDashboard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _scoreBar("Sabor", data['nota_sabor']?.toDouble() ?? 0.0),
        _scoreBar("Atención", data['nota_atencion']?.toDouble() ?? 0.0),
        _scoreBar("Espacio", data['nota_espacio']?.toDouble() ?? 0.0),
        _scoreBar("Higiene", data['detalle']?.toDouble() ?? 0.0),
      ],
    );
  }

  // Una sola familia de color (coral de marca) para las cuatro barras: cuatro
  // matices sueltos de Material (rojo/naranja/índigo/verde azulado) no
  // pertenecían a la paleta de marca y competían entre sí. La etiqueta ya
  // distingue cada categoría; el color no necesita hacerlo también.
  Widget _scoreBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTypography.labelLarge),
              Text(
                "${value.toStringAsFixed(1)} / 10",
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.accentText,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value / 10,
            backgroundColor: AppColors.accent.withValues(alpha: 0.12),
            color: AppColors.accent,
            minHeight: 8,
            // AppRadius.xs (8) es el paso más pequeño de la escala; por
            // debajo de eso (el `circular(4)` original) el radio deja de
            // leerse como intencional.
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        ],
      ),
    );
  }
}
