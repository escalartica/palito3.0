import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palito_3_0/core/models/memory_model.dart';
import 'package:palito_3_0/core/providers/gamer_provider.dart';
import 'package:palito_3_0/core/providers/memory_provider.dart';
import 'package:palito_3_0/core/providers/household_provider.dart';
import 'package:palito_3_0/core/utils/app_log.dart';
import 'package:palito_3_0/core/theme/components/app_dock.dart';
import 'package:palito_3_0/core/theme/components/neo_pressable.dart';
import '../gamer/zona_gamer_card.dart';
import 'data/gamer_content.dart';
import 'gamer_game_logic.dart';
import 'widgets/add_player_modal.dart';
import 'widgets/badges_modal.dart';
import 'widgets/how_to_play_sheet.dart';
import 'widgets/challenge_outcome_modal.dart';
import 'widgets/mode_selector.dart';
import 'widgets/pro_modal.dart';
import '../../core/theme/components/progress_track.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/theme/tokens/app_animation.dart';

// ─── Constantes ──────────────────────────────────────────────────────────────
const _kDark = AppColors.textPrimary;
const _kYellow = AppColors.primary;
const _kRed = AppColors.accent;
const _kBg = AppColors.background;

/// Naranja de insignias/historial. Acento secundario fuera de la paleta de
/// marca (navy/amarillo/coral), reservado a iconografía de logros. Se repite
/// en badges_modal.dart — si se necesitara en un tercer sitio, este es el
/// candidato a subir a AppColors como token compartido.
const _kBadgeOrange = Color(0xFFFF9F1C);

/// Colores de comensal, repartidos por turnos según el orden en que se
/// sientan. Deterministas a propósito: el mismo sitio en la mesa da siempre
/// el mismo color, y ninguno sale de la paleta de la app.
const List<Color> _kPlayerPalette = <Color>[
  AppColors.primary,
  AppColors.accent,
  AppColors.textPrimary,
  Color(0xFF1E7E45), // el verde de acierto
  Color(0xFF4E5765), // pizarra
];

// ════════════════════════════════════════════════════════════════════════════
// GamerPage
// ════════════════════════════════════════════════════════════════════════════
class GamerPage extends ConsumerStatefulWidget {
  const GamerPage({super.key});

  @override
  ConsumerState<GamerPage> createState() => _GamerPageState();
}

class _GamerPageState extends ConsumerState<GamerPage>
    with TickerProviderStateMixin {
  // 0: Ruleta Pro  |  1: Juicio Picante
  int _selectedMode = 0;

  // LA MESA EMPIEZA VACÍA.
  //
  // La versión publicada traía tres comensales inventados de fábrica —dos de
  // ellos, 'CeH' y 'Eme', los nombres de quienes desarrollaron la app—, así
  // que cualquier persona que se descargara Palito se encontraba a dos
  // desconocidos sentados a su mesa y un bot. Eso no es un detalle estético:
  // la primera impresión de la Zona Gamer era "esto no es mío".
  //
  // Ahora la lista nace vacía y `_loadPersistedData` siembra UNA sola fila,
  // la tuya, con tu nombre real y tu cuenta ya vinculada. A los demás los
  // añades tú, que es justo lo que ocurre en una mesa de verdad.
  List<Map<String, dynamic>> _players = <Map<String, dynamic>>[];

  final _nameController = TextEditingController();
  final _customChallengeController = TextEditingController();

  Map<String, dynamic>? _selectedWinner;
  bool _isSpinning = false;
  /// Qué comensal está encendido ahora mismo.
  ///
  /// Es un `ValueNotifier` y no un campo normal por una razón concreta: cada
  /// giro de la ruleta lo cambia **entre 22 y 32 veces seguidas**. Con un
  /// campo normal cada salto era un `setState`, y un `setState` aquí
  /// reconstruye la pantalla ENTERA de Zona Gamer: el panel de resultado, el
  /// podio, el historial, los logros, la tarjeta de introducción... dos mil
  /// líneas de widgets, treinta veces, mientras el dedo espera a ver quién
  /// sale. Era la causa del tirón que se nota al girar.
  ///
  /// Con el notificador, el único trozo que se vuelve a pintar es la fila de
  /// comensales, que es el único que cambia.
  final ValueNotifier<int> _highlightedIndex = ValueNotifier<int>(-1);
  // CERO. Estaba en 3.
  //
  // Era un valor de prueba que se quedó puesto, y `_loadPersistedData` solo
  // lo pisa si ya hay algo guardado en el móvil. O sea que cualquiera que se
  // bajaba la app y abría la Zona Gamer veía "3 decisiones" y "Racha 3" sin
  // haber jugado nada — y peor: `_checkAndUnlockAchievements` se llamaba con
  // ese 3, así que podía desbloquearle insignias que no se había ganado.
  int _decisionsCount = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _winnerScaleController;
  late Animation<double> _winnerScaleAnimation;

  final List<Map<String, String>> _history = [];
  final Map<String, int> _punishmentCounts = {};

  final List<Map<String, dynamic>> _achievements = buildGamerAchievements();

  final List<String> _palitoChallenges = buildPalitoChallenges();

  String? _currentChallenge;

  /// Lo que propone Palito cuando le toca a él.
  ///
  /// Un comensal llamado "Palito" es la propia app sentada a la mesa: cuando
  /// la ruleta le señala, en vez de mirar a nadie **elige el plato**. Hasta
  /// ahora ese comensal se podía añadir escribiendo el nombre a mano y la
  /// ruleta lo trataba como a cualquier otro: salía su nombre, y ahí acababa
  /// la gracia — la app anunciaba que le tocaba elegir a ella y no elegía
  /// nada.
  String? _palitoPick;

  /// La tarjeta de "qué es esto", cerrada a mano. No se guarda entre
  /// sesiones a propósito: si la cierras sin jugar y vuelves mañana sin
  /// haber jugado, sigues sin saber qué es esto.
  bool _introDismissed = false;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: AppAnimation.pulse,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: AppAnimation.inOut),
    );

    _winnerScaleController = AnimationController(
      vsync: this,
      duration: AppAnimation.slow,
    );
    _winnerScaleAnimation = CurvedAnimation(
      parent: _winnerScaleController,
      curve: AppAnimation.celebrate,
    );

    _loadPersistedData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customChallengeController.dispose();
    _pulseController.dispose();
    _winnerScaleController.dispose();
    _highlightedIndex.dispose();
    super.dispose();
  }

  // ─── Persistencia ──────────────────────────────────────────────────────────
  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final savedDecisions = prefs.getInt('palito_decisions_count');
      if (savedDecisions != null) {
        setState(() => _decisionsCount = savedDecisions);
      }

      final savedPlayersJson = prefs.getString('palito_players_data');
      if (savedPlayersJson != null) {
        final decoded = jsonDecode(savedPlayersJson);
        if (decoded is List) {
          final restored = decoded
              .whereType<Map>()
              .map<Map<String, dynamic>>(
                (item) => {
                  'name': item['name']?.toString() ?? 'Comensal',
                  'icon': _getIconData(
                    item['iconCode'] is int ? item['iconCode'] as int : 0,
                  ),
                  'color': Color(
                    item['colorValue'] is int
                        ? item['colorValue'] as int
                        : 0xFF9E9E9E,
                  ),
                  'points': item['points'] is int ? item['points'] as int : 0,
                  'medals': item['medals'] is int ? item['medals'] as int : 0,
                  // uid del miembro del grupo al que está vinculada esta
                  // fila local — ver _toggleLinkedToMe. Null si nadie la
                  // ha vinculado todavía (bots, invitados, o un jugador
                  // que aún no ha marcado "Soy yo").
                  'uid': item['uid']?.toString(),
                },
              )
              .toList();
          if (restored.isNotEmpty) setState(() => _players = restored);
        }
      }

      // Primera vez en esta Zona Gamer: te sentamos a ti y a nadie más.
      if (_players.isEmpty) {
        final String? myName = ref.read(currentDisplayNameProvider);
        final String? uid = ref.read(gamerServiceProvider).currentUid;
        setState(() {
          _players = <Map<String, dynamic>>[
            <String, dynamic>{
              'name': (myName != null && myName.trim().isNotEmpty)
                  ? myName.trim()
                  : 'Tú',
              'icon': Icons.person_rounded,
              'color': _kYellow,
              'points': 0,
              'medals': 0,
              'uid': uid,
            },
          ];
        });
      }

      final maxPts = _players.fold<int>(
        0,
        (m, p) => (p['points'] as int? ?? 0) > m ? p['points'] as int : m,
      );
      _checkAndUnlockAchievements(maxPts, fromLoad: true);

      // Ninguna fila por defecto traía `uid`, y `_syncGamerStats` solo
      // sincroniza la fila vinculada: los puntos NUNCA llegaban a la cuenta
      // y el Perfil mostraba 0 indefinidamente. La única pista de que había
      // que vincular era un texto gris de 11 px que nadie leía.
      _autoLinkMyPlayer();

      // Re-sincronizamos con Firestore al entrar a la pantalla para que
      // Profile quede alineado con los puntos locales reales, incluso si
      // el último guardado se hizo antes de corregir la sincronización.
      await _syncGamerStats();
    } catch (e, st) {
      AppLog.e('Error cargando datos del Gamer', e, st);
    }
  }

  /// Vincula automáticamente tu fila de la mesa la primera vez, para que tus
  /// puntos lleguen a tu cuenta sin que tengas que descubrir un gesto. Si ya
  /// hay una fila vinculada, no toca nada.
  void _autoLinkMyPlayer() {
    final String? uid = ref.read(gamerServiceProvider).currentUid;
    if (uid == null) return;

    final bool alreadyLinked = _players.any(
      (Map<String, dynamic> p) => p['uid'] == uid,
    );
    if (alreadyLinked) return;

    final String? myName = ref.read(currentDisplayNameProvider);

    int index = _players.indexWhere((Map<String, dynamic> p) {
      final String name = p['name']?.toString() ?? '';
      return name == 'Tú' ||
          (myName != null && name.toLowerCase() == myName.toLowerCase());
    });

    if (index == -1) return;

    setState(() {
      _players[index]['uid'] = uid;
      if (myName != null && myName.isNotEmpty) {
        _players[index]['name'] = myName;
      }
    });
  }

  Future<void> _savePersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('palito_decisions_count', _decisionsCount);

      final serialized = _players.map((p) {
        final icon = p['icon'] is IconData
            ? p['icon'] as IconData
            : Icons.face_rounded;
        final color = p['color'] is Color
            ? p['color'] as Color
            : AppColors.textMuted;
        return {
          'name': p['name']?.toString() ?? 'Comensal',
          'iconCode': icon.codePoint,
          'colorValue': color.toARGB32(),
          'points': p['points'] is int ? p['points'] as int : 0,
          'medals': p['medals'] is int ? p['medals'] as int : 0,
          'uid': p['uid'],
        };
      }).toList();

      await prefs.setString('palito_players_data', jsonEncode(serialized));
      await _syncGamerStats();
    } catch (e, st) {
      AppLog.e('Error guardando datos del Gamer', e, st);
    }
  }

  Future<void> _syncGamerStats() async {
    final service = ref.read(gamerServiceProvider);
    final uid = service.currentUid;

    // Solo se sincroniza la fila local vinculada explícitamente al uid del
    // usuario que ha iniciado sesión en este dispositivo (ver
    // _toggleLinkedToMe) — no todas las filas, y ya no por coincidencia de
    // nombre. El resto de comensales (bots, invitados, alguien que
    // todavía no ha marcado "Soy yo") solo existen localmente para la
    // partida: sus puntos no se pierden, simplemente no se guardan en la
    // cuenta de nadie hasta que alguien vincule esa fila.
    if (uid != null) {
      Map<String, dynamic>? myPlayer;
      for (final player in _players) {
        if (player['uid'] == uid) {
          myPlayer = player;
          break;
        }
      }

      if (myPlayer != null) {
        await service.updatePlayerStats(
          playerKey: uid,
          uid: uid,
          score: myPlayer['points'] as int? ?? 0,
          decisions: _decisionsCount,
          streak: _decisionsCount,
          unlockedChallenges: _palitoChallenges,
          displayName: myPlayer['name']?.toString() ?? 'Usuario',
        );
      }
    }

    final maxPts = _players.fold<int>(
      0,
      (m, p) => (p['points'] as int? ?? 0) > m ? p['points'] as int : m,
    );
    if (!mounted) return;
    _checkAndUnlockAchievements(maxPts);
  }

  /// Recalcula el progreso de los logros con el estado actual de la mesa.
  ///
  /// Hace falta porque hay logros que no dependen de girar —"Mesa llena"
  /// depende de cuánta gente hay sentada— y el progreso solo se recalculaba
  /// al arrancar y después de cada tirada. Sin esto, sentabas al quinto
  /// comensal y la tira seguía diciendo "te faltan 2" hasta la siguiente
  /// vuelta de ruleta.
  void _refreshAchievements() {
    final int maxPts = _players.fold<int>(
      0,
      (int m, Map<String, dynamic> p) =>
          (p['points'] as int? ?? 0) > m ? p['points'] as int : m,
    );
    _checkAndUnlockAchievements(maxPts);
  }

  /// El logro bloqueado que está más cerca de caer.
  ///
  /// "Más cerca" es el porcentaje de progreso, no cuántas unidades faltan:
  /// estar a 1 de 25 decisiones no es estar cerca, y estar a 1 de 2 sí.
  Map<String, dynamic>? get _nextAchievement {
    Map<String, dynamic>? best;
    double bestRatio = -1;

    for (final Map<String, dynamic> a in _achievements) {
      if (a['unlocked'] == true) continue;

      final int goal = a['goal'] as int? ?? 0;
      if (goal <= 0) continue;

      final double ratio = ((a['progress'] as int? ?? 0) / goal).clamp(0.0, 1.0);
      if (ratio > bestRatio) {
        bestRatio = ratio;
        best = a;
      }
    }

    return best;
  }

  // ─── Palito, el comensal que es la app ──────────────────────────────────────

  /// Si este comensal es la propia app.
  ///
  /// Se marca con `isBot` al añadirlo, pero también se reconoce por el
  /// nombre: quien ya se había inventado el truco escribiendo "Palito" o
  /// "Palito App" a mano —que es exactamente de donde salió esta idea— se
  /// encuentra con que ahora funciona, sin tener que borrar y volver a
  /// añadir.
  static bool _isPalito(Map<String, dynamic> player) {
    if (player['isBot'] == true) return true;

    final String name = (player['name']?.toString() ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');

    return name == 'palito' || name == 'palitoapp';
  }

  /// El plato que propone Palito, sacado del diario que tenéis abierto.
  ///
  /// No es aleatorio del todo: tira primero de los platos que puntuasteis
  /// con un 3,5 o más y a los que dijisteis que volveríais. Proponer a
  /// ciegas el sitio que os pareció regular sería un chiste que se gasta a
  /// la primera; proponer uno de los buenos es una recomendación de verdad,
  /// hecha con lo que vosotros mismos habéis escrito.
  String? _palitoSuggestion() {
    final List<MemoryModel> memories = ref.read(memoryProvider);
    if (memories.isEmpty) return null;

    final List<MemoryModel> favourites = memories
        .where((MemoryModel m) => m.rating >= 3.5 && m.wouldReturn)
        .toList();

    final List<MemoryModel> pool = favourites.isEmpty ? memories : favourites;
    final MemoryModel pick = pool[Random().nextInt(pool.length)];

    final String dish = pick.title.trim();
    final String place = pick.restaurantName.trim();

    if (place.isEmpty) return dish.isEmpty ? null : dish;
    if (dish.isEmpty || dish.toLowerCase() == place.toLowerCase()) return place;

    return '$dish · $place';
  }

  // ─── Logros ─────────────────────────────────────────────────────────────────
  /// El segundo parámetro era `int streak` y las dos llamadas le pasaban
  /// `_decisionsCount`: no había ninguna racha, era el total de decisiones
  /// con otro nombre. Se quita en vez de dejar un parámetro que promete un
  /// dato que la app no tiene.
  void _checkAndUnlockAchievements(int maxPoints, {bool fromLoad = false}) {
    final newlyUnlocked = <Map<String, dynamic>>[];

    // Señales de la mesa, calculadas una sola vez para los siete logros.
    final int playerCount = _players.length;
    final int playersWithPoints = _players
        .where((Map<String, dynamic> p) => (p['points'] as int? ?? 0) > 0)
        .length;
    final int maxMedals = _players.fold<int>(
      0,
      (int m, Map<String, dynamic> p) =>
          (p['medals'] as int? ?? 0) > m ? p['medals'] as int : m,
    );

    for (final a in _achievements) {
      final String id = a['id']?.toString() ?? '';

      final progress = GamerGameLogic.achievementProgress(
        achievementId: id,
        maxPoints: maxPoints,
        decisionsCount: _decisionsCount,
        playerCount: playerCount,
        playersWithPoints: playersWithPoints,
        maxMedals: maxMedals,
      );

      // El progreso se guarda siempre, conseguido o no: es lo que el panel
      // de insignias enseña debajo de cada logro bloqueado ("9 de 10") para
      // que se vea lo cerca que está.
      a['progress'] = progress.current;
      a['goal'] = progress.goal;

      if (a['unlocked'] == true) continue;

      if (progress.goal > 0 && progress.current >= progress.goal) {
        a['unlocked'] = true;
        if (!fromLoad) newlyUnlocked.add(a);
      }
    }

    if (!mounted || newlyUnlocked.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final a = newlyUnlocked.first;
      _showAchievementUnlockedDialog(
        a['title'] as String,
        a['desc'] as String,
        a['icon'] as IconData,
        a['color'] as Color,
      );
    });
  }

  void _showAchievementUnlockedDialog(
    String title,
    String desc,
    IconData icon,
    Color color,
  ) {
    // showGeneralDialog en vez de showDialog: el logro es el momento de
    // mayor carga emocional de la app (raro, "delight" en el sentido de
    // apple-design), así que se le da una entrada propia con rebote —a
    // diferencia del fade+scale genérico de Material— en vez de reusar
    // el mismo AppAnimation.pop ya usado en el resto de la UI para
    // mantener coherencia de vocabulario.
    showGeneralDialog(
      context: context,
      barrierLabel: 'Logro desbloqueado',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: AppAnimation.slow,
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        // reverseCurve sin rebote: el rebote solo tiene sentido
        // "llegando" (el logro apareciendo), no "yéndose" — reproducir
        // el mismo easeOutBack al revés se ve como si el diálogo se
        // desinflara de forma rara.
        final curved = CurvedAnimation(
          parent: animation,
          // `celebrate` existe exactamente para esto y no se estaba usando
          // en ningún sitio: se pasa de largo un 45 % y vuelve, una sola
          // vez. `pop` (14 %) es el rebote de un chip.
          curve: AppAnimation.celebrate,
          reverseCurve: AppAnimation.exit,
        );
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: curved.value, child: child),
        );
      },
      pageBuilder: (ctx, animation, secondaryAnimation) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: _kDark, width: 2.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Navy sobre el color del logro, nunca blanco.
            //
            // El icono iba en blanco y el título en el color del logro. Con
            // los colores viejos de Material colaba de milagro; desde que
            // los logros usan la paleta de la marca, un logro amarillo
            // pintaba un icono blanco sobre amarillo (1,4:1) y un título
            // amarillo sobre blanco (1,6:1). El momento más celebrado de la
            // app enseñaba un premio que no se leía.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: _kDark, width: 2),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: _kDark, offset: Offset(3, 3), blurRadius: 0),
                ],
              ),
              child: Icon(icon, size: 40, color: _kDark),
            ),
            const SizedBox(height: 18),
            Text(
              'LOGRO DESBLOQUEADO',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.15,
                letterSpacing: -0.4,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  // Amarillo de marca con texto navy (12,47:1), no el color
                  // del logro con texto blanco: ese blanco sobre amarillo
                  // medía 1,4:1.
                  backgroundColor: AppColors.primary,
                  foregroundColor: _kDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    side: const BorderSide(color: _kDark, width: 2),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  '¡Genial!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Iconos ─────────────────────────────────────────────────────────────────
  IconData _getIconData(int code) => switch (code) {
    0xe491 => Icons.person_rounded,
    0xe25d => Icons.favorite_rounded,
    0xf04e9 => Icons.smart_toy_rounded,
    0xe5f9 => Icons.star_rounded,
    0xe3a7 => Icons.local_fire_department_rounded,
    0xe0e9 => Icons.bolt_rounded,
    _ => Icons.face_rounded,
  };

  // ─── Jugadores ──────────────────────────────────────────────────────────────
  /// Sienta a la app a la mesa como un comensal más.
  void _addPalito() {
    if (_players.any(_isPalito)) return;

    setState(() {
      _players.add(<String, dynamic>{
        'name': 'Palito',
        'icon': Icons.restaurant_rounded,
        'color': AppColors.textPrimary,
        'points': 0,
        'medals': 0,
        'uid': null,
        'isBot': true,
      });
    });

    _refreshAchievements();
    Navigator.pop(context);
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar('Palito se sienta con vosotros');
    _savePersistedData();
  }

  void _addPlayer() {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _players.add({
        'name': text,
        'icon': Icons.face_rounded,
        // Antes: `Colors.primaries[Random().nextInt(...)]`. Un color de
        // Material al azar —lima, cian, índigo— en una app que es navy,
        // amarillo y coral, y distinto cada vez que se añadía a la misma
        // persona. Ahora se reparte por turnos de una paleta corta y
        // propia, así que dos comensales nunca coinciden hasta el quinto.
        'color': _kPlayerPalette[_players.length % _kPlayerPalette.length],
        'points': 0,
        'medals': 0,
        'uid': null,
      });
      _nameController.clear();
    });

    _refreshAchievements();
    Navigator.pop(context);
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar('¡$text añadido a la mesa!');
    _savePersistedData();
  }

  /// Confirma antes de quitar a alguien de la mesa. La pulsación larga
  /// borraba al instante, sin diálogo, sin deshacer y sin que en ninguna
  /// parte se dijera que ese gesto existía.
  Future<void> _confirmRemovePlayer(int index) async {
    if (index < 0 || index >= _players.length) return;
    if (_players.length <= 1) {
      _showFeedbackSnackbar('Debe quedar al menos un comensal');
      return;
    }

    final String name = _players[index]['name']?.toString() ?? 'Comensal';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('¿Quitar a $name de la mesa?'),
        content: const Text(
          'Sus puntos de esta sesión se pierden. Puedes volver a añadirlo '
          'cuando quieras.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _removePlayer(index);
  }

  void _removePlayer(int index) {
    if (index < 0 || index >= _players.length) return;
    if (_players.length <= 1) {
      _showFeedbackSnackbar('Debe quedar al menos un comensal');
      return;
    }
    final removedName = _players[index]['name']?.toString() ?? 'Comensal';
    setState(() {
      _players.removeAt(index);
      if (_highlightedIndex.value >= _players.length) {
        _highlightedIndex.value = _players.isEmpty
            ? -1
            : _players.length - 1;
      }
      if (_selectedWinner != null && _selectedWinner!['name'] == removedName) {
        _selectedWinner = null;
      }
    });
    _refreshAchievements();
    _savePersistedData();
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar('Comensal $removedName eliminado');
  }

  /// Vincula (o desvincula, si ya lo estaba) la fila [index] de la mesa
  /// local al uid del usuario que ha iniciado sesión en este dispositivo.
  /// Solo puede haber una fila vinculada a la vez por dispositivo — vincular
  /// otra desvincula automáticamente la anterior. Ver el comentario de
  /// _syncGamerStats: solo la fila vinculada llega a guardarse en la cuenta
  /// de alguien; el resto son invitados/bots puramente locales de la mesa.
  void _toggleLinkedToMe(int index) {
    final uid = ref.read(gamerServiceProvider).currentUid;
    if (uid == null) return;

    final name = _players[index]['name']?.toString() ?? 'Comensal';
    final wasLinked = _players[index]['uid'] == uid;

    setState(() {
      for (final player in _players) {
        player['uid'] = null;
      }
      if (!wasLinked) {
        _players[index]['uid'] = uid;
      }
    });

    _savePersistedData();
    HapticFeedback.selectionClick();
    _showFeedbackSnackbar(
      wasLinked
          ? 'Ya no vinculas tus puntos a "$name"'
          : 'Tus puntos ahora se guardan como "$name"',
    );
  }

  // ─── Sesión ──────────────────────────────────────────────────────────────────
  void _resetSessionScores() {
    setState(() {
      for (final p in _players) {
        p['points'] = 0;
        p['medals'] = 0;
      }
      _history.clear();
      _punishmentCounts.clear();
      _decisionsCount = 0;
      _selectedWinner = null;
      _currentChallenge = null;
      _palitoPick = null;
      _highlightedIndex.value = -1;
      // Los logros NO se vuelven a bloquear: un logro conseguido no debería
      // perderse al reiniciar la puntuación de una sesión de juego.
    });
    _savePersistedData();
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar('🔄 Puntuaciones de la sesión reiniciadas');
  }

  void _clearHistory() {
    if (_history.isEmpty && _punishmentCounts.isEmpty) return;
    setState(() {
      _history.clear();
      _punishmentCounts.clear();
    });
    _savePersistedData();
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar('Historial de sesión borrado');
  }

  void _showFeedbackSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: _kDark,
            ),
          ),
          backgroundColor: _kYellow,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ─── Resultado del reto ──────────────────────────────────────────────────────
  void _resolveChallengeResult(String playerName, bool succeeded) {
    if (!mounted || _players.isEmpty) return;
    final idx = _players.indexWhere((p) => p['name'] == playerName);
    if (idx == -1) return;

    final player = _players[idx];
    setState(() {
      if (succeeded) {
        player['points'] = (player['points'] ?? 0) + 15;
        player['medals'] = (player['medals'] ?? 0) + 1;
        _history.insert(0, {
          'winner': playerName,
          'detail': '✅ ¡Reto Superado (+15 pts / +1 medalla)!',
          'time': TimeOfDay.now().format(context),
        });
      } else {
        _history.insert(0, {
          'winner': playerName,
          'detail': '❌ Reto Fallido',
          'time': TimeOfDay.now().format(context),
        });
      }
      if (_history.length > 5) _history.removeLast();
    });

    _savePersistedData();
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar(
      succeeded
          ? '🎉 ¡+15 puntos para $playerName!'
          : '❌ Reto no superado por $playerName',
    );
  }

  // ─── Diálogos / Modales ──────────────────────────────────────────────────────
  void _showChallengeOutcomeDialog(String playerName, String challengeText) {
    showModalBottomSheet(
      context: context,
      // Sobre TODO, incluido el dock. Sin esto la hoja se abre dentro
      // del navegador del shell, y el dock —que vive en un Stack por
      // encima— le pasa por delante y le tapa el botón de confirmar.
      // Pasaba en el modal de añadir comensal: el botón "Añadir a la
      // Mesa" quedaba detrás de la barra de pestañas.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChallengeOutcomeModal(
        playerName: playerName,
        challengeText: challengeText,
        onOutcome: (succeeded) =>
            _resolveChallengeResult(playerName, succeeded),
      ),
    );
  }

  void _showAddChallengeDialog() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Añadir un juicio picante',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _kDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customChallengeController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ej: Pagar la cuenta o hacer un baile…',
                hintStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceWarm,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () {
                  final text = _customChallengeController.text.trim();
                  if (text.isEmpty) return;
                  final challenge = '🔥 $text';
                  setState(() {
                    _palitoChallenges.add(challenge);
                    _currentChallenge = challenge;
                  });
                  _customChallengeController.clear();
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  _showFeedbackSnackbar('Juicio picante añadido con éxito');
                  _savePersistedData();
                },
                child: Text(
                  'Guardar y Aplicar Juicio',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showBadgesModal() {
    final sorted = List<Map<String, dynamic>>.from(_players)
      ..sort(
        (a, b) =>
            (b['points'] as int? ?? 0).compareTo(a['points'] as int? ?? 0),
      );

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          BadgesModal(players: sorted, achievements: _achievements),
    );
  }

  void _showZonaGamerProModal() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProModal(
        players: _players,
        decisionsCount: _decisionsCount,
        historyCount: _history.length,
        onViewBadges: _showBadgesModal,
        onResetSession: _confirmResetSession,
      ),
    );
  }

  /// Reiniciar la sesión borraba puntos, medallas e historial al instante,
  /// sin confirmación y sin forma de deshacerlo.
  Future<void> _confirmResetSession() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('¿Reiniciar la sesión?'),
        content: const Text(
          'Se ponen a cero los puntos, las medallas y el historial de esta '
          'mesa. Los logros conseguidos se mantienen. No se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _resetSessionScores();
  }

  void _showAddPlayerDialog() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          AddPlayerModal(
            controller: _nameController,
            onAdd: _addPlayer,
            onAddPalito: _addPalito,
            palitoAlreadyPlaying: _players.any(_isPalito),
          ),
    );
  }

  // ─── Ruleta ──────────────────────────────────────────────────────────────────
  void _spinGame() {
    if (_isSpinning || !mounted) return;

    // Una ruleta con un solo comensal siempre sale tú. Antes el botón se
    // pulsaba igual y "elegía" al único que había, que es una forma tonta de
    // no hacer nada. Ahora dice qué falta.
    if (_players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textPrimary,
          content: const Text(
            'Añade a quien esté contigo en la mesa para poder jugar.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          action: SnackBarAction(
            label: 'Añadir',
            textColor: AppColors.primary,
            onPressed: _showAddPlayerDialog,
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSpinning = true;
      _selectedWinner = null;
      _currentChallenge = null;
      _palitoPick = null;
    });
    // El pulso solo mientras gira — y solo si el sistema no pide reducir el
    // movimiento. Un latido que no para nunca es de lo que peor sienta a
    // quien tiene vértigo o migraña, y es justo lo que esa opción del sistema
    // existe para evitar.
    if (!MediaQuery.disableAnimationsOf(context)) {
      _pulseController.repeat(reverse: true);
    }
    HapticFeedback.heavyImpact();

    final random = Random();
    final totalSteps = 22 + random.nextInt(10);

    Future<void> runSpin() async {
      try {
        for (int step = 0; step <= totalSteps; step++) {
          if (!mounted || _players.isEmpty) return;
          // Sin `setState`: el notificador avisa solo a la fila de
          // comensales. Ver el comentario de `_highlightedIndex`.
          _highlightedIndex.value =
              (_highlightedIndex.value + 1) % _players.length;
          HapticFeedback.selectionClick();
          if (step < totalSteps) {
            await Future.delayed(
              Duration(milliseconds: 35 + (pow(step, 1.35) * 3).toInt()),
            );
          }
        }

        if (!mounted || _players.isEmpty) return;

        final winnerIndex = _highlightedIndex.value % _players.length;
        final winner = _players[winnerIndex];
        final winnerName = winner['name']?.toString() ?? 'Comensal';
        int pointsWon = 0;
        String? eventDetail;

        setState(() {
          _isSpinning = false;
          _selectedWinner = winner;
          _decisionsCount++;

          // Si le toca a la app, la app elige.
          _palitoPick = (_selectedMode == 0 && _isPalito(winner))
              ? _palitoSuggestion()
              : null;

          final outcome = GamerGameLogic.computeSpinOutcome(
            selectedMode: _selectedMode,
            challenges: _palitoChallenges,
            random: random,
          );

          pointsWon = outcome.pointsAwarded;
          eventDetail = outcome.eventDetail;
          winner['points'] = (winner['points'] ?? 0) + pointsWon;

          if (outcome.awardsMedal) {
            winner['medals'] = (winner['medals'] ?? 0) + 1;
            _punishmentCounts[winnerName] =
                (_punishmentCounts[winnerName] ?? 0) + 1;
          }

          if (outcome.challenge != null) {
            _currentChallenge = outcome.challenge;
          }

          _history.insert(0, {
            'winner': winnerName,
            'detail': outcome.historyDetail,
            'time': TimeOfDay.now().format(context),
          });

          if (_history.length > 5) _history.removeLast();
        });

        _pulseController.stop();

        // Arrancar la animación AQUÍ, en el mismo turno que el setState que
        // hace visible el panel. Antes se llamaba después de `await
        // _savePersistedData()` y de una escritura de red: como
        // `Transform.scale` no colapsa el layout, el panel dejaba de pintarse
        // pero seguía ocupando su sitio — el hueco vertical enorme de Zona
        // Gamer.
        _winnerScaleController.forward(from: 0.0);
        HapticFeedback.vibrate();

        _showFeedbackSnackbar(
          _selectedMode == 0
              ? 'A $winnerName le toca elegir plato'
              : '🔥 ¡Juicio picante para $winnerName!',
        );

        await _savePersistedData();
        if (!mounted) return;

        try {
          await ref
              .read(gamerServiceProvider)
              .logGameSessionEvent(
                winnerName: winnerName,
                eventDetail: eventDetail ?? 'Evento Gamer',
                pointsAwarded: pointsWon,
              );
        } catch (e, st) {
          AppLog.e('Error sincronizando evento de ruleta', e, st);
        }
      } catch (e, st) {
        AppLog.e('Error durante el giro de la ruleta', e, st);
        if (!mounted) return;
        _pulseController.stop();
        setState(() {
          _isSpinning = false;
          _selectedWinner = null;
          _currentChallenge = null;
          _palitoPick = null;
        });
        _showFeedbackSnackbar(
          '⚠️ No se pudo completar el giro. Inténtalo de nuevo.',
        );
      }
    }

    runSpin();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        // SIN flecha de volver. Zona Gamer es una pestaña raíz del dock, no
        // una pantalla apilada: esa flecha prometía un "atrás" que no existe
        // y en realidad te mandaba a Inicio, que no es de donde venías. El
        // mismo fallo que tenía el Perfil.
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(color: _kDark, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: Image.asset(
                  'assets/images/logo.png',
                  semanticLabel: 'Logotipo de Palito de Sabores',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Zona Gamer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: _kDark,
                ),
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          // ── Las reglas, siempre a mano ──
          //
          // La explicación existía, pero se autodestruía: la tarjeta "¿Quién
          // elige hoy?" sale solo hasta la primera tirada y se puede cerrar
          // antes. Después no había forma de volver a verla, justo cuando
          // empiezas a tener las preguntas de verdad — de dónde salen los
          // puntos, qué son las medallas, qué hace Palito sentado a la mesa.
          //
          // Y esa tarjeta solo explicaba los tres modos: ni puntos, ni
          // medallas, ni cómo vincular tus puntos a tu cuenta.
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: _kDark, width: AppBorder.thin),
                boxShadow: const [
                  BoxShadow(color: _kDark, offset: Offset(2, 2), blurRadius: 0),
                ],
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: _kDark,
                size: 18,
              ),
            ),
            onPressed: () => showHowToPlaySheet(context),
            tooltip: 'Cómo se juega',
            // Sin `padding: zero`, cada `IconButton` se lleva 48 puntos de
            // ancho por sus márgenes internos. Con dos botones más la
            // pastilla de decisiones, al título no le quedaba sitio y se
            // cortaba en "Zona Gam…". El área táctil sigue siendo de 44,
            // que es el mínimo de Apple: lo que se quita es aire, no dedo.
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: _kDark, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: _kDark, offset: Offset(2, 2), blurRadius: 0),
                ],
              ),
              child: const Icon(
                Icons.military_tech_rounded,
                color: _kBadgeOrange,
                size: 18,
              ),
            ),
            onPressed: _showBadgesModal,
            // El botón decía "Puntuaciones e Insignias", la hoja que abre se
            // titula "El podio" y su sección se llama "Logros de la mesa":
            // tres nombres para lo mismo, y el del botón era el único que no
            // aparecía dentro. Quien no entiende la navegación de esta app no
            // es porque falten pantallas, es por esto.
            tooltip: 'Ver el podio y los logros',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          // Era una llama y un número, sin una palabra. Nadie sabía qué
          // contaba, y para un lector de pantalla era literalmente "3".
          Semantics(
            label: '$_decisionsCount decisiones tomadas en esta partida',
            child: Container(
            margin: const EdgeInsets.only(right: 16, left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kYellow,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: _kDark, width: 1.5),
            ),
            child: ExcludeSemantics(
              child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 15,
                  color: _kDark,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_decisionsCount',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: _kDark,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'decisiones',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SafeArea(
            child: SingleChildScrollView(
              // EL HUECO DE ABAJO LO MARCA EL DOCK, NO UN 60 A OJO.
              //
              // El dock flota por delante del contenido en su propio `Stack`
              // (ver main.dart) y ocupa 76 píxeles más el área segura del
              // móvil: en un iPhone con isla dinámica, unos 110. Con 60 de
              // hueco, la última tarjeta —la de "Resumen de la partida", que
              // es la que lleva insignias, historial y reiniciar— quedaba
              // medio tapada por el dock y no se podía terminar de leer ni
              // de pulsar. Se ve en cualquier captura que llegue al final de
              // la pantalla.
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                AppDock.height + 32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Qué es esto ───────────────────────────────────────────────
                  //
                  // Zona Gamer no se explicaba en ninguna parte. Entrabas y
                  // te encontrabas dos pestañas, una tarjeta amarilla que
                  // preguntaba "¿Quién elige?" y un botón de girar: se podía
                  // deducir con dos o tres toques, pero nadie tiene por qué
                  // deducir para qué sirve una pestaña de la barra.
                  //
                  // Sale solo hasta la primera tirada —`_decisionsCount` ya
                  // se guarda entre sesiones, así que no hace falta recordar
                  // nada más— y se puede cerrar antes. Quien ya juega no lo
                  // vuelve a ver.
                  if (_decisionsCount == 0 && !_introDismissed) ...<Widget>[
                    _GamerIntroCard(
                      onDismiss: () => setState(() => _introDismissed = true),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Selector de modo ──────────────────────────────────────────
                  ModeSelector(
                    selectedMode: _selectedMode,
                    onSelect: (m) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedMode = m);
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Panel resultado / ruleta ───────────────────────────────────
                  ScaleTransition(
                    // Desde el 90 %. El panel entero creciendo desde un punto
                    // no se leia como celebracion, se leia como un fallo de
                    // dibujado.
                    scale: _selectedWinner != null
                        ? Tween<double>(
                            begin: 0.90,
                            end: 1.0,
                          ).animate(_winnerScaleAnimation)
                        : const AlwaysStoppedAnimation<double>(1.0),
                    child: AnimatedContainer(
                      duration: AppAnimation.standard,
                      width: double.infinity,
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: _selectedMode == 0 ? _kYellow : _kRed,
                        // 32, no AppRadius.xl (24): coincide con el radio de
                        // las hojas inferiores de esta misma pantalla
                        // (badges/pro/reto/añadir comensal), que ya usan 32
                        // en su esquina superior. Es una superficie grande al
                        // mismo nivel visual que esas hojas, así que comparte
                        // su radio en vez del de "tarjeta". Pendiente:
                        // formalizar un sexto paso en AppRadius si el patrón
                        // se confirma en el resto de la app.
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: _kDark, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: _kDark,
                            offset: Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: _kDark, width: 1.5),
                            ),
                            child: ClipOval(
                              // `contain`, NO `cover`. El PNG mide 143x136:
                              // no es cuadrado. `cover` escala hasta llenar
                              // el círculo y RECORTA lo que sobra, así que el
                              // tenedor salía descentrado. `contain` lo
                              // muestra entero y centrado, que es lo que hay
                              // que hacer siempre con un icono de marca.
                              //
                              // Es decorativo: al lado hay texto que dice lo
                              // mismo, así que se excluye del lector de
                              // pantalla en vez de repetirlo.
                              child: Image.asset(
                                'assets/icons/IconoRedondoTenedor.png',
                                width: 52,
                                height: 52,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                excludeFromSemantics: true,
                                errorBuilder: (_, _, _) => Container(
                                  width: 52,
                                  height: 52,
                                  color: Colors.white,
                                  child: const Icon(
                                    Icons.restaurant,
                                    color: _kDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _selectedWinner == null
                                ? (_isSpinning
                                      ? 'Buscando comensal…'
                                      : (_players.length < 2
                                            ? 'Todavía no hay con quién jugar'
                                            : 'Sois ${_players.length} en la mesa'))
                                : (_selectedMode == 0
                                      ? (_isPalito(_selectedWinner!)
                                            ? 'Palito elige por vosotros'
                                            : 'Le toca elegir plato a')
                                      : 'Veredicto final'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _selectedMode == 0
                                  ? _kDark.withValues(alpha: 0.8)
                                  : Colors.white.withValues(alpha: 0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedWinner != null
                                ? _selectedWinner!['name'] as String
                                : (_selectedMode == 0
                                      // El titular repetía la línea de
                                      // arriba ("¡Gira para ver quién elige
                                      // plato!" / "Ruleta de Platos"): dos
                                      // frases para decir lo mismo, en el
                                      // elemento más grande de la pantalla.
                                      // Ahora arriba va cuántos sois y aquí
                                      // la pregunta que el juego responde.
                                      // Con un solo comensal, el titular
                                      // preguntaba "¿Quién elige?" encima de
                                      // un "¿quién está en la mesa?": dos
                                      // preguntas apiladas, y la grande sin
                                      // respuesta posible. El elemento mayor
                                      // de la pantalla dice ahora qué hacer.
                                      ? (_players.length < 2
                                            ? 'Añade a los comensales'
                                            : '¿Quién elige?')
                                      : (_players.length < 2
                                            ? 'Añade a los comensales'
                                            : '¿A quién le cae?')),
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: _selectedMode == 0 ? _kDark : Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          // LO QUE ELIGE PALITO.
                          //
                          // Si el comensal que ha salido es la app, aquí va
                          // el plato, sacado de vuestro propio diario. Sin
                          // esto, la ruleta anunciaba que elegía la app y no
                          // elegía nada: el chiste se quedaba a medias.
                          if (_selectedWinner != null &&
                              _isPalito(_selectedWinner!) &&
                              _selectedMode == 0) ...<Widget>[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(color: _kDark, width: 2),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    _palitoPick == null
                                        ? 'TODAVÍA NO OS CONOZCO'
                                        : 'ESTA NOCHE, ESTO',
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _palitoPick ??
                                        'Apuntad algún plato y os propongo '
                                            'uno de los vuestros',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: _palitoPick == null ? 14 : 17,
                                      height: 1.25,
                                      fontWeight: FontWeight.w800,
                                      color: _kDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_selectedMode == 1 &&
                              _currentChallenge != null) ...[
                            const SizedBox(height: 14),
                            // La tarjeta dice "toca aquí" con el dedo
                            // dibujado y no era un botón para el lector de
                            // pantalla: un `GestureDetector` pelado no tiene
                            // rol, así que VoiceOver leía el reto y se
                            // callaba lo único que hay que hacer con él.
                            Semantics(
                              button: true,
                              label:
                                  'Reto: ${_currentChallenge!}. '
                                  'Tocar para evaluarlo.',
                              child: ExcludeSemantics(
                              child: GestureDetector(
                              onTap: () {
                                if (_selectedWinner != null) {
                                  _showChallengeOutcomeDialog(
                                    _selectedWinner!['name'] as String,
                                    _currentChallenge!,
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(
                                    color: _kDark,
                                    width: AppBorder.thin,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: _kDark,
                                      offset: Offset(3, 3),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _currentChallenge!,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _kDark,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '👆 Toca aquí para evaluar el reto',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _kRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Botón girar ───────────────────────────────────────────────
                  ScaleTransition(
                    scale: _isSpinning
                        ? _pulseAnimation
                        : const AlwaysStoppedAnimation(1.0),
                    child: SizedBox(
                      width: double.infinity,
                      // Altura mínima, no fija: con el texto del sistema ampliado
                      // el botón principal reventaba con overflow horizontal.
                      height:
                          56 *
                          MediaQuery.textScalerOf(
                            context,
                          ).scale(1).clamp(1.0, 1.4).toDouble(),
                      child: NeoPressable(
                        onTap: _isSpinning ? null : _spinGame,
                        color: _kDark,
                        borderWidth: 2,
                        shadowOffset: const Offset(4, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.casino_rounded,
                              size: 22,
                              color: _kYellow,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _isSpinning
                                    ? 'Girando la ruleta…'
                                    // En español solo va en mayúscula la
                                    // primera palabra. "Girar Ruleta" y
                                    // "Juicio Picante" son mayúsculas a la
                                    // inglesa: en un botón español se leen
                                    // como un error, no como énfasis.
                                    : (_selectedMode == 0
                                          ? '¡Girar la ruleta!'
                                          : '¡Lanzar el juicio picante!'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ── El siguiente logro ────────────────────────────────────────
                  //
                  // Lo que faltaba para que esto fuera un juego y no un
                  // sorteo. Los logros existían pero solo se veían entrando
                  // en un panel, dentro de otro panel: quien no los buscaba
                  // no sabía que estaban, y quien los veía se encontraba una
                  // lista de candados sin decir cuánto faltaba.
                  //
                  // Aquí sale uno solo —el más cerca de conseguirse— con su
                  // barra, justo debajo del botón de girar. "Te falta 1" al
                  // lado del botón es la diferencia entre una tirada y otra
                  // más.
                  if (_nextAchievement != null) ...<Widget>[
                    const SizedBox(height: 18),
                    _NextAchievementStrip(
                      achievement: _nextAchievement!,
                      onTap: _showBadgesModal,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Comensales ────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Comensales en la mesa (${_players.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _kDark,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddPlayerDialog,
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: _kRed,
                        ),
                        label: Text(
                          'Añadir',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: _kRed,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Toca tu comensal para vincular tus puntos a tu cuenta',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Solo esta fila se vuelve a pintar en cada salto de la
                  // ruleta. Ver el comentario de `_highlightedIndex`.
                  ValueListenableBuilder<int>(
                    valueListenable: _highlightedIndex,
                    builder:
                        (
                          BuildContext context,
                          int highlighted,
                          Widget? _,
                        ) =>
                    SizedBox(
                      // 94 fijos no dan para el nombre con el texto ampliado.
                      height:
                          94 *
                          MediaQuery.textScalerOf(
                            context,
                          ).scale(1).clamp(1.0, 1.4).toDouble(),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _players.length,
                        itemBuilder: (context, index) {
                          final player = _players[index];
                          final isHighlighted = index == highlighted;
                          final isWinner =
                              _selectedWinner != null &&
                              _selectedWinner!['name'] == player['name'];
                          final playerColor = player['color'] as Color;
                          final myUid = ref.read(gamerServiceProvider).currentUid;
                          final isLinkedToMe =
                              myUid != null && player['uid'] == myUid;

                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                onTap: () => _toggleLinkedToMe(index),
                                onLongPress: () => _confirmRemovePlayer(index),
                                child: AnimatedContainer(
                                  duration: AppAnimation.fast,
                                  width: 76,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    // Relleno sólido, no alpha-blend: el mismo
                                    // patrón de "seleccionado" que tabs y chips
                                    // en el resto de la app — garantiza que el
                                    // texto oscuro siempre tenga contraste
                                    // suficiente, sin depender de qué haya debajo.
                                    color: isHighlighted
                                        ? _kYellow
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    border: Border.all(
                                      color: isHighlighted || isWinner
                                          ? _kBadgeOrange
                                          : _kDark,
                                      width: isHighlighted || isWinner ? 2 : 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: _kDark,
                                        offset: Offset(2, 2),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          // Cuando la tarjeta está
                                          // seleccionada su fondo es amarillo,
                                          // y el círculo del comensal se
                                          // pintaba con SU color al 20 % y el
                                          // icono en ese mismo color. Para
                                          // quien tuviera el amarillo de marca
                                          // —el primer comensal de la mesa,
                                          // siempre— el resultado era amarillo
                                          // sobre amarillo: el icono
                                          // desaparecía justo en el momento en
                                          // que la ruleta lo elegía, que es
                                          // cuando más hay que verlo.
                                          //
                                          // Seleccionado: círculo blanco y
                                          // icono navy, con borde. Contraste
                                          // garantizado sea cual sea el color
                                          // del comensal.
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: isHighlighted
                                                ? Colors.white
                                                : playerColor.withValues(
                                                    alpha: 0.2,
                                                  ),
                                            child: Container(
                                              decoration: isHighlighted
                                                  ? const BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border:
                                                          Border.fromBorderSide(
                                                            BorderSide(
                                                              color: _kDark,
                                                              width: 1.5,
                                                            ),
                                                          ),
                                                    )
                                                  : null,
                                              alignment: Alignment.center,
                                              child: Icon(
                                                player['icon'] as IconData,
                                                color: isHighlighted
                                                    ? _kDark
                                                    : playerColor,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                          if (isLinkedToMe)
                                            Positioned(
                                              right: -2,
                                              bottom: -2,
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: const BoxDecoration(
                                                  color: _kYellow,
                                                  shape: BoxShape.circle,
                                                  border: Border.fromBorderSide(
                                                    BorderSide(
                                                      color: _kDark,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.check_rounded,
                                                  size: 10,
                                                  color: _kDark,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        player['name'] as String,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: _kDark,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Zona Gamer Pro ────────────────────────────────────────────
                  // Ponía "Zona Gamer / Experiencia Pro" —el nombre de la
                  // pantalla en la que ya estás— en un morado que no aparece
                  // en ningún otro sitio de la app. Lo que abre de verdad es
                  // el resumen de la partida: cuántos sois, cuántas
                  // decisiones lleváis, el historial, las insignias y el
                  // botón de empezar de cero. Ahora lo dice.
                  ZonaGamerCard(
                    title: 'Resumen de la partida',
                    subtitle: 'Insignias, historial y empezar de cero',
                    backgroundColor: _kDark,
                    onTap: _showZonaGamerProModal,
                  ),
                  const SizedBox(height: 28),

                  // ── Historial ─────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Historial de la sesión',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kDark,
                        ),
                      ),
                      if (_history.isNotEmpty)
                        TextButton(
                          onPressed: _clearHistory,
                          child: Text(
                            'Limpiar',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              // `Colors.red.shade400` medía 3,49:1 sobre
                              // blanco: por debajo del 4,5:1 que pide un
                              // texto. El rojo de error de la app mide 5,44.
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_history.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: _kDark, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: _kDark,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        'Todavía no hay registros en esta sesión. ¡Gira la ruleta para empezar!',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ..._history.map(
                      (record) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: _kDark, width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: _kDark,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.history_rounded,
                                    size: 18,
                                    color: _kBadgeOrange,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          record['winner']!,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: _kDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          record['detail']!,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              record['time']!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ── Añadir reto ───────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kRed.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      onPressed: _showAddChallengeDialog,
                      icon: const Icon(
                        Icons.local_fire_department_rounded,
                        color: _kRed,
                        size: 18,
                      ),
                      label: Text(
                        'Añadir un juicio picante al vuelo',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _kRed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La tira del siguiente logro: qué es, cuánto llevas y cuánto falta.
class _NextAchievementStrip extends StatelessWidget {
  const _NextAchievementStrip({
    required this.achievement,
    required this.onTap,
  });

  final Map<String, dynamic> achievement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String title = achievement['title']?.toString() ?? '';
    final int goal = achievement['goal'] as int? ?? 1;
    final int current = (achievement['progress'] as int? ?? 0).clamp(0, goal);
    final int missing = goal - current;

    return Semantics(
      button: true,
      label:
          'Siguiente logro: $title. Llevas $current de $goal. '
          'Toca para ver todos los logros',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: _kDark, width: AppBorder.thin),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    achievement['icon'] as IconData? ?? Icons.star_rounded,
                    size: 22,
                    color: _kDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // ── Decía "Mesa llena · te faltan 4" ──
                        //
                        // Sin este rótulo, la tira afirma un hecho y lo
                        // desmiente en la misma línea: "Mesa llena" a la
                        // izquierda y "te faltan 4" a la derecha. Visto en el
                        // simulador y hay que leerlo dos veces para entender
                        // que "Mesa llena" es el NOMBRE de un logro que
                        // todavía no tienes, no el estado de tu mesa.
                        //
                        // Lo llamativo: la etiqueta de VoiceOver de esta
                        // misma tira ya dice "Siguiente logro: ...". Quien la
                        // escuchaba entendía la pantalla mejor que quien la
                        // veía.
                        Text(
                          'PRÓXIMO LOGRO',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: _kDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              missing == 1 ? 'te falta 1' : 'te faltan $missing',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        ProgressTrack(
                          value: current / goal,
                          color: AppColors.primary,
                          height: 9,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Qué es Zona Gamer, en cuatro líneas y una vez.
class _GamerIntroCard extends StatelessWidget {
  const _GamerIntroCard({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _kDark, width: AppBorder.normal),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: _kDark, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  '¿Quién elige hoy?',
                  style: GoogleFonts.outfit(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: _kDark,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Cerrar la explicación',
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: onDismiss,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Para la discusión de todas las comidas. Sentáis a la mesa a '
            'quien esté, giráis, y la ruleta decide.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          const _IntroLine(
            icon: Icons.casino_rounded,
            title: 'Ruleta',
            text: 'Señala a quién le toca elegir plato.',
          ),
          const SizedBox(height: 10),
          const _IntroLine(
            icon: Icons.local_fire_department_rounded,
            title: 'Juicio picante',
            text: 'Al señalado le cae un reto. Vale medalla.',
          ),
          const SizedBox(height: 10),
          const _IntroLine(
            icon: Icons.restaurant_rounded,
            title: 'Palito',
            text: 'Siéntalo a la mesa y, si le toca, elige él '
                'de vuestro diario.',
          ),
          const SizedBox(height: 6),
          // Antes de que esta tarjeta desaparezca para siempre, que diga
          // dónde vive la explicación completa. Si no, quien la cierra se
          // queda sin ayuda y sin saber que había más.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showHowToPlaySheet(context),
              icon: const Icon(Icons.help_outline_rounded, size: 18),
              label: const Text('Ver las reglas completas'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroLine extends StatelessWidget {
  const _IntroLine({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.tintPrimary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: _kDark, width: 1.5),
          ),
          child: Icon(icon, size: 16, color: _kDark),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text.rich(
              TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text: '$title. ',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: _kDark,
                    ),
                  ),
                  TextSpan(
                    text: text,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
