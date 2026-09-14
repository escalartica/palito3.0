import 'package:flutter/material.dart';

class MemoryScoreDashboard extends StatelessWidget {
  final Map<String, dynamic> data;

  const MemoryScoreDashboard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _scoreBar(
          "Sabor",
          data['nota_sabor']?.toDouble() ?? 0.0,
          Colors.redAccent,
        ),
        _scoreBar(
          "Atención",
          data['nota_atencion']?.toDouble() ?? 0.0,
          Colors.orange,
        ),
        _scoreBar(
          "Espacio",
          data['nota_espacio']?.toDouble() ?? 0.0,
          Colors.indigoAccent,
        ),
        _scoreBar("Higiene", data['detalle']?.toDouble() ?? 0.0, Colors.teal),
      ],
    );
  }

  Widget _scoreBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                "${value.toStringAsFixed(1)} / 10",
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value / 10,
            backgroundColor: color.withValues(alpha: 0.1),
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
