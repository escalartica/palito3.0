import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/categories.dart'; 
import '../../../core/theme/components/home_widgets.dart';
import '../../../core/theme/components/memory_card.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/dock_provider.dart';

// Paleta de colores
const Color palitoYellow = Color(0xFFFFD400); 
const Color palitoPink = Color(0xFFE91E63);   
const Color palitoDark = Color(0xFF1A1A1A);   

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    
    final filteredMemories = selectedCategory == "Todos"
        ? memories
        : memories.where((m) => m.category == selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: Stack(
        children: [
          NotificationListener<UserScrollNotification>(
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
                // Hero ocupa el 70% de pantalla
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: HomeHero(memory: filteredMemories.isNotEmpty ? filteredMemories.last : null),
                ),
                
                _buildSectionHeader("Últimos recuerdos"),
                
                SizedBox(
                  height: 60,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip("Todos", selectedCategory, ref),
                        ...gastronomicCategories.map((cat) => _buildFilterChip(cat.name, selectedCategory, ref)),
                      ],
                    ),
                  ),
                ),

                filteredMemories.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: Text("Aún no tienes recuerdos aquí")),
                      )
                    : Column(
                        children: filteredMemories.reversed.map((memory) => Dismissible(
                          key: Key(memory.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => ref.read(memoryProvider.notifier).removeMemory(memory.id),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(color: palitoPink.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
                          ),
                          child: MemoryCardCompact(memory: memory),
                        )).toList(),
                      ),
                const SizedBox(height: 120),
              ],
            ),
          ),
          
          // Nuevo botón de acción flotante (FAB) profesional con sombra dura
          Positioned(
            bottom: 120,
            right: 24,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: palitoDark,
                    offset: Offset(4, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                backgroundColor: palitoYellow,
                elevation: 0,
                onPressed: () => context.push('/new-memory'),
                shape: const CircleBorder(side: BorderSide(color: palitoDark, width: 2.5)),
                child: const Icon(Icons.add, color: palitoDark, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 24, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: palitoDark, letterSpacing: -0.5),
      ),
    );
  }

  Widget _buildFilterChip(String label, String selected, WidgetRef ref) {
    final isSelected = label == selected;
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 4),
      child: GestureDetector(
        onTap: () => ref.read(selectedCategoryProvider.notifier).state = label,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? palitoPink : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palitoDark, width: 2.5),
            boxShadow: [BoxShadow(color: palitoDark.withOpacity(0.2), offset: const Offset(4, 4))],
          ),
          child: Text(
            label,
            style: TextStyle(color: isSelected ? Colors.white : palitoDark, fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}