import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../core/models/memory_model.dart';
import '../../core/providers/memory_provider.dart';
import '../../core/providers/gamer_provider.dart';
import '../../core/services/gamer_firestore_service.dart';

// ─── Constantes de color ────────────────────────────────────────────────────
const _kDark     = Color(0xFF0F172A);
const _kYellow   = Color(0xFFFFD400);
const _kRed      = Color(0xFFFF4D29);
const _kBg       = Color(0xFFFFFDF5);
const _kYellowBg = Color(0xFFFFF3D6);
const _kRedBg    = Color(0xFFFFECE6);
const _kSlateBg  = Color(0xFFE2E8F0);

// ─── Modelo de configuración de perfil ──────────────────────────────────────
class _ProfileConfig {
  const _ProfileConfig({
    required this.name,
    required this.subtitle,
    required this.color,
    required this.bgCard,
    required this.icon,
  });
  final String   name;
  final String   subtitle;
  final Color    color;
  final Color    bgCard;
  final IconData icon;
}

const _profiles = [
  _ProfileConfig(
    name: 'Eme', subtitle: 'Gestora de igualdad y administradora',
    color: _kRed, bgCard: _kRedBg, icon: Icons.favorite_rounded,
  ),
  _ProfileConfig(
    name: 'CeH', subtitle: 'Catadora oficial y administradora',
    color: _kYellow, bgCard: _kYellowBg, icon: Icons.person_rounded,
  ),
  _ProfileConfig(
    name: 'Team', subtitle: 'Bitácora conjunta de Eme & CeH',
    color: _kDark, bgCard: _kSlateBg, icon: Icons.groups_rounded,
  ),
];

// ─── Decoración neobrutalista reutilizable ───────────────────────────────────
BoxDecoration _neoBorder({
  double radius = 20,
  double width  = 2,
  Offset shadowOffset = const Offset(0, 4),
  Color? color,
}) =>
    BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _kDark, width: width),
      boxShadow: [BoxShadow(color: _kDark, offset: shadowOffset, blurRadius: 0)],
    );

// ════════════════════════════════════════════════════════════════════════════
// ProfilePage
// ════════════════════════════════════════════════════════════════════════════
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  int _selectedProfileIndex = 0;
  final Map<int, String?> _savedImagePaths = {};

  @override
  void initState() {
    super.initState();
    _loadProfileImages();
  }

  Future<void> _loadProfileImages() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < 3; i++) {
        _savedImagePaths[i] = prefs.getString('profile_image_$i');
      }
    });
  }

  Future<void> _pickImageForProfile(int index) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final appDir     = await getApplicationDocumentsDirectory();
    final fileName   = 'profile_image_$index${path.extension(image.path)}';
    final localImage = await File(image.path).copy('${appDir.path}/$fileName');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_$index', localImage.path);

    if (!mounted) return;
    setState(() => _savedImagePaths[index] = localImage.path);
    HapticFeedback.mediumImpact();
  }

  void _saveProfileChanges() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Cambios guardados con éxito! 🚀',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _kDark),
        ),
        backgroundColor: _kYellow,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _kDark, width: 2),
        ),
      ),
    );
  }

  GamerPlayerStats _selectStats(GamerStats stats) {
    if (_selectedProfileIndex == 0) return stats.eme;
    if (_selectedProfileIndex == 1) return stats.ceh;
    return stats.team;
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final memories        = ref.watch(memoryProvider);
    final gamerStatsAsync = ref.watch(gamerStatsStreamProvider);
    final config          = _profiles[_selectedProfileIndex];
    final imagePath       = _savedImagePaths[_selectedProfileIndex];

    final total      = memories.length;
    final avgRating  = total > 0
        ? memories.map((m) => m.rating).reduce((a, b) => a + b) / total
        : 0.0;
    final returnPct  = total > 0
        ? memories.where((m) => m.wouldReturn).length / total * 100
        : 0.0;
    final categoryCounts = <String, int>{};
    for (final m in memories) {
      categoryCounts[m.category] = (categoryCounts[m.category] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Selector de perfil ──────────────────────────────────
                _ProfileTabBar(
                  selectedIndex: _selectedProfileIndex,
                  onSelect: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedProfileIndex = i);
                  },
                ),
                const SizedBox(height: 24),

                // ── Cabecera ────────────────────────────────────────────
                _ProfileHeader(
                  config: config,
                  imagePath: imagePath,
                  onTapImage: () => _pickImageForProfile(_selectedProfileIndex),
                ),
                const SizedBox(height: 24),

                // ── Stats Gamer ─────────────────────────────────────────
                const _SectionTitle('Estadísticas Gamer de Sesión'),
                const SizedBox(height: 12),
                gamerStatsAsync.when(
                  loading: () => const _GamerStatsRow(points: '…', streak: '…'),
                  error:   (_, __) => const _GamerStatsRow(points: '0', streak: '0'),
                  data: (gamerStats) {
                    final s = gamerStats == null
                        ? GamerPlayerStats.empty(uid: '', displayName: config.name)
                        : _selectStats(gamerStats);
                    return _GamerStatsRow(points: '${s.gamerPoints}', streak: '${s.streak}');
                  },
                ),
                const SizedBox(height: 24),

                // ── Bitácora ────────────────────────────────────────────
                const _SectionTitle('Bitácora y Recuerdos'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _MetricCard(
                    title: 'Registros', value: '$total',
                    icon: Icons.book_rounded, color: _kDark, bgColor: _kSlateBg,
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _MetricCard(
                    title: 'Nota Media', value: avgRating.toStringAsFixed(1),
                    icon: Icons.star_half_rounded, color: _kYellow, bgColor: _kYellowBg,
                  )),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _MetricCard(
                    title: 'Índice de Retorno', value: '${returnPct.toStringAsFixed(0)}%',
                    icon: Icons.thumb_up_rounded,
                    color: const Color(0xFF10B981), bgColor: const Color(0xFFD1FAE5),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _MetricCard(
                    title: 'Categorías', value: '${categoryCounts.keys.length}',
                    icon: Icons.category_rounded,
                    color: Colors.deepPurple, bgColor: Colors.purple.shade50,
                  )),
                ]),
                const SizedBox(height: 32),

                // ── Categorías ──────────────────────────────────────────
                const _SectionTitle('Categorías Principales'),
                const SizedBox(height: 14),
                if (categoryCounts.isEmpty)
                  const _EmptyCategoriesPlaceholder()
                else
                  ...categoryCounts.entries.map((e) => _CategoryBar(
                        category: e.key, count: e.value, total: total)),
                const SizedBox(height: 20),

                // ── Botón guardar ───────────────────────────────────────
                _SaveButton(onPressed: _saveProfileChanges),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) => SliverAppBar(
        title: Text('Perfil & Estadísticas',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: _kDark, fontSize: 22)),
        backgroundColor: _kBg,
        pinned: true,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.canPop() ? context.pop() : context.go('/');
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kDark, width: 2),
                  boxShadow: const [BoxShadow(color: _kDark, offset: Offset(0, 2), blurRadius: 0)],
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 16, color: _kDark),
              ),
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Widgets privados
// ════════════════════════════════════════════════════════════════════════════

// ── Selector de pestañas ─────────────────────────────────────────────────────
class _ProfileTabBar extends StatelessWidget {
  const _ProfileTabBar({required this.selectedIndex, required this.onSelect});
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(5),
        decoration: _neoBorder(radius: 20),
        child: Row(
          children: List.generate(
            _profiles.length,
            (i) => _ProfileTab(
              index: i, label: _profiles[i].name,
              isSelected: selectedIndex == i,
              onTap: () => onSelect(i),
            ),
          ),
        ),
      );
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.index, required this.label,
    required this.isSelected, required this.onTap,
  });
  final int index;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? _kYellow : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: isSelected ? Border.all(color: _kDark, width: 2) : null,
            ),
            child: Text(label,
                style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: isSelected ? _kDark : Colors.grey.shade600,
                )),
          ),
        ),
      );
}

// ── Cabecera de perfil ────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.config, required this.imagePath, required this.onTapImage,
  });
  final _ProfileConfig config;
  final String?        imagePath;
  final VoidCallback   onTapImage;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: _neoBorder(radius: 24),
        child: Row(children: [
          GestureDetector(
            onTap: onTapImage,
            child: Stack(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: config.color,
                  border: Border.all(color: _kDark, width: 2),
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: config.bgCard,
                  backgroundImage: imagePath != null ? FileImage(File(imagePath!)) : null,
                  child: imagePath == null ? Icon(config.icon, size: 34, color: _kDark) : null,
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _kYellow, shape: BoxShape.circle,
                    border: Border.all(color: _kDark, width: 1.5),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 12, color: _kDark),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.name,
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: _kDark)),
                const SizedBox(height: 4),
                Text(config.subtitle,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('💡 Toca la foto para cambiarla',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ]),
      );
}

// ── Fila de stats gamer ───────────────────────────────────────────────────────
class _GamerStatsRow extends StatelessWidget {
  const _GamerStatsRow({required this.points, required this.streak});
  final String points, streak;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _MetricCard(
          title: 'Puntos Totales', value: points,
          icon: Icons.star_rounded, color: _kYellow, bgColor: _kYellowBg,
        )),
        const SizedBox(width: 16),
        Expanded(child: _MetricCard(
          title: 'Decisiones / Racha', value: streak,
          icon: Icons.local_fire_department_rounded, color: _kRed, bgColor: _kRedBg,
        )),
      ]);
}

// ── Tarjeta de métrica ────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title, required this.value,
    required this.icon,  required this.color, required this.bgColor,
  });
  final String   title, value;
  final IconData icon;
  final Color    color, bgColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _neoBorder(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kDark, width: 1.5),
                  ),
                  child: Icon(icon, color: _kDark, size: 20),
                ),
                Text(value,
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: _kDark)),
              ],
            ),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

// ── Barra de categoría ────────────────────────────────────────────────────────
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.category, required this.count, required this.total});
  final String category;
  final int    count, total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _neoBorder(radius: 16, shadowOffset: const Offset(0, 3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: _kDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kYellowBg, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kDark, width: 1.5),
                ),
                child: Text(
                  '$count ${count == 1 ? 'recuerdo' : 'recuerdos'}',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _kDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct, minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: _kYellow,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Placeholder vacío ─────────────────────────────────────────────────────────
class _EmptyCategoriesPlaceholder extends StatelessWidget {
  const _EmptyCategoriesPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kDark, width: 2),
        ),
        child: Text(
          'Aún no hay categorías registradas para este perfil.',
          style: GoogleFonts.inter(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      );
}

// ── Título de sección ─────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: _kDark));
}

// ── Botón guardar ─────────────────────────────────────────────────────────────
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kYellow, foregroundColor: _kDark, elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: _kDark, width: 2),
            ),
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.save_rounded, size: 22, color: _kDark),
              const SizedBox(width: 10),
              Text('Guardar Cambios',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: _kDark)),
            ],
          ),
        ),
      );
}
