import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Importa tus providers desde la ruta correcta
import '../../core/providers/memory_provider.dart'; 
// Importa tus categorías desde la ruta correcta
import '../../core/data/categories.dart'; 

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    final filteredMemories = selectedCategory == "Todos"
        ? memories
        : memories.where((m) => m.category == selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Tus Recuerdos")),
      body: Column(
        children: [
          _buildCategoryFilter(ref, selectedCategory),
          Expanded(
            child: filteredMemories.isEmpty
                ? const Center(child: Text("No hay recuerdos en esta categoría"))
                : ListView.builder(
                    itemCount: filteredMemories.length,
                    itemBuilder: (context, index) {
                      final memory = filteredMemories[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(memory.restaurantName),
                          subtitle: Text("${memory.category} • ${memory.rating.toStringAsFixed(1)}/10"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // Aquí irá la navegación al detalle próximamente
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(WidgetRef ref, String selectedCategory) {
    final categories = ["Todos", ...gastronomicCategories.map((c) => c.name)];
    
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) => ref.read(selectedCategoryProvider.notifier).state = category,
            ),
          );
        },
      ),
    );
  }
}