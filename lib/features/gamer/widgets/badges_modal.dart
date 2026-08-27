import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'badge_pill.dart';

const _kDark = Color(0xFF0F172A);
const _kYellow = Color(0xFFFFD400);
const _kRed = Color(0xFFFF4D29);

/// Modal con el ranking de comensales (puntos y medallas) y los logros
/// especiales globales de la sesión. Extraído de gamer_page.dart.
///
/// [players] debe llegar ya ordenado por puntuación (mayor a menor); el
/// orden se calcula en el llamador para no duplicar esa lógica aquí.
class BadgesModal extends StatelessWidget {
  const BadgesModal({
    super.key,
    required this.players,
    required this.achievements,
  });

  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> achievements;

  @override
  Widget build(BuildContext context) => Container(
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
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ranking ordenado por puntuación, medallas e insignias desbloqueadas.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ...players.map((player) {
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
                          backgroundColor: playerColor.withValues(alpha: 0.2),
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
                      BadgePill(
                        text: '🏆 ${player['medals']} medallas',
                        bgColor: _kYellow.withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 6),
                      BadgePill(
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
          ...achievements.map((a) {
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
                    unlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
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
  );
}
