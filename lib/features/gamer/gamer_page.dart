import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../gamer/zona_gamer_card.dart';
import '../../../core/theme/app_theme.dart';

class GamerPage extends StatefulWidget {
  const GamerPage({super.key});

  @override
  State<GamerPage> createState() => _GamerPageState();
}

class _GamerPageState extends State<GamerPage> with TickerProviderStateMixin {
  int _selectedMode = 0; // 0: Ruleta Pro (Elige Plato), 1: Juicio Picante (Retos)
  
  List<Map<String, dynamic>> _players = [
    {"name": "Tú", "icon": Icons.person_rounded, "color": const Color(0xFFFFD400), "points": 0, "medals": 0},
    {"name": "Tu Pareja", "icon": Icons.favorite_rounded, "color": const Color(0xFFFF4D29), "points": 0, "medals": 0},
    {"name": "🤖 Palito", "icon": Icons.smart_toy_rounded, "color": const Color(0xFF0F172A), "points": 0, "medals": 0},
    {"name": "Celia", "icon": Icons.star_rounded, "color": const Color(0xFF38BDF8), "points": 0, "medals": 0},
    {"name": "Chary", "icon": Icons.local_fire_department_rounded, "color": const Color(0xFFEC4899), "points": 0, "medals": 0},
    {"name": "Vero", "icon": Icons.bolt_rounded, "color": const Color(0xFF10B981), "points": 0, "medals": 0},
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customChallengeController = TextEditingController();
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

  final List<String> _palitoChallenges = [
    "🏆 ¡Pide un plato sorpresa y exígeles una nota mínima de 9!",
    "💸 ¡Toca pagar la primera ronda de bebidas de toda la mesa!",
    "🍰 ¡Elige el postre a ciegas sin mirar la carta y acierta los ingredientes!",
    "🔍 ¡Haz una cata técnica obligatoria al plato del compañero de al lado!",
    "🎙️ ¡Inaugura el banquete haciendo un brindis épico dedicado a Palito!",
    "🌶️ ¡Prueba el bocado más picante o exótico disponible en la comanda!",
  ];

  String? _currentChallenge;

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

  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDecisions = prefs.getInt('palito_decisions_count');
      if (savedDecisions != null) {
        setState(() {
          _decisionsCount = savedDecisions;
        });
      }

      final savedPlayersJson = prefs.getString('palito_players_data');
      if (savedPlayersJson != null) {
        final List<dynamic> decoded = jsonDecode(savedPlayersJson);
        setState(() {
          _players = decoded.map((item) => {
            "name": item["name"],
            "icon": _getIconData(item["iconCode"]),
            "color": Color(item["colorValue"]),
            "points": item["points"] ?? 0,
            "medals": item["medals"] ?? 0,
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error cargando datos: $e");
    }
  }

  Future<void> _savePersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('palito_decisions_count', _decisionsCount);

      final serialized = _players.map((p) => {
        "name": p["name"],
        "iconCode": (p["icon"] as IconData).codePoint,
        "colorValue": (p["color"] as Color).toARGB32(),
        "points": p["points"],
        "medals": p["medals"],
      }).toList();

      prefs.setString('palito_players_data', jsonEncode(serialized));
    } catch (e) {
      debugPrint("Error guardando datos: $e");
    }
  }

  IconData _getIconData(int code) {
    switch (code) {
      case 0xe491: return Icons.person_rounded;
      case 0xe25d: return Icons.favorite_rounded;
      case 0xf04e9: return Icons.smart_toy_rounded;
      case 0xe5f9: return Icons.star_rounded;
      case 0xe3a7: return Icons.local_fire_department_rounded;
      case 0xe0e9: return Icons.bolt_rounded;
      default: return Icons.face_rounded;
    }
  }

  void _addPlayer() {
    final text = _nameController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _players.add({
          "name": text,
          "icon": Icons.face_rounded,
          "color": Colors.primaries[Random().nextInt(Colors.primaries.length)],
          "points": 0,
          "medals": 0,
        });
        _nameController.clear();
      });
      _savePersistedData();
      Navigator.pop(context);
      HapticFeedback.mediumImpact();
      _showFeedbackSnackbar("¡$text añadido a la mesa!");
    }
  }

  void _removePlayer(int index) {
    final removedName = _players[index]["name"];
    setState(() {
      _players.removeAt(index);
    });
    _savePersistedData();
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar("Comensal $removedName eliminado");
  }

  void _resetSessionScores() {
    setState(() {
      for (var p in _players) {
        p["points"] = 0;
        p["medals"] = 0;
      }
      _history.clear();
      _punishmentCounts.clear();
      _decisionsCount = 0;
      _selectedWinner = null;
      _currentChallenge = null;
    });
    _savePersistedData();
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar("🔄 Puntuaciones de la sesión reiniciadas");
  }

  void _showFeedbackSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        backgroundColor: const Color(0xFFFFD400),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resolveChallengeResult(String playerName, bool succeeded) {
    setState(() {
      final player = _players.firstWhere((p) => p["name"] == playerName, orElse: () => _players[0]);
      if (succeeded) {
        player["points"] = (player["points"] ?? 0) + 15;
        player["medals"] = (player["medals"] ?? 0) + 1;
        _history.insert(0, {
          "winner": playerName,
          "detail": "✅ ¡Reto Superado (+15 pts / +1 medalla)!",
          "time": TimeOfDay.now().format(context),
        });
        _showFeedbackSnackbar("🎉 ¡+15 puntos para $playerName!");
      } else {
        _history.insert(0, {
          "winner": playerName,
          "detail": "❌ Reto Fallido",
          "time": TimeOfDay.now().format(context),
        });
        _showFeedbackSnackbar("❌ Reto no superado por $playerName");
      }
      if (_history.length > 5) _history.removeLast();
    });
    _savePersistedData();
    HapticFeedback.mediumImpact();
  }

  void _showChallengeOutcomeDialog(String playerName, String challengeText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
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
                  "🎯 Evaluar Juicio de $playerName",
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
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
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
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
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade700,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text("❌ No Superado", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          _resolveChallengeResult(playerName, true);
                          Navigator.pop(context);
                        },
                        child: Text("✅ ¡Superado!", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddChallengeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
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
                    "Añadir Juicio Picante",
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customChallengeController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: "Ej: Pagar la cuenta o hacer un baile...",
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
                    backgroundColor: const Color(0xFFFF4D29),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final text = _customChallengeController.text.trim();
                    if (text.isNotEmpty) {
                      setState(() {
                        _palitoChallenges.add("🔥 $text");
                        _currentChallenge = "🔥 $text";
                      });
                      _customChallengeController.clear();
                      Navigator.pop(context);
                      HapticFeedback.mediumImpact();
                      _showFeedbackSnackbar("Juicio picante añadido con éxito");
                    }
                  },
                  child: Text("Guardar y Aplicar Juicio", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showBadgesModal() {
    final sortedPlayers = List<Map<String, dynamic>>.from(_players)
      ..sort((a, b) => (b["points"] as int).compareTo(a["points"] as int));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
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
                  Row(
                    children: [
                      const Icon(Icons.military_tech_rounded, color: Color(0xFFFF9F1C), size: 28),
                      const SizedBox(width: 10),
                      Text(
                        "Insignias de la Mesa",
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Ranking ordenado por puntuación y medallas obtenidas en la sesión.",
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ...sortedPlayers.map((player) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: (player["color"] as Color).withValues(alpha: 0.2),
                          child: Icon(player["icon"], color: player["color"], size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(player["name"], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F172A))),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD400).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text("🏆 ${player["medals"]} medallas", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D29).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text("⭐ ${player["points"]} pts", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFF4D29))),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showZonaGamerProModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
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
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.deepPurple, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        "Panel Pro de Zona Gamer",
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Configuración avanzada y estadísticas globales de la sesión actual en Palito.",
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
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
                    Column(
                      children: [
                        Text("👥 Comensales", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text("${_players.length}", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      ],
                    ),
                    Container(height: 30, width: 1, color: Colors.grey.shade300),
                    Column(
                      children: [
                        Text("⚡ Decisiones", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text("$_decisionsCount", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFFF4D29))),
                      ],
                    ),
                    Container(height: 30, width: 1, color: Colors.grey.shade300),
                    Column(
                      children: [
                        Text("📜 Historial", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text("${_history.length} jugadas", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showBadgesModal();
                  },
                  child: Text("Ver Ranking Completo de Insignias", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade200),
                    backgroundColor: Colors.red.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _resetSessionScores();
                  },
                  child: Text("🔄 Reiniciar Puntuaciones de Sesión", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade600)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _spinGame() {
    if (_players.isEmpty || _isSpinning) return;

    setState(() {
      _isSpinning = true;
      _selectedWinner = null;
      _currentChallenge = null;
    });
    HapticFeedback.heavyImpact();

    final random = Random();
    int totalSteps = 22 + random.nextInt(10);
    int step = 0;

    void nextStep() {
      if (!mounted) return;
      setState(() {
        _highlightedIndex = (_highlightedIndex + 1) % _players.length;
      });
      HapticFeedback.selectionClick();

      if (step < totalSteps) {
        step++;
        int delay = 35 + (pow(step, 1.35) * 3).toInt();
        Future.delayed(Duration(milliseconds: delay), nextStep);
      } else {
        final winner = _players[_highlightedIndex];
        final winnerName = winner["name"];

        setState(() {
          _isSpinning = false;
          _selectedWinner = winner;
          _decisionsCount++;

          if (_selectedMode == 0) {
            _currentChallenge = null;
            _history.insert(0, {
              "winner": winnerName,
              "detail": "🍽️ ¡Le toca elegir plato!",
              "time": TimeOfDay.now().format(context),
            });
            _showFeedbackSnackbar("🍽️ ¡A $winnerName le toca elegir plato!");
          } else {
            final challenge = _palitoChallenges[random.nextInt(_palitoChallenges.length)];
            _currentChallenge = challenge;
            _punishmentCounts[winnerName] = (_punishmentCounts[winnerName] ?? 0) + 1;
            
            winner["points"] = (winner["points"] ?? 0) + 10;
            winner["medals"] = (winner["medals"] ?? 0) + 1;

            _history.insert(0, {
              "winner": winnerName,
              "detail": "🔥 Juicio Picante asignado",
              "time": TimeOfDay.now().format(context),
            });
          }

          if (_history.length > 5) _history.removeLast();
        });

        _savePersistedData();
        _winnerScaleController.forward(from: 0.0);
        HapticFeedback.vibrate();
      }
    }

    nextStep();
  }

  void _showAddPlayerDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
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
                    "Nuevo Comensal",
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: "Nombre del amigo o familiar...",
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
                    backgroundColor: const Color(0xFFFFD400),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _addPlayer,
                  child: Text("Añadir a la Mesa", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _clearHistory() {
    if (_history.isEmpty && _punishmentCounts.isEmpty) return;
    setState(() {
      _history.clear();
      _punishmentCounts.clear();
    });
    _savePersistedData();
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar("Historial de sesión borrado");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFDF5),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF0F172A)),
          ),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          "Zona Gamer de Palito",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF0F172A)),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.military_tech_rounded, color: Color(0xFFFF9F1C), size: 18),
            ),
            onPressed: _showBadgesModal,
            tooltip: "Ver Puntuaciones e Insignias",
          ),
          Container(
            margin: const EdgeInsets.only(right: 16, left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 15, color: Colors.black87),
                const SizedBox(width: 4),
                Text(
                  "$_decisionsCount",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), fontSize: 13),
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
              // Selector de Modos de Juego (Diseño limpio en pastilla)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedMode = 0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedMode == 0 ? const Color(0xFFFFD400) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("🎯", style: TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Text(
                                "Ruleta Pro",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _selectedMode == 0 ? const Color(0xFF0F172A) : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedMode = 1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedMode == 1 ? const Color(0xFFFF4D29) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("🔥", style: TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Text(
                                "Juicio Picante",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _selectedMode == 1 ? Colors.white : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Visualizador Central de Ganador (Elegante y Orgánico)
              ScaleTransition(
                scale: _selectedWinner != null ? _winnerScaleAnimation : const AlwaysStoppedAnimation(1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: _selectedMode == 0 ? const Color(0xFFFFD400) : const Color(0xFFFF4D29),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: (_selectedMode == 0 ? const Color(0xFFFFD400) : const Color(0xFFFF4D29)).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
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
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/icons/IconoRedondoTenedor.png',
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 52,
                              height: 52,
                              color: Colors.white,
                              child: const Icon(Icons.restaurant, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _selectedWinner == null
                            ? (_isSpinning ? "⚡ Buscando comensal..." : (_selectedMode == 0 ? "¡Gira para ver quién elige plato!" : "¡El juicio picante va a empezar!"))
                            : (_selectedMode == 0 ? "🍽️ ¡Le toca elegir plato a:" : "🎉 ¡Veredicto Final:"),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _selectedMode == 0 ? const Color(0xFF0F172A).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedWinner != null ? _selectedWinner!["name"] : (_selectedMode == 0 ? "Ruleta de Platos" : "Juicio Pendiente"),
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: _selectedMode == 0 ? const Color(0xFF0F172A) : Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_selectedMode == 1 && _currentChallenge != null) ...[
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () {
                            if (_selectedWinner != null) {
                              _showChallengeOutcomeDialog(_selectedWinner!["name"], _currentChallenge!);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _currentChallenge!,
                                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "👆 Toca aquí para evaluar el reto",
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFFF4D29)),
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

              // Botón de Acción Principal con Efecto Pulso
              ScaleTransition(
                scale: _isSpinning ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    onPressed: _isSpinning ? null : _spinGame,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.casino_rounded, size: 22, color: Color(0xFFFFD400)),
                        const SizedBox(width: 10),
                        Text(
                          _isSpinning ? "Girando Ruleta..." : (_selectedMode == 0 ? "¡Girar Ruleta (Elegir Plato)!" : "¡Lanzar Juicio Picante!"),
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Sección Comensales en la Mesa (Estilo Scroll Horizontal de Avatares Flotantes)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Comensales en la Mesa (${_players.length})",
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  TextButton.icon(
                    onPressed: _showAddPlayerDialog,
                    icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFFFF4D29)),
                    label: Text("Añadir", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFFF4D29), fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Fila de Comensales Deslizante (Limpia y Minimalista)
              SizedBox(
                height: 94,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _players.length,
                  itemBuilder: (context, index) {
                    final player = _players[index];
                    final isHighlighted = index == _highlightedIndex;
                    final isWinner = _selectedWinner != null && _selectedWinner!["name"] == player["name"];

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onLongPress: () {
                          if (_players.length > 1) {
                            _removePlayer(index);
                          } else {
                            _showFeedbackSnackbar("Debe quedar al menos un comensal");
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 76,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                          decoration: BoxDecoration(
                            color: isHighlighted 
                                ? const Color(0xFFFFD400).withValues(alpha: 0.3)
                                : (isWinner ? Colors.white : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isHighlighted || isWinner ? const Color(0xFFFF9F1C) : Colors.grey.shade200,
                              width: isHighlighted || isWinner ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: (player["color"] as Color).withValues(alpha: 0.2),
                                child: Icon(player["icon"], color: player["color"], size: 18),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                player["name"],
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 28),

              // Tarjeta Interactiva Zona Gamer Card
              ZonaGamerCard(
                title: "Zona Gamer",
                subtitle: "Experiencia Pro",
                backgroundColor: Colors.deepPurple,
                onTap: _showZonaGamerProModal,
              ),

              const SizedBox(height: 28),

              // Historial Pro de la Sesión
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Historial de la Sesión",
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  if (_history.isNotEmpty)
                    TextButton(
                      onPressed: _clearHistory,
                      child: Text("Limpiar", style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.bold)),
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
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    "Todavía no hay registros en esta sesión. ¡Gira la ruleta para empezar!",
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._history.map((record) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history_rounded, size: 18, color: Color(0xFFFF9F1C)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(record["winner"]!, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              Text(record["detail"]!, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                      Text(record["time"]!, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
              
              const SizedBox(height: 24),

              // Botón Añadir Reto Personalizado al vuelo
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFFFF4D29).withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _showAddChallengeDialog,
                  icon: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF4D29), size: 18),
                  label: Text(
                    "Añadir Juicio Picante al Vuelo",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFFFF4D29)),
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