import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/data/categories.dart';
import '../../../../../core/providers/memory_provider.dart';
import '../../../../../core/theme/tokens/app_spacing.dart';
import '../../../../../core/theme/tokens/app_typography.dart';
import '../../../../../core/theme/components/memory_card.dart';


class CategoryListPage extends ConsumerWidget {
  final Category category;

  const CategoryListPage({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filtramos las memorias según la categoría actual
    final memories = ref.watch(memoryProvider).where((m) => m.category == category.name).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: Text(category.name, style: AppTypography.headlineMedium),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2C3E50)),
      ),
      body: Column(
        children: [
          Container(
            height: 150,
            margin: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: const Center(child: Text("Mapa de experiencias")),
          ),
          
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: memories.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              // CORRECCIÓN: Pasamos el objeto 'memory' requerido por el constructor
              itemBuilder: (context, index) => MemoryCardCompact(
                memory: memories[index],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/new-memory', extra: category),
        backgroundColor: const Color(0xFF2C3E50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}