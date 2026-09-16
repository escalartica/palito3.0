import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/components/progress_track.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

const _kDark = AppColors.textPrimary;

/// ===========================================================================
/// EL PODIO Y LOS LOGROS DE LA MESA
/// ===========================================================================
///
/// El botón que abre esta hoja dice "Ver Podio e Insignias" y lo que había
/// dentro era una lista. Tres tarjetas beige idénticas, del mismo tamaño y
/// con el mismo peso visual: quien llevaba 40 puntos y tres medallas se veía
/// exactamente igual que quien llevaba 5 y ninguna, y para saber quién iba
/// ganando había que leer los números uno por uno. Un podio en el que hay que
/// leer para saber quién ha ganado no es un podio.
///
/// Lo que cambia:
///
/// - **Primero, segundo y tercero se ven distintos.** El primero ocupa su
///   propia tarjeta ancha, con el amarillo de marca, borde y sombra dura; los
///   demás van en filas con su número delante. La jerarquía se ve de un
///   vistazo, antes de leer nada.
/// - **Se acabaron los lavados.** Las pastillas usaban coral al 15 % con el
///   texto también coral encima: **2,71:1**, por debajo del mínimo legible.
///   Ahora el texto es navy sobre tintes opacos.
/// - **Los logros bloqueados enseñan cuánto falta.** Antes eran un candado y
///   una frase; ahora llevan su barra: "9 de 10" invita a una tirada más,
///   "bloqueado" no invita a nada.
///
/// [players] llega ya ordenado por puntuación (mayor a menor); el orden se
/// calcula en el llamador para no duplicar esa lógica aquí.
class BadgesModal extends StatelessWidget {
  const BadgesModal({
    super.key,
    required this.players,
    required this.achievements,
  });

  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> achievements;

  @override
  Widget build(BuildContext context) {
    final int unlockedCount = achievements
        .where((Map<String, dynamic> a) => a['unlocked'] == true)
        .length;

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
                    'El podio',
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
              players.isEmpty
                  ? 'Todavía no hay nadie en la mesa.'
                  : (_anyPoints(players)
                        ? 'Cómo va la sesión ahora mismo.'
                        : 'Todavía no hay puntos. Girad la ruleta para abrir '
                              'el marcador.'),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            if (players.isNotEmpty) ...<Widget>[
              _WinnerCard(
                player: players.first,
                // Con todos a cero no hay nadie ganando: la tarjeta decía
                // "VA GANANDO" encima del primero de la lista antes de la
                // primera tirada. Es el mismo invento que "Volverías 0 %"
                // con el diario vacío — un dato que parece un dato y no lo
                // es.
                leading: _anyPoints(players),
              ),
              const SizedBox(height: 10),
              for (int i = 1; i < players.length; i++) ...<Widget>[
                _RunnerUpRow(position: i + 1, player: players[i]),
                if (i < players.length - 1) const SizedBox(height: 8),
              ],
            ],

            const SizedBox(height: 26),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Logros de la mesa',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _kDark,
                    ),
                  ),
                ),
                Text(
                  '$unlockedCount de ${achievements.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final Map<String, dynamic> a in achievements) ...<Widget>[
              _AchievementRow(achievement: a),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Si alguien de la mesa ha puntuado ya.
bool _anyPoints(List<Map<String, dynamic>> players) =>
    players.any((Map<String, dynamic> p) => (p['points'] as int? ?? 0) > 0);

/// Quien va primero. Su tarjeta es la única con el amarillo de marca y la
/// única con sombra dura: en una pantalla donde todo lo demás es blanco y
/// beige, eso basta para que el ojo aterrice aquí antes de leer un número.
class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.player, required this.leading});

  final Map<String, dynamic> player;

  /// Si alguien de la mesa tiene puntos. Sin puntos no se corona a nadie.
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final int points = player['points'] as int? ?? 0;
    final int medals = player['medals'] as int? ?? 0;
    final String name = player['name']?.toString() ?? 'Comensal';

    return Semantics(
      label: leading
          ? 'Primer puesto: $name, $points puntos y $medals '
                '${medals == 1 ? 'medalla' : 'medallas'}'
          : '$name, todavía sin puntos',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: _kDark, width: AppBorder.normal),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: _kDark, offset: Offset(3, 3), blurRadius: 0),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kDark, width: AppBorder.normal),
                ),
                child: Icon(
                  player['icon'] as IconData? ?? Icons.person_rounded,
                  size: 24,
                  color: _kDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      leading ? 'VA GANANDO' : 'EN LA MESA',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: _kDark,
                      ),
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -0.4,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      medals == 0
                          ? '$points puntos'
                          : '$points puntos · $medals '
                                '${medals == 1 ? 'medalla' : 'medallas'}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Del segundo para abajo. Número grande delante: el puesto es el dato, no
/// el adorno.
class _RunnerUpRow extends StatelessWidget {
  const _RunnerUpRow({required this.position, required this.player});

  final int position;
  final Map<String, dynamic> player;

  @override
  Widget build(BuildContext context) {
    final int points = player['points'] as int? ?? 0;
    final int medals = player['medals'] as int? ?? 0;
    final String name = player['name']?.toString() ?? 'Comensal';

    return Semantics(
      label:
          'Puesto $position: $name, $points puntos y $medals '
          '${medals == 1 ? 'medalla' : 'medallas'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceWarm,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.tintMuted, width: 1.5),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 22,
                child: Text(
                  '$position',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                player['icon'] as IconData? ?? Icons.person_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                medals == 0 ? '$points pts' : '$points pts · $medals 🏆',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un logro. Conseguido: tinte de su color y su marca de visto. Bloqueado:
/// apagado, pero con la barra de cuánto llevas — que es la única razón por la
/// que alguien mira un logro que todavía no tiene.
class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement});

  final Map<String, dynamic> achievement;

  @override
  Widget build(BuildContext context) {
    final bool unlocked = achievement['unlocked'] == true;
    final String title = achievement['title']?.toString() ?? '';
    final String desc = achievement['desc']?.toString() ?? '';
    final int goal = achievement['goal'] as int? ?? 0;
    final int current = (achievement['progress'] as int? ?? 0).clamp(
      0,
      goal == 0 ? 1 : goal,
    );

    // Tinte opaco por color de marca. Nada de `color.withValues(alpha: 0.08)`:
    // sobre esta hoja da igual, pero en cuanto una tarjeta lleva sombra dura
    // el navy se cuela por debajo del fondo translúcido y el texto se vuelve
    // ilegible. Se hace bien desde el principio.
    final Color color = achievement['color'] as Color? ?? AppColors.primary;
    final Color tint = unlocked
        ? (color == AppColors.accent
              ? AppColors.tintAccent
              : color == AppColors.textPrimary
              ? AppColors.tintMuted
              : AppColors.tintPrimary)
        : AppColors.surface;

    return Semantics(
      label: unlocked
          ? '$title, conseguido. $desc'
          : goal > 0
          ? '$title, bloqueado. $desc Llevas $current de $goal'
          : '$title, bloqueado. $desc',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: unlocked ? _kDark : AppColors.tintMuted,
              width: unlocked ? AppBorder.thin : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                achievement['icon'] as IconData? ?? Icons.star_rounded,
                color: unlocked ? _kDark : AppColors.textMuted,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        color: unlocked ? _kDark : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      desc,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (!unlocked && goal > 0) ...<Widget>[
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: ProgressTrack(
                              value: current / goal,
                              color: AppColors.primary,
                              height: 8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$current de $goal',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                unlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
                color: unlocked ? _kDark : AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
