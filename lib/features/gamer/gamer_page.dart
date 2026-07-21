import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class GamerPage extends StatefulWidget {
  const GamerPage({super.key});

  @override
  State<GamerPage> createState() => _GamerPageState();
}

class _GamerPageState extends State<GamerPage> with TickerProviderStateMixin {
  int _selectedMode = 0; // 0: Ruleta Pro, 1: El Juicio de Palito
  
  final List<Map<String, dynamic>> _players = [
    {"name": "Tú", "icon": Icons.person_rounded, "color": const Color(0xFFFFD400)},
    {"name": "Tu Pareja", "icon": Icons.favorite_rounded, "color": const Color(0xFFFF4D29)},
    {"name": "🤖 Palito", "icon": Icons.smart_toy_rounded, "color": const Color(0xFF0F172A)},
    {"name": "Celia", "icon": Icons.star_rounded, "color": const Color(0xFF38BDF8)},
    {"name": "Chary", "icon": Icons.local_fire_department_rounded, "color": const Color(0xFFEC4899)},
    {"name": "Vero", "icon": Icons.bolt_rounded, "color": const Color(0xFF10B981)},
  ];

  final TextEditingController _nameController = TextEditingController();
  Map<String, dynamic>? _selectedWinner;
  bool _isSpinning = false;
  int _highlightedIndex = -1;
  int _decisionsCount = 3; // Contador de partidas en la sesión

  final List<String> _palitoChallenges = [
    "🏆 ¡Pide un plato sorpresa y exígeles una nota mínima de 9!",
    "💸 ¡Te toca pagar la primera ronda de bebidas de toda la mesa!",
    "🍰 ¡Elige el postre a ciegas sin mirar la carta y acierta los ingredientes!",
    "🔍 ¡Haz una cata técnica obligatoria al plato del compañero de al lado!",
    "🎙️ ¡Inaugura el banquete haciendo un brindis épico dedicado a Palito!",
    "🌶️ ¡Prueba el bocado más picante o exótico disponible en la comanda!",
  ];

  String? _currentChallenge;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addPlayer() {
    final text = _nameController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _players.add({
          "name": text,
          "icon": Icons.face_rounded,
          "color": Colors.primaries[Random().nextInt(Colors.primaries.length)],
        });
        _nameController.clear();
      });
      Navigator.pop(context);
      HapticFeedback.mediumImpact();
    }
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
    int totalSteps = 18 + random.nextInt(12);
    int step = 0;

    void nextStep() {
      if (!mounted) return;
      setState(() {
        _highlightedIndex = (_highlightedIndex + 1) % _players.length;
      });
      HapticFeedback.selectionClick();

      if (step < totalSteps) {
        step++;
        // Velocidad decreciente simulando inercia real de ruleta
        int delay = 50 + (pow(step, 1.4) * 3).toInt();
        Future.delayed(Duration(milliseconds: delay), nextStep);
      } else {
        final winner = _players[_highlightedIndex];
        setState(() {
          _isSpinning = false;
          _selectedWinner = winner;
          _decisionsCount++;
          if (_selectedMode == 1 || winner["name"].contains("Palito")) {
            _currentChallenge = _palitoChallenges[random.nextInt(_palitoChallenges.length)];
          }
        });
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
                  fillColor: const Color(0xFFFFFDF5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF0F172A)),
          ),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          "Zona Gamer de Palito",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A)),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD400).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFFF4D29)),
                const SizedBox(width: 4),
                Text(
                  "$_decisionsCount",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
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
              // Selector de Modos de Juego (Gamificación Avanzada)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMode = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedMode == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: _selectedMode == 0 ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "🎯 Ruleta Pro",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: _selectedMode == 0 ? const Color(0xFF0F172A) : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMode = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedMode == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: _selectedMode == 1 ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "🔥 El Juicio Picante",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: _selectedMode == 1 ? const Color(0xFFFF4D29) : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Visualizador Central de Ganador Estilo Concurso
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _selectedMode == 0 
                        ? [const Color(0xFFFFD400), const Color(0xFFFF9F1C)]
                        : [const Color(0xFFFF4D29), const Color(0xFFFF7043)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: (_selectedMode == 0 ? const Color(0xFFFF9F1C) : const Color(0xFFFF4D29)).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icons/IconoRedondoTenedor.png',
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedWinner == null
                          ? (_isSpinning ? "⚡ Buscando culpable..." : (_selectedMode == 0 ? "¡Gira para resolver la mesa!" : "¡El juicio de Palito va a empezar!"))
                          : "🎉 ¡Veredicto Final:",
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedWinner != null ? _selectedWinner!["name"] : (_selectedMode == 0 ? "Ruleta Lista" : "Juicio Pendiente"),
                      style: GoogleFonts.outfit(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_currentChallenge != null)
                      Container(
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _currentChallenge!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Cabecera Comensales
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Comensales Activos (${_players.length})",
                    style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  TextButton.icon(
                    onPressed: _showAddPlayerDialog,
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF4D29)),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: Text("Añadir", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Lista de jugadores con indicador de selección interactivo
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _players.length,
                itemBuilder: (context, index) {
                  final player = _players[index];
                  final isHighlighted = _highlightedIndex == index;
                  final isProtected = index < 3;
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isHighlighted ? const Color(0xFFFFECE6) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isHighlighted ? const Color(0xFFFF4D29) : Colors.grey.shade200,
                        width: isHighlighted ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (player["color"] as Color).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(player["icon"] as IconData, color: player["color"] as Color, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            player["name"],
                            style: GoogleFonts.inter(
                              fontWeight: isHighlighted ? FontWeight.w900 : FontWeight.w600, 
                              fontSize: 15, 
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (isHighlighted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D29),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text("¡Punto!", style: GoogleFonts.outfit(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        if (!isProtected && !isHighlighted)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _players.removeAt(index);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Botón de Acción Principal Gamer
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD400),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  onPressed: _isSpinning ? null : _spinGame,
                  child: Text(
                    _isSpinning ? "🎲 Sorteando en la Mesa..." : (_selectedMode == 0 ? "⚡ ¡Girar Ruleta Decisiva!" : "🔥 ¡Lanzar Juicio de Palito!"),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17),
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