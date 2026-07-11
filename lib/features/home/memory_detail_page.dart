import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/tokens/app_typography.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/providers/memory_provider.dart';
import 'memory_form_page.dart';

class MemoryDetailPage extends ConsumerWidget {
  final MemoryModel memory;

  const MemoryDetailPage({super.key, required this.memory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoryProvider);
    final currentMemory = memories.firstWhere(
      (m) => m.id == memory.id,
      orElse: () => memory,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Editar recuerdo',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MemoryFormPage(memory: currentMemory),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: currentMemory.imageUrl != null && currentMemory.imageUrl!.isNotEmpty
                  ? Image.network(currentMemory.imageUrl!, fit: BoxFit.cover)
                  : Container(color: Colors.grey.shade200),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(currentMemory.title, style: AppTypography.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    "En: ${currentMemory.restaurantName}", 
                    style: AppTypography.bodyMedium.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  Text("Tu opinión", style: AppTypography.titleMedium),
                  const SizedBox(height: 8),
                  Text(currentMemory.description, style: AppTypography.bodyLarge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}