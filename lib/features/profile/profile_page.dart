import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/household_provider.dart';
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

// ─── Modelo de pestaña de perfil ─────────────────────────────────────────────
//
// Antes había exactamente 3 pestañas fijas en el código ('Eme', 'CeH',
// 'Team'), sin relación con ninguna cuenta real. Ahora se construyen en
// tiempo real a partir de activeGroupMembersProvider — cualquier número de
// miembros, cada uno con su nombre/foto reales — más una pestaña "Team"
// sintetizada solo cuando hay más de un miembro (ver _buildMemberTabs).
class _ProfileConfig {
  const _ProfileConfig({
    required this.uid,
    required this.name,
    required this.subtitle,
    required this.color,
    required this.bgCard,
    required this.icon,
  });

  /// Null únicamente para la pestaña sintetizada "Team" — no representa a
  /// ningún usuario real, así que no tiene foto propia que subir.
  final String? uid;
  final String name;
  final String subtitle;
  final Color color;
  final Color bgCard;
  final IconData icon;
}

// Paleta que se recorre por posición (no por nombre) para dar a cada
// miembro un color/icono distintivo sin tener que hardcodear cuántos
// habrá ni quiénes son.
const List<(Color, Color, IconData)> _memberPalette = [
  (_kRed, _kRedBg, Icons.favorite_rounded),
  (_kYellow, _kYellowBg, Icons.person_rounded),
  (Colors.deepPurple, Color(0xFFEDE7F6), Icons.emoji_emotions_rounded),
  (Color(0xFF10B981), Color(0xFFD1FAE5), Icons.eco_rounded),
];

List<_ProfileConfig> _buildMemberTabs({
  required List<String> memberUids,
  required Map<String, dynamic> memberProfiles,
}) {
  final tabs = <_ProfileConfig>[
    for (int i = 0; i < memberUids.length; i++)
      () {
        final uid = memberUids[i];
        final profile = memberProfiles[uid] as Map<String, dynamic>?;
        final palette = _memberPalette[i % _memberPalette.length];
        final name = (profile?['displayName'] as String?)?.trim();
        return _ProfileConfig(
          uid: uid,
          name: name?.isNotEmpty == true ? name! : 'Miembro',
          subtitle: 'Miembro del grupo',
          color: palette.$1,
          bgCard: palette.$2,
          icon: palette.$3,
        );
      }(),
  ];

  if (memberUids.length > 1) {
    tabs.add(
      const _ProfileConfig(
        uid: null,
        name: 'Team',
        subtitle: 'Vista conjunta de todo el grupo',
        color: _kDark,
        bgCard: _kSlateBg,
        icon: Icons.groups_rounded,
      ),
    );
  }

  return tabs;
}

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
  final Map<String, String?> _savedImagePaths = {};
  List<String> _lastLoadedMemberUids = const [];
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;

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
    // Las fotos se cargan reactivamente desde build() en cuanto se conoce
    // la lista real de miembros (ver el ref.listen ahí) — en el primer
    // frame, activeGroupMembersProvider casi seguro todavía está vacío
    // mientras se resuelve el stream de Firestore.
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

  // Las fotos de perfil viven en Cloudinary, con su URL guardada en
  // groups/{groupId}.profileImages, indexado por uid — así son las
  // mismas en todos los dispositivos del grupo (y las de cada persona
  // sobreviven aunque cambie el orden de las pestañas).
  Future<void> _loadProfileImages(String groupId, List<String> uids) async {
    final resolved = <String, String?>{};

    for (final uid in uids) {
      resolved[uid] = await StorageImageService.getProfileImageUrl(
        groupId,
        uid,
      );
    }

    if (!mounted) return;
    setState(() => _savedImagePaths.addAll(resolved));
  }

  Future<void> _pickImageForProfile(String groupId, String uid) async {
    // Foto de perfil pequeña y circular: no hace falta subirla a
    // resolución de cámara completa.
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();

    try {
      final downloadUrl = await StorageImageService.uploadProfileImage(
        groupId: groupId,
        uid: uid,
        bytes: bytes,
      );

      if (!mounted) return;
      setState(() => _savedImagePaths[uid] = downloadUrl);
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Sin esto, un fallo de red al subir la foto quedaba como una
      // excepción sin capturar: ni se avisaba al usuario ni se sabía
      // por qué la foto "no se guardó".
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo subir la foto. Comprueba tu conexión '
            'e inténtalo de nuevo.',
          ),
        ),
      );
    }
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

  // ─── Cuenta: cerrar sesión / eliminar cuenta ────────────────────────────
  Future<void> _handleSignOut() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Podrás volver a iniciar sesión con Apple cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSigningOut = true);
    // No navegamos manualmente: al cerrar sesión, authStateChangesProvider
    // emite null y el redirect de GoRouter lleva a /sign-in solo, igual
    // que ocurre al iniciar sesión (ver routerProvider en main.dart).
    await ref.read(authServiceProvider).signOut();
    if (mounted) setState(() => _isSigningOut = false);
  }

  // Doble confirmación deliberada — es una acción destructiva e
  // irreversible sobre la cuenta personal (aunque los datos compartidos
  // del grupo queden archivados, ver AccountDeletionService). El primer
  // diálogo explica las consecuencias; el segundo es la última oportunidad
  // de echarse atrás, sin más contexto que distraiga.
  Future<void> _handleDeleteAccount() async {
    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tu cuenta'),
        content: const Text(
          'Se eliminará tu cuenta y saldrás de todos tus grupos '
          'compartidos. Los recuerdos, fotos y estadísticas que hayas '
          'compartido NO se borran, por si alguien más los sigue usando '
          'o vuelves a unirte más adelante. Esta acción no se puede '
          'deshacer para tu cuenta personal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Continuar',
              style: GoogleFonts.inter(color: _kRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    final bool? secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Seguro que quieres eliminarla?'),
        content: const Text('Esta es tu última oportunidad para cancelar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sí, eliminar mi cuenta',
              style: GoogleFonts.inter(color: _kRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (secondConfirm != true || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await ref.read(accountDeletionServiceProvider).deleteAccount();
      // Éxito: authStateChangesProvider emite null y el redirect de
      // GoRouter saca de aquí solo — no hace falta navegar a mano.
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo eliminar la cuenta. Comprueba tu conexión e '
            'inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  /// La pestaña "Team" (config.uid == null) muestra el agregado del grupo;
  /// cualquier otra pestaña muestra las estadísticas propias de ese uid.
  GamerPlayerStats _selectStats(GamerStats stats, _ProfileConfig config) {
    if (config.uid == null) return stats.team;
    return stats.forUid(config.uid!);
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoryProvider);
    final gamerStatsAsync = ref.watch(gamerStatsStreamProvider);

    final String? groupId = ref.watch(activeGroupIdProvider);
    final List<String> memberUids = ref.watch(activeGroupMembersProvider);
    final Map<String, dynamic> memberProfiles =
        (ref.watch(activeGroupDocProvider).valueOrNull?['memberProfiles']
                as Map?)
            ?.cast<String, dynamic>() ??
        const {};

    // Carga (o recarga) las fotos de perfil en cuanto se conoce la lista
    // real de miembros — puede tardar un instante en el primer frame
    // mientras se resuelve el stream de Firestore, y puede cambiar más
    // adelante si alguien se une al grupo con esta pantalla ya abierta.
    if (groupId != null &&
        memberUids.isNotEmpty &&
        !listEquals(memberUids, _lastLoadedMemberUids)) {
      _lastLoadedMemberUids = memberUids;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadProfileImages(groupId, memberUids);
      });
    }

    final tabs = _buildMemberTabs(
      memberUids: memberUids,
      memberProfiles: memberProfiles,
    );

    if (tabs.isEmpty) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final int safeIndex = _selectedProfileIndex.clamp(0, tabs.length - 1);
    final config = tabs[safeIndex];
    final imagePath = config.uid == null
        ? null
        : _savedImagePaths[config.uid];

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
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
                    tabs: tabs,
                    selectedIndex: safeIndex,
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
                    // La pestaña "Team" no representa a ninguna cuenta real,
                    // así que no tiene foto propia que cambiar.
                    onTapImage: (groupId == null || config.uid == null)
                        ? null
                        : () => _pickImageForProfile(groupId, config.uid!),
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
                        error: (_, _) => const _GamerStatsRow(
                          pointsValue: 0,
                          streakValue: 0,
                        ),
                        data: (gamerStats) {
                          final s = gamerStats == null
                              ? GamerPlayerStats.empty(
                                  uid: '',
                                  displayName: config.name,
                                )
                              : _selectStats(gamerStats, config);
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
                const SizedBox(height: 32),

                // ── Grupos ────────────────────────────────────────────────
                _fadeSlide(
                  _saveButtonAnim,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Grupos'),
                      const SizedBox(height: 12),
                      _AccountActionTile(
                        icon: Icons.group_add_rounded,
                        label: 'Compartir con alguien',
                        color: _kDark,
                        bgColor: _kYellowBg,
                        isLoading: false,
                        onTap: () => context.push('/household-setup'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Cuenta ──────────────────────────────────────────────
                _fadeSlide(
                  _saveButtonAnim,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Cuenta'),
                      const SizedBox(height: 12),
                      _AccountActionTile(
                        icon: Icons.logout_rounded,
                        label: 'Cerrar sesión',
                        color: _kDark,
                        bgColor: _kSlateBg,
                        isLoading: _isSigningOut,
                        onTap: _isSigningOut || _isDeletingAccount
                            ? null
                            : _handleSignOut,
                      ),
                      const SizedBox(height: 12),
                      _AccountActionTile(
                        icon: Icons.delete_forever_rounded,
                        label: 'Eliminar cuenta',
                        color: _kRed,
                        bgColor: _kRedBg,
                        isLoading: _isDeletingAccount,
                        onTap: _isSigningOut || _isDeletingAccount
                            ? null
                            : _handleDeleteAccount,
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
        ),
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
  const _ProfileTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });
  final List<_ProfileConfig> tabs;
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
        tabs.length,
        (i) => _ProfileTab(
          index: i,
          label: tabs[i].name,
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
  final VoidCallback? onTapImage;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _stickerCard(radius: 24),
    child: Row(
      children: [
        Tooltip(
          message: onTapImage == null
              ? config.name
              : 'Cambiar foto de perfil',
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
              if (onTapImage != null)
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

// ── Fila de acción de cuenta (cerrar sesión / eliminar cuenta) ────────────────
class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: _stickerCard(
      radius: 16,
      borderWidth: 2,
      shadowOffset: const Offset(3, 3),
      color: bgColor,
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: color,
                        ),
                      )
                    : Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
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
