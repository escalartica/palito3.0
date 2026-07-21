import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/data/categories.dart'; 
import '../../../core/theme/components/home_widgets.dart';
import '../../../core/theme/components/memory_card.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/dock_provider.dart';

// Paleta de colores UI/UX de Alta Gama (Estándar iOS Líder)
const Color colorBackground = Color(0xFFF4F4F8);
const Color colorCardSurface = Colors.white;
const Color colorTextMain = Color(0xFF0F172A);
const Color colorAccentCoral = Color(0xFFFF4D29); // Naranja brasa vivo selecto

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Animación de Fade In elegante para el aterrizaje de la pantalla
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    
    final filteredMemories = selectedCategory == "Todos"
        ? memories
        : memories.where((m) => m.category == selectedCategory).toList();

    return Scaffold(
      backgroundColor: colorBackground,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // 1. Contenido principal con scroll fluido y un margen inferior holgado (300px)
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
                padding: EdgeInsets.zero,
                children: [
                  // Cabecera superior rediseñada con mayor protagonismo para el logotipo y sin textos vacíos
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Palito de Sabores",
                                  style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: colorTextMain,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Logotipo de mayor formato con contenedor flotante armónico y sombra elegante
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: colorCardSurface,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tarjeta Héroe Principal con proporción equilibrada y moderna
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.34,
                      child: HomeHero(memory: filteredMemories.isNotEmpty ? filteredMemories.last : null),
                    ),
                  ),
                  
                  // Cabecera de sección estilizada y cercana
                  _buildSectionHeader("Últimos Registros"),
                  
                  // Filtros de categoría horizontales (Píldoras compactas)
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildFilterChip("Todos", selectedCategory, ref),
                        ...gastronomicCategories.map((cat) => _buildFilterChip(cat.name, selectedCategory, ref)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Listado de recuerdos con diseño cohesionado y limpio
                  filteredMemories.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          child: Center(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: colorCardSurface,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.restaurant_menu_rounded, size: 32, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text(
                                    "No hay experiencias guardadas aquí",
                                    style: GoogleFonts.outfit(
                                      color: colorTextMain,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: filteredMemories.reversed.map((memory) => Dismissible(
                              key: Key(memory.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => ref.read(memoryProvider.notifier).removeMemory(memory.id),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400, 
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: MemoryCardCompact(memory: memory),
                              ),
                            )).toList(),
                          ),
                        ),
                  
                  // Margen de seguridad inferior definitivo de 300px para separación total
                  const SizedBox(height: 300),
                ],
              ),
            ),
            
            // 2. Botón de Acción Flotante (FAB) posicionado a 125px para evitar cualquier solapamiento
            Positioned(
              bottom: 125,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorAccentCoral.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  backgroundColor: colorAccentCoral,
                  elevation: 0,
                  onPressed: () => context.push('/new-memory'),
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: colorTextMain, 
              letterSpacing: -0.3,
            ),
          ),
          Text(
            "Ver todo",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorAccentCoral,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String selected, WidgetRef ref) {
    final isSelected = label == selected;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => ref.read(selectedCategoryProvider.notifier).state = label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? colorTextMain : colorCardSurface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.12 : 0.03),
                blurRadius: isSelected ? 6 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : Colors.grey.shade700, 
              fontSize: 13, 
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}