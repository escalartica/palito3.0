import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palito_3_0/core/providers/gamer_provider.dart';
import 'package:palito_3_0/core/theme/components/neo_pressable.dart';
import '../gamer/zona_gamer_card.dart';

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

  List<Map<String, dynamic>> _players = [
    {
      'name': 'CeH',
      'icon': Icons.person_rounded,
      'color': _kYellow,
      'points': 0,
      'medals': 0,
    },
    {
      'name': 'Eme',
      'icon': Icons.favorite_rounded,
      'color': _kRed,
      'points': 0,
      'medals': 0,
    },
    {
      'name': '🤖 Palito App',
      'icon': Icons.smart_toy_rounded,
      'color': _kDark,
      'points': 0,
      'medals': 0,
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

  final List<Map<String, dynamic>> _achievements = [
    {
      'id': 'king_flavor',
      'title': 'Rey del Sabor',
      'desc': 'Alcanzar los 40 puntos o más en la sesión.',
      'icon': Icons.workspace_premium_rounded,
      'color': Colors.amber,
      'unlocked': false,
    },
    {
      'id': 'spicy_streak',
      'title': 'Racha Picante',
      'desc': 'Acumular una racha de más de 10 decisiones.',
      'icon': Icons.local_fire_department_rounded,
      'color': Colors.deepOrange,
      'unlocked': false,
    },
    {
      'id': 'soul_table',
      'title': 'Alma de la Mesa',
      'desc': 'Interactuar con todos los comensales.',
      'icon': Icons.groups_rounded,
      'color': Colors.purple,
      'unlocked': false,
    },
  ];

  final List<String> _palitoChallenges = [
    '🏆 ¡Pide un plato sorpresa!',
    '💸 ¡Toca pagar la primera ronda de bebidas de toda la mesa!',
    '🍰 ¡Elige el postre a ciegas sin mirar la carta y acierta los ingredientes!',
    '🔍 ¡Haz una cata técnica obligatoria al plato del compañero de al lado!',
    '🎙️ ¡Inaugura el banquete haciendo un brindis épico dedicado a Palito!',
    '🌶️ ¡Prueba el bocado más picante o exótico disponible en la comanda!',
    '🥔 ¡Encuentra la mejor patata de toda la mesa y proclámala oficialmente!',
    '🕵️ ¡Adivina el ingrediente secreto de un plato sin preguntar a nadie!',
    '🤫 ¡Elige un plato para compartir sin decirle a nadie qué es!',
    '📸 ¡Haz la foto gastronómica más artística de la noche!',
    '👃 ¡Huele un plato con los ojos cerrados e intenta adivinar qué lleva!',
    '🔄 ¡Intercambia tu plato con alguien durante un bocado!',
    '🎯 ¡Pide algo que jamás hayas probado antes!',
    '🧠 ¡Describe tu plato sin mencionar ninguno de sus ingredientes!',
    '🎤 ¡Presenta el siguiente plato como si fueras el chef de un restaurante Michelin!',
    '🧂 ¡Adivina si el plato necesita más sal antes de probarlo!',
    '🗺️ ¡Busca en el menú un plato típico de una región que nunca hayas visitado!',
    '💎 ¡Declara cuál es el bocado más valioso de la mesa y explica por qué!',
    '🔥 ¡Encuentra el plato con más personalidad de toda la comanda!',
    '❤️ ¡Regala tu mejor bocado a la persona que elijas!',
    '🎭 ¡Describe tu plato usando solo tres palabras dramáticas!',
    '📖 ¡Inventa una historia de 20 segundos sobre el origen de tu plato!',
    '🧐 ¡Analiza un plato como si fueras un detective buscando pistas!',
    '🥇 ¡Elige al campeón absoluto de la mesa y corona tu Plato de la Noche!',
    '🎰 ¡Deja que Palito decida tu próximo bocado!',
    '🚨 ¡ALERTA PALITO! Tienes que probar el plato que menos te apetezca!',
  ];

  String? _currentChallenge;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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

      // Re-sincronizamos con Firestore al entrar a la pantalla para que
      // Profile quede alineado con los puntos locales reales, incluso si
      // el último guardado se hizo antes de corregir la sincronización.
      await _syncGamerStats();
    } catch (e, st) {
      debugPrint('Error cargando datos del Gamer: $e');
      debugPrintStack(stackTrace: st);
    }
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
        };
      }).toList();

      await prefs.setString('palito_players_data', jsonEncode(serialized));
      await _syncGamerStats();
    } catch (e, st) {
      debugPrint('Error guardando datos y sincronizando con Firestore: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> _syncGamerStats() async {
    final service = ref.read(gamerServiceProvider);
    final uid = service.currentUid;

    // Sincronizamos la puntuación de CADA jugador por separado (no la suma
    // de la mesa), para que Profile lea el mismo número que Zona Gamer
    // muestra para Eme y para CeH individualmente.
    if (uid != null) {
      for (final player in _players) {
        final name = player['name']?.toString().trim().toLowerCase() ?? '';
        final String playerKey;
        if (name == 'eme') {
          playerKey = 'eme';
        } else if (name == 'ceh') {
          playerKey = 'ceh';
        } else {
          continue;
        }

        await service.updatePlayerStats(
          playerKey: playerKey,
          uid: uid,
          score: player['points'] as int? ?? 0,
          decisions: _decisionsCount,
          streak: _decisionsCount,
          unlockedChallenges: _palitoChallenges,
          displayName: player['name']?.toString() ?? playerKey,
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
      final met = switch (a['id']) {
        'king_flavor' => maxPoints >= 40,
        'spicy_streak' => streak >= 10,
        'soul_table' => _decisionsCount >= 5,
        _ => false,
      };
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
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
      });
      _nameController.clear();
    });

    Navigator.pop(context);
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar('¡$text añadido a la mesa!');
    _savePersistedData();
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
      for (final a in _achievements) {
        a['unlocked'] = false;
      }
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
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFFFF8EE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '🎯 Evaluar Juicio de $playerName',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  challengeText,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _kDark,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _resolveChallengeResult(playerName, false);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        '❌ No Superado',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _resolveChallengeResult(playerName, true);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        '✅ ¡Superado!',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.military_tech_rounded,
                          color: Color(0xFFFF9F1C),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Insignias y Logros de la Mesa',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _kDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Ranking ordenado por puntuación, medallas e insignias desbloqueadas.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              ...sorted.map((player) {
                final playerColor = player['color'] as Color;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: playerColor.withValues(
                                alpha: 0.2,
                              ),
                              child: Icon(
                                player['icon'] as IconData,
                                color: playerColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                player['name'] as String,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _kDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _BadgePill(
                            text: '🏆 ${player['medals']} medallas',
                            bgColor: _kYellow.withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 6),
                          _BadgePill(
                            text: '⭐ ${player['points']} pts',
                            bgColor: _kRed.withValues(alpha: 0.15),
                            textColor: _kRed,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text(
                'Logros Especiales Globales',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kDark,
                ),
              ),
              const SizedBox(height: 10),
              ..._achievements.map((a) {
                final unlocked = a['unlocked'] == true;
                final color = a['color'] as Color;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? color.withValues(alpha: 0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: unlocked
                          ? color.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        a['icon'] as IconData,
                        color: unlocked ? color : Colors.grey.shade400,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a['title'] as String,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: unlocked ? _kDark : Colors.grey.shade500,
                              ),
                            ),
                            Text(
                              a['desc'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        unlocked
                            ? Icons.check_circle_rounded
                            : Icons.lock_rounded,
                        color: unlocked ? color : Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showZonaGamerProModal() {
    final totalPts = _players.fold<int>(
      0,
      (s, p) => s + (p['points'] as int? ?? 0),
    );
    final totalForPct = totalPts == 0 ? 1 : totalPts;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.deepPurple,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Panel Pro de Zona Gamer',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _kDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Estadísticas globales en tiempo real y rendimiento analítico de la sesión en Palito.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ProStat(
                      label: '👥 Comensales',
                      value: '${_players.length}',
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    _ProStat(
                      label: '⚡ Decisiones',
                      value: '$_decisionsCount',
                      valueColor: _kRed,
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    _ProStat(
                      label: '📜 Historial',
                      value: '${_history.length} jugadas',
                      valueColor: Colors.deepPurple,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Distribución de Puntos por Comensal',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _kDark,
                ),
              ),
              const SizedBox(height: 10),
              ..._players.map((player) {
                final pts = player['points'] as int? ?? 0;
                final medals = player['medals'] as int? ?? 0;
                final pct = (pts / totalForPct).clamp(0.0, 1.0);
                final playerColor = player['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                player['icon'] as IconData,
                                size: 14,
                                color: playerColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                player['name'] as String,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _kDark,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$pts pts ($medals 🏆)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            playerColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showBadgesModal();
                  },
                  child: Text(
                    'Ver Podio e Insignias',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade200),
                    backgroundColor: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetSessionScores();
                  },
                  child: Text(
                    '🔄 Reiniciar Sesión',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.red.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPlayerDialog() {
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
                  'Nuevo Comensal',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _kDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Nombre del amigo o familiar...',
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
                  backgroundColor: _kYellow,
                  foregroundColor: _kDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _addPlayer,
                child: Text(
                  'Añadir a la Mesa',
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

  // ─── Ruleta ──────────────────────────────────────────────────────────────────
  void _spinGame() {
    if (_players.isEmpty || _isSpinning || !mounted) return;

    setState(() {
      _isSpinning = true;
      _selectedWinner = null;
      _currentChallenge = null;
    });
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

          if (_selectedMode == 0) {
            pointsWon = 5;
            winner['points'] = (winner['points'] ?? 0) + pointsWon;
            eventDetail = 'Ruleta Pro: Elección de Plato';
            _history.insert(0, {
              'winner': winnerName,
              'detail': '🍽️ ¡Le toca elegir plato!',
              'time': TimeOfDay.now().format(context),
            });
          } else {
            final challenge =
                _palitoChallenges[random.nextInt(_palitoChallenges.length)];
            _currentChallenge = challenge;
            _punishmentCounts[winnerName] =
                (_punishmentCounts[winnerName] ?? 0) + 1;
            pointsWon = 10;
            winner['points'] = (winner['points'] ?? 0) + pointsWon;
            winner['medals'] = (winner['medals'] ?? 0) + 1;
            eventDetail = 'Juicio Picante';
            _history.insert(0, {
              'winner': winnerName,
              'detail': '🔥 Juicio Picante asignado',
              'time': TimeOfDay.now().format(context),
            });
          }
          if (_history.length > 5) _history.removeLast();
        });

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
          debugPrint('Error sincronizando evento de ruleta: $e');
          debugPrintStack(stackTrace: st);
        }

        if (!mounted) return;
        _winnerScaleController.forward(from: 0.0);
        HapticFeedback.vibrate();
      } catch (e, st) {
        debugPrint('Error durante el giro de la ruleta: $e');
        debugPrintStack(stackTrace: st);
        if (!mounted) return;
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Selector de modo ──────────────────────────────────────────
              _ModeSelector(
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
                            errorBuilder: (_, __, ___) => Container(
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
                      if (_selectedMode == 1 && _currentChallenge != null) ...[
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
                  height: 56,
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
                        Text(
                          _isSpinning
                              ? 'Girando Ruleta...'
                              : (_selectedMode == 0
                                    ? '¡Girar Ruleta (Elegir Plato)!'
                                    : '¡Lanzar Juicio Picante!'),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                    icon: const Icon(Icons.add_rounded, size: 16, color: _kRed),
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
              const SizedBox(height: 12),
              SizedBox(
                height: 94,
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

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onLongPress: () => _removePlayer(index),
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
                              color: isHighlighted ? _kYellow : Colors.white,
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
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: playerColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  child: Icon(
                                    player['icon'] as IconData,
                                    color: playerColor,
                                    size: 18,
                                  ),
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
                      color: Colors.grey.shade400,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            color: Colors.grey.shade400,
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
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Widgets auxiliares privados
// ════════════════════════════════════════════════════════════════════════════

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selectedMode, required this.onSelect});
  final int selectedMode;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _kDark, width: 2),
      boxShadow: const [
        BoxShadow(color: _kDark, offset: Offset(3, 3), blurRadius: 0),
      ],
    ),
    child: Row(
      children: [
        _ModeTab(
          label: '🎯 Ruleta Pro',
          index: 0,
          selectedMode: selectedMode,
          activeColor: _kYellow,
          onTap: onSelect,
        ),
        _ModeTab(
          label: '🔥 Juicio Picante',
          index: 1,
          selectedMode: selectedMode,
          activeColor: _kRed,
          onTap: onSelect,
          activeTextColor: Colors.white,
        ),
      ],
    ),
  );
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.index,
    required this.selectedMode,
    required this.activeColor,
    required this.onTap,
    this.activeTextColor,
  });
  final String label;
  final int index, selectedMode;
  final Color activeColor;
  final Color? activeTextColor;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedMode == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
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
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected
                    ? (activeTextColor ?? _kDark)
                    : Colors.grey.shade500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.text, required this.bgColor, this.textColor});
  final String text;
  final Color bgColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: textColor ?? _kDark,
      ),
    ),
  );
}

class _ProStat extends StatelessWidget {
  const _ProStat({required this.label, required this.value, this.valueColor});
  final String label, value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: valueColor ?? _kDark,
        ),
      ),
    ],
  );
}
