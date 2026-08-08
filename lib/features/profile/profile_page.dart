import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/memory_model.dart';
import '../../core/providers/memory_provider.dart';
import '../../core/providers/gamer_provider.dart';
import '../../core/services/gamer_firestore_service.dart';
import '../../core/services/storage_image_service.dart';
import '../../core/theme/components/neo_pressable.dart';

// ─── Constantes de color ────────────────────────────────────────────────────
const _kDark = Color(0xFF0F172A);
const _kYellow = Color(0xFFFFD400);
const _kRed = Color(0xFFFF4D29);
const _kBg = Color(0xFFFFFDF5);
const _kYellowBg = Color(0xFFFFF3D6);
const _kRedBg = Color(0xFFFFECE6);
const _kSlateBg = Color(0xFFE2E8F0);

// ─── Modelo de configuración de perfil ──────────────────────────────────────
class _ProfileConfig {
  const _ProfileConfig({
    required this.name,
    required this.subtitle,
    required this.color,
    required this.bgCard,
    required this.icon,
  });
  final String name;
  final String subtitle;
  final Color color;
  final Color bgCard;
  final IconData icon;
}

const _profiles = [
  _ProfileConfig(
    name: 'Eme',
    subtitle: 'Gestora de igualdad y administradora',
    color: _kRed,
    bgCard: _kRedBg,
    icon: Icons.favorite_rounded,
  ),
  _ProfileConfig(
    name: 'CeH',
    subtitle: 'Catadora oficial y administradora',
    color: _kYellow,
    bgCard: _kYellowBg,
    icon: Icons.person_rounded,
  ),
  _ProfileConfig(
    name: 'Team',
    subtitle: 'Bitácora conjunta de Eme & CeH',
    color: _kDark,
    bgCard: _kSlateBg,
    icon: Icons.groups_rounded,
  ),
];

// ─── Tarjeta "sticker" reutilizable: borde negro grueso + sombra dura sin
// difuminado — el neobrutalismo de marca, ejecutado con rigor (radios y
// offsets consistentes en toda la pantalla, sin blur ni degradados) ──────
BoxDecoration _stickerCard({
  double radius = 20,
  double borderWidth = 2,
  Offset shadowOffset = const Offset(4, 4),
  Color? color,
}) => BoxDecoration(
  color: color ?? Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: _kDark, width: borderWidth),
  boxShadow: [BoxShadow(color: _kDark, offset: shadowOffset, blurRadius: 0)],
);

// ─── Botón circular con feedback táctil y objetivo de toque accesible ───────
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _kDark, width: 2),
        boxShadow: const [
          BoxShadow(color: _kDark, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Icon(icon, size: 18, color: _kDark),
          ),
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// ProfilePage
// ════════════════════════════════════════════════════════════════════════════
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  int _selectedProfileIndex = 0;
  final Map<int, String?> _savedImagePaths = {};

  // ─── Entrada escalonada ───────────────────────────────────────────────────
  // La pantalla no aparece de golpe: cada bloque tiene su propio intervalo
  // dentro de un único AnimationController, igual que en HomePage — así el
  // lenguaje de movimiento de la app es consistente entre pantallas.
  late final AnimationController _entryController;

  Animation<double> _interval(double start, double end) => CurvedAnimation(
    parent: _entryController,
    curve: Interval(start, end, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _tabBarAnim = _interval(0.00, 0.30);
  late final Animation<double> _headerAnim = _interval(0.10, 0.45);
  late final Animation<double> _gamerStatsAnim = _interval(0.25, 0.58);
  late final Animation<double> _bitacoraAnim = _interval(0.38, 0.70);
  late final Animation<double> _categoriesAnim = _interval(0.52, 0.82);
  late final Animation<double> _saveButtonAnim = _interval(0.70, 1.00);

  @override
  void initState() {
    super.initState();
    _loadProfileImages();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Widget _fadeSlide(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }

  // Las fotos de perfil viven en Firebase Storage bajo un nombre fijo por
  // índice (households/<hogar>/profile_images/profile_<i>.jpg) — así son
  // las mismas en todos los dispositivos del hogar, en vez de quedarse
  // atrapadas en el almacenamiento local de un solo móvil.
  Future<void> _loadProfileImages() async {
    final resolved = <int, String?>{};

    for (int i = 0; i < 3; i++) {
      resolved[i] = await StorageImageService.getProfileImageUrl(i);
    }

    if (!mounted) return;
    setState(() => _savedImagePaths.addAll(resolved));
  }

  Future<void> _pickImageForProfile(int index) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();

    final downloadUrl = await StorageImageService.uploadProfileImage(
      profileIndex: index,
      bytes: bytes,
    );

    if (!mounted) return;
    setState(() => _savedImagePaths[index] = downloadUrl);
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
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final memories = ref.watch(memoryProvider);
    final gamerStatsAsync = ref.watch(gamerStatsStreamProvider);
    final config = _profiles[_selectedProfileIndex];
    final imagePath = _savedImagePaths[_selectedProfileIndex];

    final total = memories.length;
    final avgRating = total > 0
        ? memories.map((m) => m.rating).reduce((a, b) => a + b) / total
        : 0.0;
    final returnPct = total > 0
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
                _fadeSlide(
                  _tabBarAnim,
                  _ProfileTabBar(
                    selectedIndex: _selectedProfileIndex,
                    onSelect: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedProfileIndex = i);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // ── Cabecera ────────────────────────────────────────────
                _fadeSlide(
                  _headerAnim,
                  _ProfileHeader(
                    config: config,
                    imagePath: imagePath,
                    onTapImage: () =>
                        _pickImageForProfile(_selectedProfileIndex),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Stats Gamer ─────────────────────────────────────────
                _fadeSlide(
                  _gamerStatsAnim,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Estadísticas Gamer de Sesión'),
                      const SizedBox(height: 12),
                      gamerStatsAsync.when(
                        loading: () => const _GamerStatsRow(),
                        error: (_, __) => const _GamerStatsRow(
                          pointsValue: 0,
                          streakValue: 0,
                        ),
                        data: (gamerStats) {
                          final s = gamerStats == null
                              ? GamerPlayerStats.empty(
                                  uid: '',
                                  displayName: config.name,
                                )
                              : _selectStats(gamerStats);
                          return _GamerStatsRow(
                            pointsValue: s.gamerPoints,
                            streakValue: s.streak,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Bitácora ────────────────────────────────────────────
                _fadeSlide(
                  _bitacoraAnim,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Bitácora y Recuerdos'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Registros',
                              numericValue: total.toDouble(),
                              valueBuilder: (v) => '${v.round()}',
                              icon: Icons.book_rounded,
                              color: _kDark,
                              bgColor: _kSlateBg,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MetricCard(
                              title: 'Nota Media',
                              numericValue: avgRating,
                              valueBuilder: (v) => v.toStringAsFixed(1),
                              icon: Icons.star_half_rounded,
                              color: _kYellow,
                              bgColor: _kYellowBg,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Índice de Retorno',
                              numericValue: returnPct,
                              valueBuilder: (v) => '${v.round()}%',
                              icon: Icons.thumb_up_rounded,
                              color: const Color(0xFF10B981),
                              bgColor: const Color(0xFFD1FAE5),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _MetricCard(
                              title: 'Categorías',
                              numericValue: categoryCounts.keys.length
                                  .toDouble(),
                              valueBuilder: (v) => '${v.round()}',
                              icon: Icons.category_rounded,
                              color: Colors.deepPurple,
                              bgColor: Colors.purple.shade50,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Categorías ──────────────────────────────────────────
                _fadeSlide(
                  _categoriesAnim,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Categorías Principales'),
                      const SizedBox(height: 14),
                      if (categoryCounts.isEmpty)
                        const _EmptyCategoriesPlaceholder()
                      else
                        ...categoryCounts.entries.map(
                          (e) => _CategoryBar(
                            category: e.key,
                            count: e.value,
                            total: total,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Botón guardar ───────────────────────────────────────
                _fadeSlide(
                  _saveButtonAnim,
                  _SaveButton(onPressed: _saveProfileChanges),
                ),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) => SliverAppBar(
    title: Text(
      'Perfil & Estadísticas',
      style: GoogleFonts.outfit(
        fontWeight: FontWeight.w900,
        color: _kDark,
        fontSize: 22,
      ),
    ),
    backgroundColor: _kBg,
    pinned: true,
    elevation: 0,
    centerTitle: true,
    leading: Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Center(
        child: _CircleIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Volver',
          onTap: () {
            HapticFeedback.selectionClick();
            context.canPop() ? context.pop() : context.go('/');
          },
        ),
      ),
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kDark, width: 2),
              boxShadow: const [
                BoxShadow(color: _kDark, offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    ],
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
    decoration: _stickerCard(
      radius: 20,
      borderWidth: 2,
      shadowOffset: const Offset(3, 3),
    ),
    child: Row(
      children: List.generate(
        _profiles.length,
        (i) => _ProfileTab(
          index: i,
          label: _profiles[i].name,
          isSelected: selectedIndex == i,
          onTap: () => onSelect(i),
        ),
      ),
    ),
  );
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.index,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final int index;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _kYellow : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isSelected ? Border.all(color: _kDark, width: 2) : null,
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: _kDark,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isSelected ? _kDark : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Cabecera de perfil ────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.config,
    required this.imagePath,
    required this.onTapImage,
  });
  final _ProfileConfig config;
  final String? imagePath;
  final VoidCallback onTapImage;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _stickerCard(radius: 24),
    child: Row(
      children: [
        Tooltip(
          message: 'Cambiar foto de perfil',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kDark, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: _kDark,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Material(
                    color: config.color,
                    child: InkWell(
                      onTap: onTapImage,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: config.bgCard,
                          backgroundImage: imagePath != null
                              ? NetworkImage(imagePath!)
                              : null,
                          onBackgroundImageError: imagePath != null
                              ? (_, _) {}
                              : null,
                          child: imagePath == null
                              ? Icon(config.icon, size: 34, color: _kDark)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _kYellow,
                      shape: BoxShape.circle,
                      border: Border.all(color: _kDark, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: _kDark,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 13,
                      color: _kDark,
                    ),
                  ),
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
                config.name,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _kDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                config.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Toca la foto para cambiarla',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Fila de stats gamer ───────────────────────────────────────────────────────
class _GamerStatsRow extends StatelessWidget {
  const _GamerStatsRow({this.pointsValue, this.streakValue});
  final int? pointsValue;
  final int? streakValue;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _MetricCard(
          title: 'Puntos Totales',
          value: pointsValue == null ? '…' : null,
          numericValue: pointsValue?.toDouble(),
          valueBuilder: (v) => '${v.round()}',
          icon: Icons.star_rounded,
          color: _kYellow,
          bgColor: _kYellowBg,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _MetricCard(
          title: 'Decisiones / Racha',
          value: streakValue == null ? '…' : null,
          numericValue: streakValue?.toDouble(),
          valueBuilder: (v) => '${v.round()}',
          icon: Icons.local_fire_department_rounded,
          color: _kRed,
          bgColor: _kRedBg,
        ),
      ),
    ],
  );
}

// ── Tarjeta de métrica ────────────────────────────────────────────────────────
// Cuando se proporciona `numericValue`, la cifra cuenta desde 0 hasta el
// valor final en lugar de aparecer estática — refuerza la sensación de que
// la app está "viva" y respondiendo a los datos reales del usuario.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.value,
    this.numericValue,
    this.valueBuilder,
  }) : assert(value != null || (numericValue != null && valueBuilder != null));
  final String title;
  final String? value;
  final double? numericValue;
  final String Function(double)? valueBuilder;
  final IconData icon;
  final Color color, bgColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _stickerCard(),
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
                border: Border.all(color: _kDark, width: 1.5),
              ),
              child: Icon(icon, color: _kDark, size: 20),
            ),
            _buildValue(),
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

  Widget _buildValue() {
    final style = GoogleFonts.outfit(
      fontSize: 24,
      fontWeight: FontWeight.w900,
      color: _kDark,
    );
    if (numericValue == null) {
      return Text(value!, style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: numericValue),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(valueBuilder!(v), style: style),
    );
  }
}

// ── Barra de categoría ────────────────────────────────────────────────────────
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.count,
    required this.total,
  });
  final String category;
  final int count, total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _stickerCard(
        radius: 16,
        borderWidth: 2,
        shadowOffset: const Offset(3, 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _kDark,
                ),
              ),
              Transform.rotate(
                angle: -0.05,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kYellowBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kDark, width: 1.5),
                  ),
                  child: Text(
                    '$count ${count == 1 ? 'recuerdo' : 'recuerdos'}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _kDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
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
    decoration: _stickerCard(radius: 16, borderWidth: 2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.category_outlined, size: 28, color: Colors.grey.shade400),
        const SizedBox(height: 10),
        Text(
          'Aún no hay categorías registradas para este perfil.',
          style: GoogleFonts.inter(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ── Título de sección ─────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.outfit(
      fontSize: 18,
      fontWeight: FontWeight.w900,
      color: _kDark,
    ),
  );
}

// ── Botón guardar ─────────────────────────────────────────────────────────────
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: NeoPressable(
      onTap: onPressed,
      color: _kYellow,
      borderWidth: 2,
      shadowOffset: const Offset(4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.save_rounded, size: 22, color: _kDark),
          const SizedBox(width: 10),
          Text(
            'Guardar Cambios',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _kDark,
            ),
          ),
        ],
      ),
    ),
  );
}
