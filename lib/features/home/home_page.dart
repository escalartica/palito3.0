import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/categories.dart'; 
import '../../../core/theme/components/home_widgets.dart';
import '../../../core/theme/components/memory_card.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/dock_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    
    // Filtramos la lista según la categoría seleccionada
    final filteredMemories = selectedCategory == "Todos"
        ? memories
        : memories.where((m) => m.category == selectedCategory).toList();

    final featuredMemories = memories.take(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse) {
            ref.read(dockVisibleProvider.notifier).state = false;
          } else if (notification.direction == ScrollDirection.forward) {
            ref.read(dockVisibleProvider.notifier).state = true;
          }
          return true;
        },
        child: ListView(
          children: [
            HomeHero(memory: memories.isNotEmpty ? memories.last : null),
            
            const SectionHeader("Para repetir"),
            SizedBox(
              height: 220,
              child: featuredMemories.isEmpty 
                ? const Padding(
                    padding: EdgeInsets.only(left: 24),
                    child: Center(child: Text("Aún no tienes recuerdos destacados")),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: featuredMemories.length,
                    itemBuilder: (context, index) => MemoryCardLarge(memory: featuredMemories[index]),
                  ),
            ),
            const SectionHeader("Últimos recuerdos"),
            
            // FILTROS (CHIPS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("Todos", selectedCategory, ref),
                    ...gastronomicCategories.map((cat) => _buildFilterChip(cat.name, selectedCategory, ref)),
                  ],
                ),
              ),
            ),

            // LISTA FILTRADA CON BORRADO PROFESIONAL
            ...filteredMemories.map((memory) => Dismissible(
              key: Key(memory.id),
              direction: DismissDirection.endToStart,
              // Añadimos confirmación visual antes de borrar
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Eliminar recuerdo"),
                    content: const Text("¿Seguro que quieres borrar este recuerdo de forma permanente?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
              ),
              onDismissed: (direction) {
                ref.read(memoryProvider.notifier).removeMemory(memory.id);
              },
              child: MemoryCardCompact(memory: memory),
            )),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String selected, WidgetRef ref) {
    final isSelected = label == selected;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => ref.read(selectedCategoryProvider.notifier).state = label,
        selectedColor: const Color(0xFF2C3E50),
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      ),
    );
  }
}