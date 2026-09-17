import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../zona_gamer_card.dart';
import '../../../core/theme/components/app_motion.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

/// ===========================================================================
/// CÓMO SE JUEGA
/// ===========================================================================
///
/// Las reglas de la ruleta, enteras y a mano en cualquier momento.
///
/// POR QUÉ HACÍA FALTA. La explicación existía —la tarjeta "¿Quién elige
/// hoy?"— pero **se autodestruía**: sale solo hasta la primera tirada y se
/// puede cerrar antes, y después no hay forma de volver a verla. O sea que la
/// ayuda desaparecía exactamente cuando dejabas de necesitarla para la
/// primera pantalla y empezabas a necesitarla para todo lo demás: qué son los
/// puntos, de dónde salen las medallas, qué hace Palito sentado a la mesa,
/// qué son esos siete logros.
///
/// Y encima esa tarjeta solo explicaba los tres modos. Nada de puntos, ni de
/// medallas, ni de cómo vincular tus puntos a tu cuenta.
///
/// Las cifras de aquí NO están escritas a ojo: salen de
/// `GamerGameLogic.computeSpinOutcome` (5 puntos la ruleta, 10 y medalla el
/// juicio picante) y de `achievementProgress` (las metas de los logros). Si
/// algún día cambian ahí, este texto miente — está anotado en ambos sitios.
/// ===========================================================================
Future<void> showHowToPlaySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Sin esto, la hoja se abre en el `Navigator` de la pestaña y **el dock
    // se pinta encima**, tapándole el final. Se ve en cuanto la comparas con
    // las otras hojas de la app, que sí lo declaran: el dock vive en el
    // andamio de las pestañas, por encima del contenido, así que una hoja
    // que no suba al navegador raíz se queda por debajo de él.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => const _HowToPlaySheet(),
  );
}

class _HowToPlaySheet extends StatelessWidget {
  const _HowToPlaySheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        // `MotionColumn` y no `Column`: las seis reglas se colocan de arriba
        // abajo en vez de encenderse las seis a la vez. En una hoja que son
        // seis bloques de texto seguidos, eso es la diferencia entre "aquí
        // hay un muro" y "esto se lee por orden".
        child: MotionColumn(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Cómo se juega',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
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
              'Para decidir sin discutir. Sentáis a la mesa a quien esté, '
              'giráis, y la ruleta decide por vosotros.',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),

            const _Rule(
              icon: Icons.groups_rounded,
              title: 'La mesa',
              lines: <String>[
                'Añade un comensal por cada persona que esté comiendo.',
                'Toca tu comensal para vincular sus puntos a tu cuenta: así '
                    'los puntos que gane son tuyos de verdad.',
                'Mantén pulsado un comensal para quitarlo.',
              ],
            ),

            const _Rule(
              icon: Icons.casino_rounded,
              title: 'Quién elige',
              lines: <String>[
                'Señala a quién le toca elegir el plato.',
                'Quien salga se lleva 5 puntos.',
              ],
            ),

            const _Rule(
              icon: Icons.local_fire_department_rounded,
              title: 'Juicio picante',
              lines: <String>[
                'Al señalado le cae un reto al azar. Solo por salir ya son '
                    '10 puntos y una medalla.',
                'Si lo cumple, 15 puntos más y otra medalla.',
                'Toca la tarjeta del reto para decir si lo cumplió.',
              ],
            ),

            const _Rule(
              icon: Icons.restaurant_rounded,
              title: 'Palito',
              lines: <String>[
                'Siéntalo a la mesa como un comensal más.',
                'Si la ruleta le señala, elige él: propone un plato de '
                    'vuestro propio diario, tirando de los que puntuasteis '
                    'alto y a los que dijisteis que volveríais.',
              ],
            ),

            const _Rule(
              icon: Icons.military_tech_rounded,
              title: 'El podio y los logros',
              lines: <String>[
                'En el botón de la medalla, arriba: quién va ganando y los '
                    'siete logros de la mesa.',
                'Cada logro dice cuánto te falta, no solo si lo tienes.',
              ],
            ),

            const _Rule(
              icon: Icons.restart_alt_rounded,
              title: 'Empezar de cero',
              lines: <String>[
                'En «$kResumenDeLaPartida» puedes poner los puntos a cero '
                    'sin perder los logros que ya hayáis conseguido.',
              ],
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({
    required this.icon,
    required this.title,
    required this.lines,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppBorder.thin,
              ),
            ),
            child: Icon(icon, size: 19, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                for (final String line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
