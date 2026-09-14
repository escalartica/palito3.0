import 'package:flutter/material.dart';
import 'logic/memory_result_logic.dart';
import 'widgets/memory_hero_card.dart';
import 'widgets/memory_score_dashboard.dart';
import 'widgets/memory_insights_widget.dart';
import 'widgets/memory_gallery_widget.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> memoryData;

  const ResultScreen({super.key, required this.memoryData});

  @override
  Widget build(BuildContext context) {
    final logic = MemoryResultLogic(memoryData);

    final double globalScore = logic.getAverageScore([
      'nota_espacio',
      'nota_atencion',
    ]);
    final String restaurantName =
        memoryData['nombre_restaurante'] ?? 'Restaurante sin nombre';
    final bool willReturn = memoryData['volverias'] ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text("Tu Recuerdo Palito")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MemoryHeroCard(
              nombreRestaurante: restaurantName,
              score: globalScore,
              volverias: willReturn,
            ),

            const SizedBox(height: 30),
            const Text(
              "Desglose de la experiencia",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            MemoryScoreDashboard(data: memoryData),

            const SizedBox(height: 30),
            MemoryInsightsWidget(data: memoryData),

            // Integración final de la galería
            const SizedBox(height: 30),
            MemoryGalleryWidget(data: memoryData),
            const SizedBox(height: 40), // Espacio final
          ],
        ),
      ),
    );
  }
}
