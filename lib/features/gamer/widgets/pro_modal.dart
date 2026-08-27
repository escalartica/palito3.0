import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pro_stat.dart';

const _kDark = Color(0xFF0F172A);
const _kRed = Color(0xFFFF4D29);

/// Panel Pro de Zona Gamer: estadísticas globales y distribución de puntos
/// por comensal, con accesos a ver insignias y reiniciar la sesión.
/// Extraído de gamer_page.dart.
class ProModal extends StatelessWidget {
  const ProModal({
    super.key,
    required this.players,
    required this.decisionsCount,
    required this.historyCount,
    required this.onViewBadges,
    required this.onResetSession,
  });

  final List<Map<String, dynamic>> players;
  final int decisionsCount;
  final int historyCount;
  final VoidCallback onViewBadges;
  final VoidCallback onResetSession;

  @override
  Widget build(BuildContext context) {
    final totalPts = players.fold<int>(
      0,
      (s, p) => s + (p['points'] as int? ?? 0),
    );
    final totalForPct = totalPts == 0 ? 1 : totalPts;

    return Container(
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
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Estadísticas globales en tiempo real y rendimiento analítico de la sesión en Palito.',
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
                  ProStat(label: '👥 Comensales', value: '${players.length}'),
                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                  ProStat(
                    label: '⚡ Decisiones',
                    value: '$decisionsCount',
                    valueColor: _kRed,
                  ),
                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                  ProStat(
                    label: '📜 Historial',
                    value: '$historyCount jugadas',
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
            ...players.map((player) {
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
                        valueColor: AlwaysStoppedAnimation<Color>(playerColor),
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
                  Navigator.pop(context);
                  onViewBadges();
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
                  Navigator.pop(context);
                  onResetSession();
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
    );
  }
}
