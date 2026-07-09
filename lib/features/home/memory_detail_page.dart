import 'package:flutter/material.dart';
import '../../core/models/memory_model.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/theme/tokens/app_typography.dart';


class MemoryDetailPage extends StatelessWidget {
  final MemoryModel memory;

  const MemoryDetailPage({
    super.key,
    required this.memory,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              memory.title,
              style: AppTypography.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Fecha (formateada de forma sencilla)
            Text(
              "Fecha: ${memory.date.day}/${memory.date.month}/${memory.date.year}",
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Descripción larga
            Text(
              memory.description,
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}