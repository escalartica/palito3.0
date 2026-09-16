import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/household_provider.dart';
import '../../core/providers/memory_provider.dart';
import '../../core/models/memory_model.dart';
import '../../core/providers/gamer_provider.dart';
import '../../core/services/gamer_firestore_service.dart';
import '../../core/data/rating_scale.dart';
import '../../core/services/account_deletion_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/storage_image_service.dart';
import 'widgets/profile_groups_section.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/theme/tokens/app_animation.dart';
import '../../core/theme/tokens/app_typography.dart';
import '../../core/theme/components/app_dock.dart';
import '../../core/theme/components/stats_ticker.dart';
import '../../core/utils/relative_date.dart';
import '../../core/theme/components/progress_track.dart';

// ─── Constantes de color ────────────────────────────────────────────────────
const _kDark = AppColors.textPrimary;
const _kYellow = AppColors.primary;
const _kRed = AppColors.accent;
const _kBg = AppColors.background;
const _kYellowBg = Color(0xFFFFF3D6);
const _kRedBg = Color(0xFFFFECE6);
const _kSlateBg = Color(0xFFE2E8F0);

// AppColors solo define tokens funcionales (texto, fondo, estado); esta
// pantalla necesita además un par de acentos puramente decorativos para
// distinguir personas y categorías visualmente. Se nombran aquí, una sola
// vez, en vez de repetir el literal hexadecimal en cada sitio donde se usan
// (antes `Color(0xFF10B981)` y `Colors.deepPurple` con dos fondos ligeramente
// distintos aparecían sueltos en tres puntos del archivo).
const _kPurple = Colors.deepPurple;
const _kPurpleBg = Color(0xFFEDE7F6);
const _kGreen = Color(0xFF10B981);
const _kGreenBg = Color(0xFFD1FAE5);

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
  (_kPurple, _kPurpleBg, Icons.emoji_emotions_rounded),
  (_kGreen, _kGreenBg, Icons.eco_rounded),
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
  double radius = AppRadius.lg,
  double borderWidth = AppBorder.normal,
  Offset shadowOffset = const Offset(4, 4),
  Color? color,
}) => BoxDecoration(
  color: color ?? AppColors.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: _kDark, width: borderWidth),
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

  // `CurvedAnimation` y no `Animation<double>`: hace falta el tipo concreto
  // para poder llamar a su `dispose()`. Ver el `dispose` de este State.
  CurvedAnimation _interval(double start, double end) => CurvedAnimation(
    parent: _entryController,
    curve: Interval(start, end, curve: AppAnimation.enter),
  );

  late final CurvedAnimation _tabBarAnim = _interval(0.00, 0.30);
  late final CurvedAnimation _headerAnim = _interval(0.10, 0.45);
  late final CurvedAnimation _gamerStatsAnim = _interval(0.25, 0.58);
  late final CurvedAnimation _bitacoraAnim = _interval(0.38, 0.70);
  late final CurvedAnimation _categoriesAnim = _interval(0.52, 0.82);
  late final CurvedAnimation _saveButtonAnim = _interval(0.70, 1.00);

  @override
  void initState() {
    super.initState();
    // Las fotos se cargan reactivamente desde build() en cuanto se conoce
    // la lista real de miembros (ver el ref.listen ahí) — en el primer
    // frame, activeGroupMembersProvider casi seguro todavía está vacío
    // mientras se resuelve el stream de Firestore.
    _entryController = AnimationController(
      vsync: this,
      duration: AppAnimation.entry,
    )..forward();
  }

  // ── "Reducir movimiento" ──
  //
  // Esta pantalla montaba su coreografía de entrada pasara lo que pasara.
  // Quien lleva activada esa opción del sistema —a menudo por vértigo o por
  // migraña— seguía viendo entrar los bloques uno detrás de otro.
  //
  // Va aquí y no en `initState` porque el `MediaQuery` todavía no existe en
  // ese momento; y se resuelve poniendo el controlador directamente en su
  // valor final, que es la pantalla ya montada, sin recorrido.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entryController.value = 1.0;
    }
  }

  @override
  void dispose() {
    // Las seis animaciones ANTES que el controlador del que cuelgan.
    //
    // `_interval()` devuelve un `CurvedAnimation`, y un `CurvedAnimation` se
    // suscribe a su animación padre: solo su propio `dispose()` deshace esa
    // suscripción. Aquí había seis, una por bloque de la coreografía de
    // entrada, y ninguna se liberaba — cada entrada y salida del Perfil
    // dejaba seis oyentes colgados.
    for (final CurvedAnimation a in <CurvedAnimation>[
      _tabBarAnim,
      _headerAnim,
      _gamerStatsAnim,
      _bitacoraAnim,
      _categoriesAnim,
      _saveButtonAnim,
    ]) {
      a.dispose();
    }

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
    XFile? image;

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

    // Leer los bytes TAMBIÉN puede fallar, y estaba fuera de los dos try que
    // lo rodean: una foto que vive en iCloud y no está descargada, un fichero
    // movido, o una imagen enorme sin memoria, y la excepción salía sin
    // capturar. El síntoma para el usuario es exactamente el mismo que el
    // fallo que el comentario de arriba dice haber arreglado: el selector se
    // cierra y no pasa nada.
    final Uint8List bytes;
    try {
      bytes = await image.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      _snack('No se pudo leer esa foto. Prueba con otra.');
      return;
    }

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

    // Liberar el controlador DESPUÉS del fotograma, no aquí mismo.
    //
    // `showDialog` completa su future en el `Navigator.pop`, no cuando
    // termina la animación de salida. En este punto el `TextField` de arriba
    // sigue montado y sigue apuntando a este controlador, así que liberarlo
    // ya provoca *"A TextEditingController was used after being disposed"*
    // en cuanto el diálogo desmonta su foco.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

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
            // "Continuar" no dice qué va a pasar, y estaba puesto en la
            // acción más irreversible de la app. Ahora el botón nombra lo
            // que hace, que además es la regla de toda la app.
            //
            // Y en rojo de verdad: el coral de marca sobre el blanco del
            // diálogo mide 3,31:1, por debajo del 4,5:1 de WCAG AA. Este
            // mide 5,44:1. Es el mismo `AppColors.error` que ya usa la hoja
            // de personas para "Quitar".
            child: Text(
              'Sí, quiero eliminarla',
              style: GoogleFonts.inter(
                color: AppColors.error,
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
                color: AppColors.error,
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
    final List<MemoryModel> allMemories = ref.watch(memoryProvider);
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
                  // Sin `color` toma `colorScheme.primary`, el amarillo de
                  // marca: 1,39:1 sobre el crema del fondo. Es el único
                  // indicador de que algo está pasando en la pantalla que ve
                  // quien ha perdido el acceso a su grupo, y era invisible.
                  const CircularProgressIndicator(color: _kDark),
                  const SizedBox(height: 24),
                  Text(
                    'Cargando tu perfil…',
                    style: GoogleFonts.inter(fontSize: 14, color: _kDark),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      switchActiveGroup(ref, null);
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

    // ── Los números de cada persona son ahora los suyos ──
    //
    // Hasta ahora las pestañas de persona eran decorativas: pulsaras la que
    // pulsaras, salían las mismas cifras, porque los recuerdos no guardaban
    // quién los había escrito. Desde que `MemoryModel.createdBy` existe, sí
    // se puede separar.
    //
    // Con dos cautelas, porque este campo es nuevo:
    //
    // - Los recuerdos guardados antes de hoy no llevan autor, y no se puede
    //   adivinar. Si NINGUNO lo lleva, filtrar dejaría todas las pestañas a
    //   cero: en ese caso se enseñan los del grupo entero, como siempre.
    // - Si algunos sí lo llevan, se filtra — y se dice cuántos se quedan
    //   fuera, en vez de que las cuentas no cuadren en silencio.
    final bool anyAuthored = allMemories.any(
      (MemoryModel m) => m.createdBy != null,
    );
    final bool filterByPerson = config.uid != null && anyAuthored;

    final List<MemoryModel> memories = filterByPerson
        ? allMemories
              .where((MemoryModel m) => m.createdBy == config.uid)
              .toList()
        : allMemories;

    final int unattributed = filterByPerson
        ? allMemories.where((MemoryModel m) => m.createdBy == null).length
        : 0;

    // Cero recuerdos no siempre significa "no hay recuerdos". `MemoryNotifier`
    // distingue el diario vacío del diario que no se ha podido leer, y esta
    // pantalla no lo estaba preguntando.
    final bool diaryPermissionDenied =
        allMemories.isEmpty &&
        ref.read(memoryProvider.notifier).isPermissionDenied;
    final bool diaryLoadFailed =
        allMemories.isEmpty &&
        ref.read(memoryProvider.notifier).hasStreamError;

    final total = memories.length;
    // Solo cuentan los recuerdos que SÍ tienen nota: dividir entre el total
    // hacía que, con cuatro recuerdos heredados sin puntuar y uno de 4,5, la
    // "Nota Media" saliera 0,9 — y con todos heredados, exactamente 0,0.
    final double? avgRating = RatingScale.average(
      memories.map((m) => m.rating),
    );
    // `double?`, no `0.0`.
    //
    // Con el diario vacío la tarjeta afirmaba "Volverías 0 %": que no
    // repetirías en ninguno de los sitios a los que no has ido. Un cero
    // inventado es peor que un hueco, porque parece un dato. Justo al lado,
    // "Nota media" ya hacía lo correcto pintando un guion.
    final double? returnPct = total > 0
        ? memories.where((m) => m.wouldReturn).length / total * 100
        : null;
    // ── Tres cosas que el modelo ya sabía y la pantalla no enseñaba ──
    //
    // El perfil consumía tres campos de `MemoryModel` —nota, si volverías y
    // categoría— y del resto no decía nada, teniendo `restaurantName`,
    // `title` y `date` guardados desde el primer día. El resultado era una
    // rejilla de porcentajes: correcta, y sin una sola frase que alguien
    // quiera leer dos veces. Estas tres sí lo son, y no hacen falta datos
    // nuevos ni una lectura más a Firestore.
    final Map<String, int> placeCounts = <String, int>{};
    for (final m in memories) {
      final String place = m.restaurantName.trim();
      if (place.isEmpty) continue;
      placeCounts[place] = (placeCounts[place] ?? 0) + 1;
    }
    MapEntry<String, int>? favouritePlace;
    for (final MapEntry<String, int> e in placeCounts.entries) {
      if (favouritePlace == null || e.value > favouritePlace.value) {
        favouritePlace = e;
      }
    }
    // Con una sola visita no hay "sitio de siempre": hay un sitio.
    if (favouritePlace != null && favouritePlace.value < 2) favouritePlace = null;

    MemoryModel? bestMemory;
    for (final m in memories) {
      if (m.rating <= 0) continue;
      if (bestMemory == null || m.rating > bestMemory.rating) bestMemory = m;
    }

    DateTime? lastDate;
    for (final m in memories) {
      if (lastDate == null || m.date.isAfter(lastDate)) lastDate = m.date;
    }

    final categoryCounts = <String, int>{};
    for (final m in memories) {
      categoryCounts[m.category] = (categoryCounts[m.category] ?? 0) + 1;
    }

    // ── Las frases de la cinta ──
    //
    // Los mismos números que ya salen en las cajitas de abajo, dichos
    // seguidos. Una cajita con un número es un dato; la misma cifra en una
    // frase es un retrato. Con la cuenta a cero no hay retrato que hacer, y
    // la cinta no se dibuja.
    final List<String> tickerItems = <String>[];
    if (total > 0) {
      tickerItems.add(total == 1 ? '1 recuerdo' : '$total recuerdos');
      if (avgRating != null) {
        // Coma decimal, que esto se lee en español.
        final String nota = avgRating.toStringAsFixed(1).replaceAll('.', ',');
        tickerItems.add('nota media $nota');
      }
      if (returnPct != null) {
        tickerItems.add('volverías al ${returnPct.round()} %');
      }
      if (categoryCounts.isNotEmpty) {
        tickerItems.add(
          categoryCounts.length == 1
              ? '1 categoría'
              : '${categoryCounts.length} categorías',
        );
        // La categoría que más se repite. Es la línea con más gracia de las
        // cinco: no es una métrica, es algo que sabes de ti.
        final MapEntry<String, int> top = categoryCounts.entries.reduce(
          (MapEntry<String, int> a, MapEntry<String, int> b) =>
              b.value > a.value ? b : a,
        );
        if (top.value > 1) tickerItems.add('tu debilidad: ${top.key}');
      }
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context),

              // A todo el ancho a propósito: va FUERA del SliverPadding de
              // 20 de abajo. Una cinta que respeta los márgenes deja de ser
              // una cinta y pasa a ser otra tarjeta más.
              SliverToBoxAdapter(child: StatsTicker(items: tickerItems)),

              SliverPadding(
                // El 120 de antes era un número a ojo que en un iPhone con
                // isla dinámica se queda a dos píxeles de tapar la última
                // fila. Se deriva del alto real del dock más el área segura,
                // igual que en Inicio y en el Mapa.
                padding: EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  AppDock.height + 44 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Selector de persona ─────────────────────────────────
                    // Solo tiene sentido cuando hay MÁS DE UNA pestaña que
                    // elegir. En el diario personal —que es donde empieza
                    // todo el mundo— había una sola: un chip amarillo con tu
                    // nombre flotando dentro de una caja blanca del ancho de
                    // la pantalla. Parecía una fila de pestañas rota, o algo
                    // que no había terminado de cargar.
                    if (tabs.length > 1) ...<Widget>[
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
                    ],

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
                    const SizedBox(height: 28),

                    // ── Con quién compartes ─────────────────────────────────
                    // Lo primero después de "quién eres" es "con quién lo
                    // compartes". Los puntos y las notas medias vienen
                    // después: a alguien que acaba de entrar le salen todos a
                    // cero y no le dicen nada, mientras que la pregunta de
                    // quién ve su diario la tiene desde el primer minuto.
                    const ProfileGroupsSection(),
                    const SizedBox(height: 28),

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
                    //
                    // Con el diario vacío esto eran seis tarjetas a cero
                    // —"Recuerdos 0", "Volverías 0 %", "Categorías 0"— y una
                    // sección de categorías vacía debajo. Seis ceros no son
                    // un resumen de nada: son la primera pantalla que ve
                    // alguien que acaba de instalar la app, y no le dicen ni
                    // qué va a salir ahí ni cómo conseguirlo. Se sustituyen
                    // por lo único que hace falta decir.
                    if (total == 0)
                      _fadeSlide(
                        _bitacoraAnim,
                        _EmptyDiaryCard(
                          // Si el filtro por persona está activo y el grupo
                          // SÍ tiene recuerdos, lo que pasa no es que el
                          // diario esté vacío: es que esta persona no ha
                          // apuntado nada.
                          personName:
                              filterByPerson && allMemories.isNotEmpty
                              ? config.name
                              : null,
                          unattributed: unattributed,
                          loadFailed: diaryLoadFailed,
                          permissionDenied: diaryPermissionDenied,
                        ),
                      )
                    else ...<Widget>[
                    _fadeSlide(
                      _bitacoraAnim,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Antes estas cifras eran SIEMPRE las del grupo
                          // entero, así que cambiar de pestaña no cambiaba
                          // nada y la pantalla resultaba incomprensible.
                          // Ahora son de quien esté seleccionado, siempre que
                          // haya con qué distinguirlo.
                          _SectionTitle(
                            filterByPerson
                                ? '${config.name} en números'
                                : '$scopeLabel en números',
                          ),
                          if (unattributed > 0) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              unattributed == 1
                                  ? 'Hay 1 recuerdo anterior a que la app '
                                        'guardara quién escribe cada uno, y no '
                                        'se cuenta aquí.'
                                  : 'Hay $unattributed recuerdos anteriores a '
                                        'que la app guardara quién escribe '
                                        'cada uno, y no se cuentan aquí.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  // "Recuerdos" en todas partes. Esta
                                  // tarjeta lo llamaba "Registros", la cinta
                                  // de arriba "recuerdos" y las barras de
                                  // abajo "recuerdos": tres palabras y dos
                                  // vocabularios para el mismo número, en la
                                  // misma pantalla.
                                  title: 'Recuerdos',
                                  numericValue: total.toDouble(),
                                  valueBuilder: (v) => '${v.round()}',
                                  icon: Icons.book_rounded,
                                  bgColor: _kSlateBg,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: avgRating == null
                                    ? const _MetricCard(
                                        title: 'Nota media',
                                        value: '—',
                                        icon: Icons.star_half_rounded,
                                        bgColor: _kYellowBg,
                                      )
                                    : _MetricCard(
                                        title: 'Nota media',
                                        numericValue: avgRating,
                                        // Coma decimal, como la cinta de
                                        // arriba y como "Lo mejor que has
                                        // comido". Era el número más
                                        // grande de la pantalla y el único
                                        // de los tres que salía con punto:
                                        // "4.5" arriba y "4,5" al lado.
                                        valueBuilder: (v) => v
                                            .toStringAsFixed(1)
                                            .replaceAll('.', ','),
                                        icon: Icons.star_half_rounded,
                                        bgColor: _kYellowBg,
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: returnPct == null
                                    ? const _MetricCard(
                                        title: 'Volverías',
                                        value: '—',
                                        icon: Icons.thumb_up_rounded,
                                        bgColor: _kGreenBg,
                                      )
                                    : _MetricCard(
                                        title: 'Volverías',
                                        numericValue: returnPct,
                                        valueBuilder: (v) => '${v.round()}%',
                                        icon: Icons.thumb_up_rounded,
                                        bgColor: _kGreenBg,
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
                                  bgColor: _kPurpleBg,
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
                          _SectionTitle(
                            filterByPerson
                                ? 'Qué pide ${config.name}'
                                : 'Qué se come en $scopeLabel',
                          ),
                          const SizedBox(height: 14),
                          if (categoryCounts.isEmpty)
                            const _EmptyCategoriesPlaceholder()
                          else
                            // Ordenadas de más a menos.
                            //
                            // Se pintaban en el orden en que Firestore
                            // devolvía los recuerdos, así que la sección
                            // titulada "Qué se come aquí" podía empezar por
                            // la categoría con un solo registro y dejar la
                            // dominante la cuarta. Un ranking sin ordenar no
                            // responde a su propio título.
                            ...(categoryCounts.entries.toList()
                                  ..sort(
                                    (MapEntry<String, int> a,
                                            MapEntry<String, int> b) =>
                                        b.value.compareTo(a.value),
                                  ))
                                .map(
                              (e) => _CategoryBar(
                                category: e.key,
                                count: e.value,
                                total: total,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // ── Lo tuyo ─────────────────────────────────────────────
                    if (favouritePlace != null ||
                        bestMemory != null ||
                        lastDate != null) ...<Widget>[
                      const SizedBox(height: 28),
                      _fadeSlide(
                        _categoriesAnim,
                        _YourThingsCard(
                          favouritePlace: favouritePlace,
                          bestMemory: bestMemory,
                          lastDate: lastDate,
                          // Null significa "estos datos son tuyos de
                          // verdad", que es lo único que justifica el "Lo
                          // tuyo". Los cuatro casos:
                          //   · tu pestaña, con filtro → tuyos.
                          //   · pestaña de otro → suyos.
                          //   · sin filtro, en tu diario personal → tuyos
                          //     (ahí no hay nadie más).
                          //   · sin filtro, en un grupo → del grupo.
                          personName: filterByPerson
                              ? (config.uid == myUid ? null : config.name)
                              : (isPersonalGroup ? null : scopeLabel),
                        ),
                      ),
                    ],
                    ],
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
                            // 2,90:1 era el peor contraste de toda la app, y
                            // estaba en la única acción que no se puede
                            // deshacer. El coral sobre el rojo pálido no
                            // llega ni de lejos al 4,5:1; este mide 4,76:1
                            // sobre ese mismo fondo.
                            //
                            // El icono de 22 px tampoco llegaba al 3:1 que
                            // pide WCAG para elementos gráficos.
                            color: AppColors.error,
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
      'Tu perfil',
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
    // SIN flecha de volver: Perfil es una pestaña raíz del dock, no una
    // pantalla apilada. La flecha que había aquí prometía un "atrás" que no
    // existe — al pulsarla saltabas a Inicio, que no es de donde venías.
    automaticallyImplyLeading: false,
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: _kDark, width: AppBorder.normal),
              boxShadow: const [
                BoxShadow(color: _kDark, offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                semanticLabel: 'Logotipo de Palito de Sabores',
              ),
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
    decoration: _stickerCard(shadowOffset: const Offset(3, 3)),
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
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: AppAnimation.fast,
          constraints: const BoxConstraints(minWidth: 92, minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _kYellow : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: isSelected
                ? Border.all(color: _kDark, width: AppBorder.normal)
                : null,
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
                color: isSelected ? _kDark : AppColors.textSecondary,
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
    decoration: _stickerCard(radius: AppRadius.xl),
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
                  border: Border.all(color: _kDark, width: AppBorder.normal),
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
                    // El `Tooltip` de arriba pone etiqueta pero no rol: un
                    // `InkWell` pelado añade la acción al nodo semántico y no
                    // el indicador de "botón", así que el único sitio de la
                    // app para cambiar tu foto no se anunciaba como pulsable.
                    child: Semantics(
                      button: onTapImage != null,
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
                          // El icono SIEMPRE debajo, aunque haya foto.
                          //
                          // Antes el respaldo solo existía cuando no había
                          // `imagePath`, así que con una URL caducada, sin
                          // red o con las reglas de Storage denegando, el
                          // error se tragaba en silencio y quedaba un disco
                          // de color liso, sin nada dentro y sin forma de
                          // saber si tu foto se había perdido. Con la foto
                          // cargada, el icono queda tapado por ella y no se
                          // ve; sin ella, se ve.
                          child: Icon(
                            config.icon,
                            size: 34,
                            color: _kDark,
                          ),
                        ),
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
                        border: Border.all(color: _kDark, width: AppBorder.thin),
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
                      // Sin `visualDensity: VisualDensity.compact`.
                      //
                      // Las `constraints` pedían 44x44, pero `compact` resta
                      // cuatro píxeles por eje: el botón real medía 40x40,
                      // por debajo del mínimo táctil. Y es el único sitio
                      // desde el que arreglar un nombre que haya salido mal.
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
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
                  color: AppColors.textSecondary,
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
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Toca la foto para cambiarla',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Iba a 10 px y en cursiva: el texto más pequeño de
                        // la pantalla para la única pista de que ahí hay una
                        // acción, y en el estilo que peor se lee de todos.
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
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
          title: 'Puntos totales',
          value: hasError ? '—' : (pointsValue == null ? '…' : null),
          numericValue: hasError ? null : pointsValue?.toDouble(),
          valueBuilder: hasError ? null : (v) => '${v.round()}',
          icon: Icons.star_rounded,
          bgColor: _kYellowBg,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _MetricCard(
          // "Racha" no era una racha.
          //
          // El valor que llega aquí es `streak`, y Zona Gamer lo escribe en
          // Firestore como `streak: _decisionsCount`: es el total de
          // decisiones de la sesión, sin ninguna noción de días seguidos ni
          // de nada encadenado. La palabra prometía una constancia que la
          // app no mide, y que además no se puede romper — una racha que
          // solo sube no es una racha. Se llama por su nombre.
          title: 'Decisiones',
          value: hasError ? '—' : (streakValue == null ? '…' : null),
          numericValue: hasError ? null : streakValue?.toDouble(),
          valueBuilder: hasError ? null : (v) => '${v.round()}',
          icon: Icons.local_fire_department_rounded,
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

  /// Había también un `color` que las seis llamadas rellenaban con un color
  /// distinto y que `build` no leía nunca: el icono y la cifra son siempre
  /// navy. Se quita en vez de empezar a usarlo, porque usarlo era peor: el
  /// verde `#10B981` sobre su propio fondo mide 2,24:1, por debajo del 3:1
  /// que necesita un icono que significa algo.
  final Color bgColor;

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
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: _kDark, width: AppBorder.thin),
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
            color: AppColors.textSecondary,
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
      fontFeatures: AppTypography.tabular,
    );
    if (numericValue == null) {
      return Text(value!, style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: numericValue),
      duration: AppAnimation.reveal,
      curve: AppAnimation.enter,
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
        radius: AppRadius.md,
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
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: _kDark, width: AppBorder.thin),
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
          ProgressTrack(value: pct, color: _kYellow),
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
    decoration: _stickerCard(radius: AppRadius.md),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.category_outlined, size: 28, color: AppColors.textMuted),
        const SizedBox(height: 10),
        Text(
          'Cuando guardes recuerdos, aquí verás de qué comes más.',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
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
  Widget build(BuildContext context) => Semantics(
    // "Cerrar sesión" y "Eliminar cuenta" se leían como texto plano: un
    // `InkWell` pelado añade la acción al nodo pero no el rol de botón. Y
    // mientras la operación está en marcha, `onTap` pasa a null y la
    // etiqueta no cambiaba, así que el lector seguía ofreciendo una acción
    // muerta. Son las dos acciones más serias de la app.
    button: true,
    enabled: onTap != null,
    label: isLoading ? '$label. En curso…' : label,
    child: ExcludeSemantics(
    child: Container(
    decoration: _stickerCard(
      radius: AppRadius.md,
      shadowOffset: const Offset(3, 3),
      color: bgColor,
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
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

// ── Diario en blanco ─────────────────────────────────────────────────────────
/// Lo que ve alguien que acaba de instalar la app.
///
/// Antes veía seis tarjetas a cero y dos secciones vacías: la pantalla se
/// comportaba como si tuviera datos que enseñar y todos valieran cero. Una
/// cuenta a estrenar no es un caso raro ni un error — es por donde empieza
/// todo el mundo, y merece una pantalla escrita para ella.
/// La tarjeta de "aquí todavía no hay nada".
///
/// Tiene tres versiones porque "cero recuerdos" significa tres cosas
/// distintas, y antes las tres decían lo mismo:
///
///   · Tu diario está de verdad vacío → invitación a empezar.
///   · Estás mirando la pestaña de OTRA persona que aún no ha apuntado nada
///     → decírselo en tercera persona, sin botón de "apunta tu primer
///     plato", que en esa pestaña no tiene sentido.
///   · **El diario no se ha podido cargar** → no es que no haya nada: es que
///     no lo sabemos. A alguien con ochenta recuerdos y un fallo de red la
///     app le decía "Tu diario está en blanco" y le invitaba a empezar de
///     cero. `MemoryNotifier` ya publicaba `hasStreamError` e
///     `isPermissionDenied` y esta pantalla no los leía — las estadísticas
///     de Zona Gamer, dos bloques más arriba, sí lo hacen bien.
class _EmptyDiaryCard extends StatelessWidget {
  const _EmptyDiaryCard({
    this.personName,
    this.unattributed = 0,
    this.loadFailed = false,
    this.permissionDenied = false,
  });

  /// Nombre de la persona cuya pestaña se está mirando, si no eres tú.
  final String? personName;

  /// Recuerdos sin autor que quedan fuera del filtro por persona.
  final int unattributed;

  final bool loadFailed;
  final bool permissionDenied;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _stickerCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tintPrimary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: _kDark, width: AppBorder.thin),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 26,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _title,
            style: GoogleFonts.outfit(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _body,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          // El botón solo donde significa algo: en TU pestaña y con el
          // diario de verdad vacío. En la de otra persona no puedes apuntar
          // por ella, y si la carga ha fallado no hay nada que empezar.
          if (personName == null && !loadFailed) ...<Widget>[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: _kDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: const BorderSide(color: _kDark, width: AppBorder.normal),
                ),
              ),
              onPressed: () => context.push('/new-memory'),
              icon: const Icon(Icons.add_rounded, size: 22),
              label: Text(
                'Apuntar mi primer plato',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  String get _title {
    if (permissionDenied) return 'No tienes acceso a este diario';
    if (loadFailed) return 'No hemos podido cargar el diario';
    if (personName != null) return '$personName todavía no ha apuntado nada';
    return 'Tu diario está en blanco';
  }

  String get _body {
    if (permissionDenied) {
      return 'Puede que te hayan sacado del grupo, o que el diario ya no '
          'exista. Prueba a elegir otro diario desde Inicio.';
    }
    if (loadFailed) {
      return 'No es que esté vacío: es que no hemos podido leerlo. Comprueba '
          'tu conexión — lo que tengas guardado sigue ahí.';
    }
    if (personName != null) {
      final String extra = unattributed > 0
          ? ' Los $unattributed recuerdos anteriores a que la app guardara '
                'quién escribe cada uno no se cuentan en ninguna pestaña.'
          : '';
      return 'Cuando apunte su primer plato, aquí saldrán sus números.$extra';
    }
    return 'Apunta el primer plato y esta pantalla se escribe sola: tu nota '
        'media, a cuántos sitios volverías, qué es lo que más pides y en '
        'qué bar acabas siempre.';
  }
}

// ── Lo tuyo ──────────────────────────────────────────────────────────────────
/// Tres frases sacadas de campos que los recuerdos ya guardaban y que la
/// pantalla no leía: el bar al que vuelves, el plato que más te gustó y
/// cuánto hace que no apuntas nada.
///
/// Un porcentaje es un dato; "en La Bulería has comido seis veces" es algo
/// que sabes de ti. Cada fila se pinta solo si hay con qué: nada de huecos
/// con un guion.
class _YourThingsCard extends StatelessWidget {
  const _YourThingsCard({
    required this.favouritePlace,
    required this.bestMemory,
    required this.lastDate,
    this.personName,
  });

  final MapEntry<String, int>? favouritePlace;
  final MemoryModel? bestMemory;
  final DateTime? lastDate;

  /// De quién son estos datos, cuando no son tuyos.
  ///
  /// Los rótulos estaban clavados en segunda persona del singular —"Lo
  /// tuyo", "Tu sitio de siempre", "Lo mejor que has comido"— pero los datos
  /// salen de `memories`, que en la pestaña de un compañero son LOS SUYOS y
  /// en la pestaña del grupo son los de todos. O sea que la app te decía que
  /// *tú* has comido seis veces en un bar al que no has ido nunca.
  ///
  /// El resto de la pantalla ya conmutaba sus rótulos según la pestaña
  /// ("Qué pide Marta", "Marta en números"); esta tarjeta se quedó sin
  /// enterarse.
  final String? personName;

  bool get _isMine => personName == null;

  @override
  Widget build(BuildContext context) {
    final MemoryModel? best = bestMemory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionTitle(_isMine ? 'Lo tuyo' : 'Lo de $personName'),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: _stickerCard(radius: AppRadius.md),
          child: Column(
            children: <Widget>[
              if (favouritePlace != null)
                _YourThingRow(
                  icon: Icons.repeat_rounded,
                  label: _isMine
                      ? 'Tu sitio de siempre'
                      : 'Su sitio de siempre',
                  value: favouritePlace!.key,
                  detail: '${favouritePlace!.value} veces',
                ),
              if (best != null)
                _YourThingRow(
                  icon: Icons.emoji_events_rounded,
                  label: _isMine
                      ? 'Lo mejor que has comido'
                      : 'Lo mejor que ha comido',
                  value: best.title.trim().isEmpty
                      ? best.restaurantName
                      : best.title,
                  // Coma decimal: esto se lee en español.
                  detail: best.rating.toStringAsFixed(1).replaceAll('.', ','),
                ),
              if (lastDate != null)
                _YourThingRow(
                  icon: Icons.schedule_rounded,
                  label: _isMine ? 'Tu último apunte' : 'Su último apunte',
                  value: relativeDate(lastDate!),
                  detail: null,
                  isLast: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _YourThingRow extends StatelessWidget {
  const _YourThingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value${detail == null ? '' : ', $detail'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: isLast
              ? null
              : const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.tintMuted, width: 1.5),
                  ),
                ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 19, color: AppColors.textSecondary),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (detail != null) ...<Widget>[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tintPrimary,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: _kDark, width: 1),
                  ),
                  child: Text(
                    detail!,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: _kDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
