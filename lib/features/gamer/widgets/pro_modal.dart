import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pro_stat.dart';
import '../../../core/theme/components/progress_track.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

const _kDark = AppColors.textPrimary;

/// ===========================================================================
/// CÓMO VA LA MESA
/// ===========================================================================
///
/// Antes se llamaba "Panel Pro de Zona Gamer" y debajo ponía "Estadísticas
/// globales en tiempo real y rendimiento analítico de la sesión en Palito":
/// catorce palabras para decir "puntos y partidas", en una hoja con tres
/// números. Nada de eso es información; es relleno de folleto en mitad de una
/// cena entre amigos.
///
/// Lo demás que cambia aquí:
///
/// - **Fuera el morado.** Había `Colors.deepPurple` en el icono, en un dato y
///   en el botón principal, y `Colors.red.shade50/200/600` en el de reiniciar.
///   Ninguno de esos colores existe en la marca: Palito es navy, amarillo y
///   coral. El morado era, además, el color más saturado de toda la app, en
///   una pantalla secundaria.
/// - **"1 jugadas".** El plural estaba concatenado a pelo.
/// - **La lista era un ranking sin ordenar.** Los comensales salían en el
///   orden en que se sentaron, con una barra de progreso al lado: parecía una
///   clasificación y no lo era.
/// - **Las barras amarillas no se veían.** Amarillo de marca sobre blanco mide
///   1,6:1; una barra que no se distingue del fondo no mide nada. Ahora van
///   dentro de una pista con borde.
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
    final int totalPts = players.fold<int>(
      0,
      (int s, Map<String, dynamic> p) => s + (p['points'] as int? ?? 0),
    );

    // El denominador de las barras es el líder, no la suma.
    //
    // Con la suma, en una mesa de cinco el primero se queda en el 40 % de la
    // barra y la gráfica parece decir que nadie destaca. Comparado con quien
    // va ganando, la distancia se lee tal cual es.
    final int leaderPts = players.fold<int>(
      0,
      (int m, Map<String, dynamic> p) =>
          (p['points'] as int? ?? 0) > m ? p['points'] as int : m,
    );
    final int scale = leaderPts == 0 ? 1 : leaderPts;

    final List<Map<String, dynamic>> ranked =
        List<Map<String, dynamic>>.from(players)..sort(
          (Map<String, dynamic> a, Map<String, dynamic> b) =>
              (b['points'] as int? ?? 0).compareTo(a['points'] as int? ?? 0),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Cómo va la mesa',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: _kDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              'Puntos, medallas y tiradas de esta sesión.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: _kDark, width: AppBorder.thin),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: _kDark, offset: Offset(2, 2), blurRadius: 0),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  ProStat(
                    icon: Icons.groups_rounded,
                    label: 'Comensales',
                    value: '${players.length}',
                  ),
                  Container(
                    height: 34,
                    width: 1,
                    color: AppColors.tintMuted,
                  ),
                  ProStat(
                    icon: Icons.bolt_rounded,
                    label: 'Decisiones',
                    value: '$decisionsCount',
                  ),
                  Container(
                    height: 34,
                    width: 1,
                    color: AppColors.tintMuted,
                  ),
                  ProStat(
                    icon: Icons.history_rounded,
                    label: historyCount == 1 ? 'Tirada' : 'Tiradas',
                    value: '$historyCount',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Puntos por comensal',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _kDark,
                    ),
                  ),
                ),
                Text(
                  '$totalPts en total',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...ranked.map((Map<String, dynamic> player) {
              final int pts = player['points'] as int? ?? 0;
              final int medals = player['medals'] as int? ?? 0;
              final String name = player['name']?.toString() ?? 'Comensal';
              final double pct = (pts / scale).clamp(0.0, 1.0);
              final Color playerColor =
                  player['color'] as Color? ?? AppColors.primary;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Semantics(
                  label:
                      '$name, $pts ${pts == 1 ? 'punto' : 'puntos'}'
                      '${medals == 0 ? '' : ' y $medals '
                            '${medals == 1 ? 'medalla' : 'medallas'}'}',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              player['icon'] as IconData? ??
                                  Icons.person_rounded,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _kDark,
                                ),
                              ),
                            ),
                            Text(
                              medals == 0
                                  ? '$pts pts'
                                  : '$pts pts · $medals 🏆',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ProgressTrack(value: pct, color: playerColor, height: 12),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),
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
                    side: const BorderSide(
                      color: _kDark,
                      width: AppBorder.normal,
                    ),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onViewBadges();
                },
                icon: const Icon(Icons.emoji_events_rounded, size: 20),
                label: Text(
                  'Ver el podio y los logros',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Reiniciar borra los puntos de todo el mundo, así que no se
            // pinta como un botón más: va en texto, abajo, y el color de
            // error avisa de lo que hace. El botón rosa pálido de antes
            // pesaba visualmente lo mismo que el principal.
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: AppColors.error,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onResetSession();
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(
                  'Reiniciar la sesión',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
