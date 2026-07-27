import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/memory_provider.dart';
import '../../core/providers/gamer_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  int _selectedProfileIndex = 0; // 0: Eme, 1: CeH, 2: Team
  
  // Guardamos las rutas de las imágenes de forma persistente
  final Map<int, String?> _savedImagePaths = {};

  @override
  void initState() {
    super.initState();
    _loadProfileImages();
  }

  Future<void> _loadProfileImages() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedImagePaths[0] = prefs.getString('profile_image_0');
      _savedImagePaths[1] = prefs.getString('profile_image_1');
      _savedImagePaths[2] = prefs.getString('profile_image_2');
    });
  }

  Future<void> _pickImageForProfile(int profileIndex) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_$profileIndex', image.path);
      
      setState(() {
        _savedImagePaths[profileIndex] = image.path;
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _saveProfileChanges() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "¡Cambios guardados con éxito! 🚀",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
        ),
        backgroundColor: const Color(0xFFFFD400),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF0F172A), width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoryProvider);
    final gamerStatsAsync = ref.watch(gamerStatsStreamProvider);

    // Lectura centralizada y limpia desde Firestore (Fuente de Verdad Única)
    final gamerData = gamerStatsAsync.value;
    
    int emeScore = 150;
    int cehScore = 60;
    int emeStreak = 10;
    int cehStreak = 5;
    int totalDecisions = 36;

    if (gamerData is Map) {
      final mapData = gamerData as Map<String, dynamic>;

      int parseVal(dynamic val, int fallback) {
        if (val == null) return fallback;
        if (val is int) return val;
        if (val is double) return val.toInt();
        if (val is String) {
          final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
          return int.tryParse(clean) ?? fallback;
        }
        return fallback;
      }

      // Si los datos vienen estructurados por nodos o mapa de usuarios/comensales
      final usersMap = mapData['users'] ?? mapData['comensales'] ?? mapData;

      if (usersMap is Map) {
        for (var entry in usersMap.entries) {
          final nameKey = entry.key.toString().toLowerCase();
          final userData = entry.value;

          if (nameKey.contains('eme')) {
            if (userData is Map) {
              emeScore = parseVal(userData['gamerPoints'] ?? userData['score'] ?? userData['points'], emeScore);
              emeStreak = parseVal(userData['streak'] ?? userData['decisions'], emeStreak);
            } else {
              emeScore = parseVal(userData, emeScore);
            }
          } else if (nameKey.contains('ceh') || nameKey.contains('carmen')) {
            if (userData is Map) {
              cehScore = parseVal(userData['gamerPoints'] ?? userData['score'] ?? userData['points'], cehScore);
              cehStreak = parseVal(userData['streak'] ?? userData['decisions'], cehStreak);
            } else {
              cehScore = parseVal(userData, cehScore);
            }
          }
        }
      }

      // Lecturas directas globales por si la raíz contiene los campos consolidados
      if (mapData.containsKey('decisions')) totalDecisions = parseVal(mapData['decisions'], totalDecisions);
      if (mapData.containsKey('totalDecisions')) totalDecisions = parseVal(mapData['totalDecisions'], totalDecisions);
    }

    int profileScore = 0;
    int profileStreak = 0;

    if (_selectedProfileIndex == 0) {
      profileScore = emeScore;
      profileStreak = emeStreak;
    } else if (_selectedProfileIndex == 1) {
      profileScore = cehScore;
      profileStreak = cehStreak;
    } else {
      // Team (Suma conjunta exacta de puntuaciones y total decisiones globales)
      profileScore = emeScore + cehScore;
      profileStreak = totalDecisions;
    }

    final filteredMemories = memories; 
    final int totalMemories = filteredMemories.length;
    final double averageRating = totalMemories > 0
        ? filteredMemories.map((m) => m.rating).reduce((a, b) => a + b) / totalMemories
        : 0.0;
    
    final int wouldReturnCount = filteredMemories.where((m) => m.wouldReturn).length;
    final double returnPercentage = totalMemories > 0
        ? (wouldReturnCount / totalMemories) * 100
        : 0.0;

    final Map<String, int> categoryCounts = {};
    for (var memory in filteredMemories) {
      categoryCounts[memory.category] = (categoryCounts[memory.category] ?? 0) + 1;
    }

    final profileConfigs = [
      {
        "name": "Eme",
        "subtitle": "Gestora de igualdad y administradora",
        "color": const Color(0xFFFF4D29),
        "bgCard": const Color(0xFFFFECE6),
        "icon": Icons.favorite_rounded,
      },
      {
        "name": "CeH",
        "subtitle": "Catadora oficial y administradora",
        "color": const Color(0xFFFFD400),
        "bgCard": const Color(0xFFFFF3D6),
        "icon": Icons.person_rounded,
      },
      {
        "name": "Team",
        "subtitle": "Bitácora conjunta de Eme & CeH",
        "color": const Color(0xFF0F172A),
        "bgCard": const Color(0xFFE2E8F0),
        "icon": Icons.groups_rounded,
      },
    ];

    final currentConfig = profileConfigs[_selectedProfileIndex];
    final currentImagePath = _savedImagePaths[_selectedProfileIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              "Perfil & Estadísticas",
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), fontSize: 22),
            ),
            backgroundColor: const Color(0xFFFFFDF5),
            pinned: true,
            elevation: 0,
            centerTitle: true,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F172A), width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 2), blurRadius: 0),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF0F172A)),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                
                // Selector Neobrutalista exclusivo para Eme, CeH y Team
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF0F172A), width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 4), blurRadius: 0),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildProfileTab(0, "Eme"),
                      _buildProfileTab(1, "CeH"),
                      _buildProfileTab(2, "Team"),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Cabecera de Usuario con foto persistente
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF0F172A), width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 4), blurRadius: 0),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _pickImageForProfile(_selectedProfileIndex),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentConfig["color"] as Color,
                                border: Border.all(color: const Color(0xFF0F172A), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 34,
                                backgroundColor: currentConfig["bgCard"] as Color,
                                backgroundImage: currentImagePath != null ? FileImage(File(currentImagePath)) : null,
                                child: currentImagePath == null
                                    ? Icon(
                                        currentConfig["icon"] as IconData, 
                                        size: 34, 
                                        color: const Color(0xFF0F172A),
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD400),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 12, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentConfig["name"] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentConfig["subtitle"] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "💡 Toca la foto para cambiarla",
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // SECCIÓN DE ESTADÍSTICAS DEL GAMER_PAGE (Sincronizadas dinámicamente)
                Text(
                  "Estadísticas Gamer de Sesión",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        title: "Puntos Totales",
                        value: "$profileScore",
                        icon: Icons.star_rounded,
                        color: const Color(0xFFFFD400),
                        bgColor: const Color(0xFFFFF3D6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _metricCard(
                        title: "Decisiones / Racha",
                        value: "$profileStreak",
                        icon: Icons.local_fire_department_rounded,
                        color: const Color(0xFFFF4D29),
                        bgColor: const Color(0xFFFFECE6),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // SECCIÓN DE MÉTRICAS GASTRONÓMICAS
                Text(
                  "Bitácora y Recuerdos",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        title: "Registros",
                        value: "$totalMemories",
                        icon: Icons.book_rounded,
                        color: const Color(0xFF0F172A),
                        bgColor: const Color(0xFFE2E8F0),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _metricCard(
                        title: "Nota Media",
                        value: averageRating.toStringAsFixed(1),
                        icon: Icons.star_half_rounded,
                        color: const Color(0xFFFFD400),
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
                        color: const Color(0xFF10B981),
                        bgColor: const Color(0xFFD1FAE5),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _metricCard(
                        title: "Categorías",
                        value: "${categoryCounts.keys.length}",
                        icon: Icons.category_rounded,
                        color: Colors.deepPurple,
                        bgColor: Colors.purple.shade50,
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
                    fontWeight: FontWeight.w900,
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
                      border: Border.all(color: const Color(0xFF0F172A), width: 2),
                    ),
                    child: Text(
                      "Aún no hay categorías registradas para este perfil.",
                      style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
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
                        border: Border.all(color: const Color(0xFF0F172A), width: 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 3), blurRadius: 0),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F172A)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3D6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                                ),
                                child: Text(
                                  "${entry.value} ${entry.value == 1 ? 'recuerdo' : 'recuerdos'}",
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: Colors.grey.shade200,
                              color: const Color(0xFFFFD400),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                
                const SizedBox(height: 20),

                // Botón de Guardar Cambios Estilo Neobrutalista
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD400),
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFF0F172A), width: 2),
                      ),
                      shadowColor: const Color(0xFF0F172A),
                    ),
                    onPressed: _saveProfileChanges,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.save_rounded, size: 22, color: Color(0xFF0F172A)),
                        const SizedBox(width: 10),
                        Text(
                          "Guardar Cambios",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),
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
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedProfileIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFD400) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isSelected ? Border.all(color: const Color(0xFF0F172A), width: 2) : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w900,
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
        border: Border.all(color: const Color(0xFF0F172A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0F172A),
            offset: Offset(0, 4),
            blurRadius: 0,
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
                  border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                ),
                child: Icon(icon, color: const Color(0xFF0F172A), size: 20),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
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
              color: Colors.grey.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}