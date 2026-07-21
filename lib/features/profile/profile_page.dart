import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/memory_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  // 0: Tú, 1: Pareja, 2: Conjunto (Team)
  int _selectedProfileIndex = 0;

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoryProvider);

    // Aquí se adaptará el filtrado cuando conectemos el autor/propietario del recuerdo o Firebase
    final filteredMemories = memories; 

    // Cálculo de estadísticas generales
    final int totalMemories = filteredMemories.length;
    final double averageRating = totalMemories > 0
        ? filteredMemories.map((m) => m.rating).reduce((a, b) => a + b) / totalMemories
        : 0.0;
    
    final int wouldReturnCount = filteredMemories.where((m) => m.wouldReturn).length;
    final double returnPercentage = totalMemories > 0
        ? (wouldReturnCount / totalMemories) * 100
        : 0.0;

    // Recuento por categoría
    final Map<String, int> categoryCounts = {};
    for (var memory in filteredMemories) {
      categoryCounts[memory.category] = (categoryCounts[memory.category] ?? 0) + 1;
    }

    // Textos personalizados según la pestaña activa
    final profileNames = ["Tus Estadísticas", "Estadísticas de Pareja", "Modo Conjunto (Team)"];
    final profileSubtitles = [
      "Exploradora de sabores y rincones",
      "Catadora oficial de la casa",
      "Bitácora gastronómica compartida"
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              "Perfil & Estadísticas",
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
            ),
            backgroundColor: const Color(0xFFFFFDF5),
            pinned: true,
            elevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                
                // Selector de Perfil Dinámico
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F1E8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildProfileTab(0, "Tú"),
                      _buildProfileTab(1, "Pareja"),
                      _buildProfileTab(2, "Team"),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Cabecera de Usuario
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFFD400), width: 2.5),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(0xFFFFF3D6),
                          child: Icon(
                            _selectedProfileIndex == 2 ? Icons.group_rounded : Icons.person_rounded, 
                            size: 36, 
                            color: const Color(0xFFB38F00),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profileNames[_selectedProfileIndex],
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profileSubtitles[_selectedProfileIndex],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Tarjetas de Métricas Clave (Grid de 2x2 simulado)
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        title: "Registros",
                        value: "$totalMemories",
                        icon: Icons.book_rounded,
                        color: const Color(0xFFFF4D29),
                        bgColor: const Color(0xFFFFECE6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _metricCard(
                        title: "Nota Media",
                        value: averageRating.toStringAsFixed(1),
                        icon: Icons.star_rounded,
                        color: const Color(0xFFB38F00),
                        bgColor: const Color(0xFFFFF3D6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        title: "Índice de Retorno",
                        value: "${returnPercentage.toStringAsFixed(0)}%",
                        icon: Icons.thumb_up_rounded,
                        color: const Color(0xFF2E7D32),
                        bgColor: const Color(0xFFE8F5E9),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _metricCard(
                        title: "Categorías",
                        value: "${categoryCounts.keys.length}",
                        icon: Icons.category_rounded,
                        color: const Color(0xFF1565C0),
                        bgColor: const Color(0xFFE3F2FD),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Desglose por Categorías
                Text(
                  "Categorías Principales",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),

                if (categoryCounts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      "Aún no hay categorías registradas. ¡Empieza a añadir recuerdos!",
                      style: GoogleFonts.inter(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...categoryCounts.entries.map((entry) {
                    final double percentage = totalMemories > 0 ? entry.value / totalMemories : 0.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF0F172A)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F1E8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "${entry.value} ${entry.value == 1 ? 'recuerdo' : 'recuerdos'}",
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: Colors.grey.shade100,
                              color: const Color(0xFFFFD400),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(int index, String label) {
    final isSelected = _selectedProfileIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedProfileIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}