import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_animation.dart';
import '../../../../core/theme/components/app_motion.dart';

const _kDark = AppColors.textPrimary;

/// Pestaña individual dentro de [ModeSelector] (p.ej. "Ruleta Pro" o
/// "Juicio Picante"). Extraído de gamer_page.dart.
class ModeTab extends StatelessWidget {
  const ModeTab({
    super.key,
    required this.label,
    required this.index,
    required this.selectedMode,
    required this.activeColor,
    required this.onTap,
  });
  final String label;
  final int index, selectedMode;
  final Color activeColor;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedMode == index;
    return Expanded(
      // Mismo fallo que el botón de girar: un `InkWell` pelado registra el
      // toque pero no se anuncia. Estas dos pestañas son lo que decide qué
      // hace la pantalla entera, y para un lector de pantalla eran dos
      // palabras sueltas — ni botones, ni cuál de las dos está elegida.
      child: Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: AppMotion.dur(context, AppAnimation.standard),
            padding: const EdgeInsets.symmetric(vertical: 15),
            // ── Una pastilla dentro de otra, las dos con borde y sombra ──
            //
            // El contenedor de fuera ya tiene borde de 2 y sombra maciza, y
            // la pestaña elegida repetía los dos. Como cada pestaña ocupa
            // media anchura, ese borde interior queda pegado al exterior: se
            // ven dos líneas negras casi superpuestas, que es exactamente lo
            // que hace que un control se lea como hecho a mano.
            //
            // El relleno de color ya dice cuál está elegida. Un borde, una
            // sombra, y se acabó.
            // Sin radio propio: la pestaña llega a los bordes de la
            // tarjeta y es el recorte de la tarjeta el que le redondea las
            // esquinas de arriba. Así el color del modo ES el borde
            // superior del panel, en vez de una pastilla flotando encima.
            // ── LA PESTAÑA APAGADA NO PUEDE SER BLANCA ──
            //
            // Lo era, y el escenario de debajo también: el mismo blanco
            // exacto. Visto en el simulador, la cabecera no se leía como
            // dos pestañas sino como una pestaña amarilla y un hueco, con
            // "Juicio picante" flotando en mitad de la nada.
            //
            // Una cabecera de pestañas funciona porque la elegida está al
            // ras del contenido y la otra está HUNDIDA. Para hundirla hace
            // falta un tono que se vea: `surfaceWarm` y `background` están a
            // un 1 % del blanco, o sea que no se ven. `tintMuted` es navy al
            // 10 % ya mezclado —opaco, ver AppColors— y el navy encima mide
            // 14,56:1.
            decoration: BoxDecoration(
              color: isSelected ? activeColor : AppColors.tintMuted,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                // NAVY TAMBIÉN SOBRE CORAL.
                //
                // "Juicio picante" venía con el texto en blanco, y blanco
                // sobre el coral de marca mide **3,31:1** — por debajo del
                // 4,5:1 que pide WCAG para texto de 14 px en negrita. Navy
                // sobre ese mismo coral mide 5,39:1.
                //
                // Y no es una preferencia mía: `AppColors.onAccent` ya vale
                // `textPrimary`, o sea que la paleta de la app ya había
                // decidido que sobre el coral va navy. Esta pestaña se
                // saltaba su propio token.
                color: isSelected ? _kDark : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
      ),
      ),
    );
  }
}
