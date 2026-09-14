import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palito_3_0/core/providers/gamer_provider.dart';
import 'package:palito_3_0/core/providers/household_provider.dart';
import 'package:palito_3_0/core/utils/app_log.dart';
import 'package:palito_3_0/core/theme/components/neo_pressable.dart';
import '../gamer/zona_gamer_card.dart';
import 'data/gamer_content.dart';
import 'gamer_game_logic.dart';
import 'widgets/add_player_modal.dart';
import 'widgets/badges_modal.dart';
import 'widgets/challenge_outcome_modal.dart';
import 'widgets/mode_selector.dart';
import 'widgets/pro_modal.dart';

// ─── Constantes ──────────────────────────────────────────────────────────────
const _kDark = Color(0xFF0F172A);
const _kYellow = Color(0xFFFFD400);
const _kRed = Color(0xFFFF4D29);
const _kBg = Color(0xFFFFFDF5);

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

  // Los comensales por defecto se llamaban 'CeH' y 'Eme' — los nombres de
  // quienes desarrollaron la app. Cualquier persona que se descargara Palito
  // encontraba a dos desconocidos sentados a su mesa.
  List<Map<String, dynamic>> _players = [
    {
      'name': 'Tú',
      'icon': Icons.person_rounded,
      'color': _kYellow,
      'points': 0,
      'medals': 0,
      'uid': null,
    },
    {
      'name': 'Invitado',
      'icon': Icons.favorite_rounded,
      'color': _kRed,
      'points': 0,
      'medals': 0,
      'uid': null,
    },
    {
      'name': '🤖 Palito App',
      'icon': Icons.smart_toy_rounded,
      'color': _kDark,
      'points': 0,
      'medals': 0,
      'uid': null,
    },
  ];

  final _nameController = TextEditingController();
  final _customChallengeController = TextEditingController();

  Map<String, dynamic>? _selectedWinner;
  bool _isSpinning = false;
  int _highlightedIndex = -1;
  int _decisionsCount = 3;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _winnerScaleController;
  late Animation<double> _winnerScaleAnimation;

  final List<Map<String, String>> _history = [];
  final Map<String, int> _punishmentCounts = {};

  final List<Map<String, dynamic>> _achievements = buildGamerAchievements();

  final List<String> _palitoChallenges = buildPalitoChallenges();

  String? _currentChallenge;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _winnerScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _winnerScaleAnimation = CurvedAnimation(
      parent: _winnerScaleController,
      curve: Curves.elasticOut,
    );

    _loadPersistedData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customChallengeController.dispose();
    _pulseController.dispose();
    _winnerScaleController.dispose();
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

      final maxPts = _players.fold<int>(
        0,
        (m, p) => (p['points'] as int? ?? 0) > m ? p['points'] as int : m,
      );
      _checkAndUnlockAchievements(maxPts, _decisionsCount, fromLoad: true);

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
        final color = p['color'] is Color ? p['color'] as Color : Colors.grey;
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
    _checkAndUnlockAchievements(maxPts, _decisionsCount);
  }

  // ─── Logros ─────────────────────────────────────────────────────────────────
  void _checkAndUnlockAchievements(
    int maxPoints,
    int streak, {
    bool fromLoad = false,
  }) {
    final newlyUnlocked = <Map<String, dynamic>>[];

    for (final a in _achievements) {
      if (a['unlocked'] == true) continue;
      final met = GamerGameLogic.isAchievementMet(
        achievementId: a['id']?.toString() ?? '',
        maxPoints: maxPoints,
        streak: streak,
        decisionsCount: _decisionsCount,
      );
      if (met) {
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
    // el mismo Curves.easeOutBack ya usado en el resto de la UI para
    // mantener coherencia de vocabulario.
    showGeneralDialog(
      context: context,
      barrierLabel: 'Logro desbloqueado',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        // reverseCurve sin rebote: el rebote solo tiene sentido
        // "llegando" (el logro apareciendo), no "yéndose" — reproducir
        // el mismo easeOutBack al revés se ve como si el diálogo se
        // desinflara de forma rara.
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: curved.value, child: child),
        );
      },
      pageBuilder: (ctx, animation, secondaryAnimation) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _kDark, width: 2.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: _kDark, width: 2),
              ),
              child: Icon(icon, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Logro Desbloqueado!',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
  void _addPlayer() {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _players.add({
        'name': text,
        'icon': Icons.face_rounded,
        'color': Colors.primaries[Random().nextInt(Colors.primaries.length)],
        'points': 0,
        'medals': 0,
        'uid': null,
      });
      _nameController.clear();
    });

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
      if (_highlightedIndex >= _players.length) {
        _highlightedIndex = _players.isEmpty ? -1 : _players.length - 1;
      }
      if (_selectedWinner != null && _selectedWinner!['name'] == removedName) {
        _selectedWinner = null;
      }
    });
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
      _highlightedIndex = -1;
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
            borderRadius: BorderRadius.circular(16),
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
                  'Añadir Juicio Picante',
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
                hintText: 'Ej: Pagar la cuenta o hacer un baile...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
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
                    borderRadius: BorderRadius.circular(16),
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          BadgesModal(players: sorted, achievements: _achievements),
    );
  }

  void _showZonaGamerProModal() {
    showModalBottomSheet(
      context: context,
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          AddPlayerModal(controller: _nameController, onAdd: _addPlayer),
    );
  }

  // ─── Ruleta ──────────────────────────────────────────────────────────────────
  void _spinGame() {
    if (_players.isEmpty || _isSpinning || !mounted) return;

    setState(() {
      _isSpinning = true;
      _selectedWinner = null;
      _currentChallenge = null;
    });
    // El pulso solo mientras gira.
    _pulseController.repeat(reverse: true);
    HapticFeedback.heavyImpact();

    final random = Random();
    final totalSteps = 22 + random.nextInt(10);

    Future<void> runSpin() async {
      try {
        for (int step = 0; step <= totalSteps; step++) {
          if (!mounted || _players.isEmpty) return;
          setState(() {
            _highlightedIndex = (_highlightedIndex + 1) % _players.length;
          });
          HapticFeedback.selectionClick();
          if (step < totalSteps) {
            await Future.delayed(
              Duration(milliseconds: 35 + (pow(step, 1.35) * 3).toInt()),
            );
          }
        }

        if (!mounted || _players.isEmpty) return;

        final winnerIndex = _highlightedIndex % _players.length;
        final winner = _players[winnerIndex];
        final winnerName = winner['name']?.toString() ?? 'Comensal';
        int pointsWon = 0;
        String? eventDetail;

        setState(() {
          _isSpinning = false;
          _selectedWinner = winner;
          _decisionsCount++;

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
              ? '🍽️ ¡A $winnerName le toca elegir plato!'
              : '🔥 ¡Juicio Picante para $winnerName!',
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
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _kDark, width: 2),
              boxShadow: const [
                BoxShadow(color: _kDark, offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 16,
              color: _kDark,
            ),
          ),
          tooltip: 'Volver',
          onPressed: () => context.go('/'),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kDark, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo.png',
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
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kDark, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: _kDark, offset: Offset(2, 2), blurRadius: 0),
                ],
              ),
              child: const Icon(
                Icons.military_tech_rounded,
                color: Color(0xFFFF9F1C),
                size: 18,
              ),
            ),
            onPressed: _showBadgesModal,
            tooltip: 'Ver Puntuaciones e Insignias',
          ),
          Container(
            margin: const EdgeInsets.only(right: 16, left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kYellow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kDark, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 15,
                  color: Colors.black87,
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
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    scale: _selectedWinner != null
                        ? _winnerScaleAnimation
                        : const AlwaysStoppedAnimation(1.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: _selectedMode == 0 ? _kYellow : _kRed,
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
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              border: Border.all(color: _kDark, width: 1.5),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/icons/IconoRedondoTenedor.png',
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
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
                                      ? '⚡ Buscando comensal...'
                                      : (_selectedMode == 0
                                            ? '¡Gira para ver quién elige plato!'
                                            : '¡El juicio picante va a empezar!'))
                                : (_selectedMode == 0
                                      ? '🍽️ ¡Le toca elegir plato a:'
                                      : '🎉 ¡Veredicto Final:'),
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
                                      ? 'Ruleta de Platos'
                                      : 'Juicio Pendiente'),
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: _selectedMode == 0 ? _kDark : Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_selectedMode == 1 &&
                              _currentChallenge != null) ...[
                            const SizedBox(height: 14),
                            GestureDetector(
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
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _kDark, width: 1.5),
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
                                    ? 'Girando Ruleta...'
                                    : (_selectedMode == 0
                                          ? '¡Girar Ruleta!'
                                          : '¡Lanzar Juicio Picante!'),
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
                  const SizedBox(height: 28),

                  // ── Comensales ────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Comensales en la Mesa (${_players.length})',
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
                      fontSize: 11.5,
                      color: const Color(0xFF5A6572),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        final isHighlighted = index == _highlightedIndex;
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
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _toggleLinkedToMe(index),
                              onLongPress: () => _confirmRemovePlayer(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
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
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isHighlighted || isWinner
                                        ? const Color(0xFFFF9F1C)
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
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: playerColor
                                              .withValues(alpha: 0.2),
                                          child: Icon(
                                            player['icon'] as IconData,
                                            color: playerColor,
                                            size: 18,
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
                  const SizedBox(height: 28),

                  // ── Zona Gamer Pro ────────────────────────────────────────────
                  ZonaGamerCard(
                    title: 'Zona Gamer',
                    subtitle: 'Experiencia Pro',
                    backgroundColor: Colors.deepPurple,
                    onTap: _showZonaGamerProModal,
                  ),
                  const SizedBox(height: 28),

                  // ── Historial ─────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Historial de la Sesión',
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
                              color: Colors.red.shade400,
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
                        borderRadius: BorderRadius.circular(20),
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
                          color: const Color(0xFF5A6572),
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
                          borderRadius: BorderRadius.circular(16),
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
                                    color: Color(0xFFFF9F1C),
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
                                            color: Colors.grey.shade600,
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
                                color: const Color(0xFF5A6572),
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
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _showAddChallengeDialog,
                      icon: const Icon(
                        Icons.local_fire_department_rounded,
                        color: _kRed,
                        size: 18,
                      ),
                      label: Text(
                        'Añadir Juicio Picante al Vuelo',
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
