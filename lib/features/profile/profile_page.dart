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
import '../../core/data/rating_scale.dart';
import '../../core/services/account_deletion_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_image_service.dart';
import '../../core/theme/components/group_switcher.dart';

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

/// El color de cada persona sale de un hash estable de su uid, no de su
/// posición en la lista: antes, que alguien entrara o saliera del grupo
/// cambiaba el color y el icono de todos los demás.
(Color, Color, IconData) _paletteFor(String uid) =>
    _memberPalette[uid.hashCode.abs() % _memberPalette.length];

List<_ProfileConfig> _buildMemberTabs({
  required List<String> memberUids,
  required Map<String, dynamic> memberProfiles,
  required String? myUid,
  required String? createdBy,
}) {
  // Tú siempre primero: la pantalla se llama "Perfil" y lo primero que hay
  // que poder responder es "¿cuál soy yo?".
  final List<String> ordered = <String>[
    ...memberUids.where((String u) => u == myUid),
    ...memberUids.where((String u) => u != myUid),
  ];

  final tabs = <_ProfileConfig>[
    for (final String uid in ordered)
      () {
        final profile = memberProfiles[uid] as Map<String, dynamic>?;
        final palette = _paletteFor(uid);
        final name = (profile?['displayName'] as String?)?.trim();
        return _ProfileConfig(
          uid: uid,
          name: uid == myUid
              ? (name?.isNotEmpty == true ? name! : 'Tú')
              : (name?.isNotEmpty == true ? name! : AuthService.unnamedMember),
          subtitle: uid == myUid
              ? 'Tu cuenta'
              : (uid == createdBy ? 'Creó el grupo' : 'Miembro del grupo'),
          color: palette.$1,
          bgCard: palette.$2,
          icon: palette.$3,
        );
      }(),
  ];

  if (ordered.length > 1) {
    tabs.add(
      const _ProfileConfig(
        uid: null,
        // "Team" en una app en español, colado entre nombres de personas como
        // si fuera una más. Y lo único que cambiaba al tocarlo eran dos
        // números, sin decirlo en ninguna parte.
        name: 'Todo el grupo',
        subtitle: 'Suma de todas las personas del grupo',
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

  /// Foto recién subida, para verla al instante sin esperar al stream.
  /// Las demás salen de `activeGroupProfileImagesProvider`, que lee el mismo
  /// documento del grupo que esta pantalla ya observa — antes se hacía una
  /// lectura COMPLETA del documento por cada miembro, en serie y sin
  /// try/catch: un `permission-denied` dejaba a todo el mundo sin foto y sin
  /// aviso.
  final Map<String, String> _justUploaded = <String, String>{};

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

  Future<void> _pickImageForProfile(String groupId, String uid) async {
    final XFile? image;

    try {
      // Foto de perfil pequeña y circular: no hace falta subirla a
      // resolución de cámara completa.
      image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );
    } on PlatformException catch (e) {
      // Denegar el acceso a Fotos lanzaba una excepción sin capturar: el
      // selector se cerraba y no pasaba absolutamente nada.
      if (!mounted) return;
      _snack(
        e.code.contains('denied')
            ? 'Palito no tiene permiso para acceder a tus fotos. Puedes '
                  'dárselo desde Ajustes.'
            : 'No se pudo abrir la galería.',
      );
      return;
    }

    if (image == null) return;

    final bytes = await image.readAsBytes();

    try {
      final String downloadUrl = await StorageImageService.uploadProfileImage(
        groupId: groupId,
        bytes: bytes,
      );

      if (!mounted) return;
      setState(() => _justUploaded[uid] = downloadUrl);
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Sin esto, un fallo de red al subir la foto quedaba como una
      // excepción sin capturar: ni se avisaba al usuario ni se sabía
      // por qué la foto "no se guardó".
      if (!mounted) return;
      _snack(
        'No se pudo subir la foto. Comprueba tu conexión e inténtalo de nuevo.',
      );
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // El antiguo botón "Guardar Cambios" no guardaba nada: solo vibraba y
  // mostraba "¡Cambios guardados con éxito!". La foto ya se sube sola al
  // elegirla y no había ningún otro campo editable en la pantalla. Se ha
  // eliminado: cada acción guarda al instante y lo dice.

  /// Cambiar tu nombre. Antes no existía NINGUNA pantalla en toda la app para
  /// hacerlo, así que quien se quedaba con un nombre derivado de su correo
  /// (`gdvcgp2gdt`) no tenía forma de arreglarlo.
  Future<void> _editDisplayName() async {
    final String? uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final TextEditingController controller = TextEditingController(
      text: ref.read(currentDisplayNameProvider) ?? '',
    );

    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            counterText: '',
            hintText: 'Cómo quieres que te llamen',
          ),
          onSubmitted: (String v) => Navigator.pop(dialogContext, v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newName == null || newName.trim().isEmpty || !mounted) return;

    try {
      await ref
          .read(authServiceProvider)
          .updateDisplayName(
            uid: uid,
            displayName: newName,
            groupIds: ref.read(userGroupIdsProvider),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Nombre actualizado'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el nombre.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
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
          'Se eliminará tu cuenta y saldrás de todos tus grupos. Tu diario '
          'personal y cualquier grupo en el que estés tú solo se borran por '
          'completo. En los grupos donde quede más gente, el contenido '
          'compartido sigue ahí para ellos. Esta acción no se puede '
          'deshacer.',
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
              style: GoogleFonts.inter(
                color: _kRed,
                fontWeight: FontWeight.bold,
              ),
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
              style: GoogleFonts.inter(
                color: _kRed,
                fontWeight: FontWeight.bold,
              ),
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
    } on AccountDeletionCancelled {
      // Cancelar la hoja de Apple no es un error: no se ha borrado nada.
      // Antes se mostraba "No se pudo eliminar la cuenta, comprueba tu
      // conexión" y, peor, los datos YA se habían borrado en ese punto.
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      _snack('Borrado cancelado. No se ha eliminado nada.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      _snack(
        'No se pudo eliminar la cuenta. Comprueba tu conexión e '
        'inténtalo de nuevo.',
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

    // Las fotos salen del documento del grupo que esta pantalla YA observa.
    // Antes se lanzaba un efecto secundario desde dentro de build() (mutando
    // un campo del State), que además hacía una lectura completa del
    // documento por cada miembro, en serie y sin try/catch.
    final Map<String, String> profileImages = <String, String>{
      ...ref.watch(activeGroupProfileImagesProvider),
      ..._justUploaded,
    };

    final String? myUid = ref.watch(currentUidProvider);
    final String? createdBy = ref.watch(activeGroupCreatedByProvider);
    final String? groupName =
        ref.watch(activeGroupDocProvider).valueOrNull?['name'] as String?;
    final String? personalGroupId = ref.watch(personalGroupIdProvider);
    final bool isPersonalGroup = groupId != null && groupId == personalGroupId;
    final String scopeLabel = isPersonalGroup
        ? 'Mi diario'
        : (groupName ?? 'este grupo');

    final tabs = _buildMemberTabs(
      memberUids: memberUids,
      memberProfiles: memberProfiles,
      myUid: myUid,
      createdBy: createdBy,
    );

    if (tabs.isEmpty) {
      // Antes se devolvía un Scaffold con SOLO un spinner: sin AppBar y sin
      // botón de volver. Si el grupo activo dejaba de ser accesible (te
      // expulsaron, o saliste de él), el usuario quedaba atrapado ahí.
      return Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Cargando tu perfil…',
                    style: GoogleFonts.inter(fontSize: 14, color: _kDark),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      ref.read(activeGroupIdOverrideProvider.notifier).state =
                          null;
                    },
                    child: const Text('Volver a mi diario'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final int safeIndex = _selectedProfileIndex.clamp(0, tabs.length - 1);
    final config = tabs[safeIndex];
    final String? imagePath = config.uid == null
        ? null
        : profileImages[config.uid];
    final bool isMyTab = config.uid != null && config.uid == myUid;

    final total = memories.length;
    // Solo cuentan los recuerdos que SÍ tienen nota: dividir entre el total
    // hacía que, con cuatro recuerdos heredados sin puntuar y uno de 4,5, la
    // "Nota Media" saliera 0,9 — y con todos heredados, exactamente 0,0.
    final double? avgRating = RatingScale.average(
      memories.map((m) => m.rating),
    );
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
                        // SOLO tu propia foto. Antes bastaba con estar en la
                        // pestaña de otra persona para subirle una foto desde tu
                        // galería — y las reglas de Firestore lo permitían.
                        onTapImage: (groupId == null || !isMyTab)
                            ? null
                            : () => _pickImageForProfile(groupId, config.uid!),
                        onEditName: isMyTab ? _editDisplayName : null,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Stats Gamer ─────────────────────────────────────────
                    _fadeSlide(
                      _gamerStatsAnim,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            config.uid == null
                                ? 'Puntos de todo el grupo'
                                : (isMyTab
                                      ? 'Tus puntos'
                                      : 'Puntos de ${config.name}'),
                          ),
                          const SizedBox(height: 12),
                          gamerStatsAsync.when(
                            loading: () => const _GamerStatsRow(),
                            // Mostrar "0 puntos" cuando en realidad ha fallado la
                            // lectura es indistinguible de un usuario nuevo, y
                            // alarmante para uno veterano.
                            error: (_, _) =>
                                const _GamerStatsRow(hasError: true),
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
                          // Estas cuatro cifras son del GRUPO entero, no de la
                          // persona cuya pestaña está seleccionada. Antes no se
                          // decía en ninguna parte, así que al cambiar de pestaña
                          // "no cambiaba nada" y la pantalla resultaba
                          // incomprensible.
                          _SectionTitle('Bitácora de $scopeLabel'),
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
                                child: avgRating == null
                                    ? const _MetricCard(
                                        title: 'Nota Media',
                                        value: '—',
                                        icon: Icons.star_half_rounded,
                                        color: _kYellow,
                                        bgColor: _kYellowBg,
                                      )
                                    : _MetricCard(
                                        title: 'Nota Media',
                                        numericValue: avgRating,
                                        valueBuilder: (v) =>
                                            v.toStringAsFixed(1),
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
                          _SectionTitle('Categorías de $scopeLabel'),
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
                          // Aquí es donde el usuario busca "quitar a alguien" o
                          // "salir del grupo". Antes esas acciones existían pero
                          // solo se llegaba a ellas desde un chip pequeño en
                          // Inicio, cuatro niveles por debajo.
                          const _SectionTitle('Grupos'),
                          const SizedBox(height: 12),
                          _AccountActionTile(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Estás en: $scopeLabel · Cambiar',
                            color: _kDark,
                            bgColor: _kSlateBg,
                            isLoading: false,
                            onTap: () => openGroupSwitcher(context, ref),
                          ),
                          const SizedBox(height: 12),
                          _AccountActionTile(
                            icon: Icons.people_alt_rounded,
                            label: isPersonalGroup
                                ? 'Tu diario es privado'
                                : 'Miembros de $scopeLabel (${memberUids.length})',
                            color: _kDark,
                            bgColor: _kYellowBg,
                            isLoading: false,
                            onTap: groupId == null
                                ? null
                                : () => openGroupMembersSheet(
                                    context,
                                    ref,
                                    groupId: groupId,
                                    groupData:
                                        ref
                                            .read(activeGroupDocProvider)
                                            .valueOrNull ??
                                        const <String, dynamic>{},
                                  ),
                          ),
                          if (!isPersonalGroup && groupId != null) ...[
                            const SizedBox(height: 12),
                            _AccountActionTile(
                              icon: Icons.person_add_alt_1_rounded,
                              label: 'Invitar con un código',
                              color: _kDark,
                              bgColor: _kYellowBg,
                              isLoading: false,
                              onTap: () => context.push(
                                '/invite-partner',
                                extra: groupId,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _AccountActionTile(
                            icon: Icons.group_add_rounded,
                            label: 'Crear grupo o unirme con un código',
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
    // Cada pestaña era `Expanded`: con cuatro miembros, cada una medía
    // ancho/4 y un nombre de 11 caracteres se salía del recuadro amarillo y
    // pisaba al vecino. Ahora cada pestaña mide lo suyo y la tira se
    // desplaza en horizontal cuando no caben.
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          tabs.length,
          (i) => _ProfileTab(
            label: tabs[i].name,
            isSelected: selectedIndex == i,
            onTap: () => onSelect(i),
          ),
        ),
      ),
    ),
  );
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: isSelected,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minWidth: 92, minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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
          child: ExcludeSemantics(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                // grey.shade600 sobre blanco da 4,0:1 — por debajo de AA.
                color: isSelected ? _kDark : const Color(0xFF5A6572),
              ),
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
    this.onEditName,
  });
  final _ProfileConfig config;
  final String? imagePath;
  final VoidCallback? onTapImage;

  /// Solo se pasa en tu propia pestaña.
  final VoidCallback? onEditName;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _stickerCard(radius: 24),
    child: Row(
      children: [
        Tooltip(
          // El tooltip anterior decía "Cambiar foto de perfil" también en la
          // pestaña de otra persona, confirmando una acción que no debería
          // existir.
          message: onTapImage == null
              ? config.name
              : 'Cambiar tu foto de perfil',
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
              Row(
                children: [
                  Flexible(
                    child: Text(
                      config.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _kDark,
                      ),
                    ),
                  ),
                  if (onEditName != null)
                    IconButton(
                      onPressed: onEditName,
                      tooltip: 'Cambiar tu nombre',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      color: _kDark,
                    ),
                ],
              ),
              Text(
                config.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF5A6572),
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Este texto se mostraba SIEMPRE, incluso en la pestaña de otra
              // persona y en la vista de grupo, donde tocar la foto no hacía
              // nada.
              if (onTapImage != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      size: 12,
                      color: Color(0xFF5A6572),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Toca la foto para cambiarla',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF5A6572),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Fila de stats gamer ───────────────────────────────────────────────────────
class _GamerStatsRow extends StatelessWidget {
  const _GamerStatsRow({
    this.pointsValue,
    this.streakValue,
    this.hasError = false,
  });
  final int? pointsValue;
  final int? streakValue;

  /// "—" en vez de un 0 inventado: un fallo de lectura no debe parecer que
  /// el usuario ha perdido sus puntos.
  final bool hasError;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _MetricCard(
          title: 'Puntos Totales',
          value: hasError ? '—' : (pointsValue == null ? '…' : null),
          numericValue: hasError ? null : pointsValue?.toDouble(),
          valueBuilder: hasError ? null : (v) => '${v.round()}',
          icon: Icons.star_rounded,
          color: _kYellow,
          bgColor: _kYellowBg,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _MetricCard(
          title: 'Decisiones / Racha',
          value: hasError ? '—' : (streakValue == null ? '…' : null),
          numericValue: hasError ? null : streakValue?.toDouble(),
          valueBuilder: hasError ? null : (v) => '${v.round()}',
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
              // Estas etiquetas ahora llevan el nombre del grupo dentro
              // ("Miembros de Cena de los viernes (3)"), así que sin
              // `Flexible` + `ellipsis` desbordarían con un nombre largo.
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
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
