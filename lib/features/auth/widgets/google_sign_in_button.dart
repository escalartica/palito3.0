import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/components/app_motion.dart';

/// ══ EL BOTÓN DE GOOGLE ══
///
/// No es un botón de Palito: es el botón de Google, y Google publica unas
/// normas de marca que hay que respetar si la app usa su identificación.
/// Por eso rompe deliberadamente con el resto de la interfaz (nada de borde
/// negro grueso ni sombra maciza) y por eso no admite colores a medida.
///
/// Lo que las normas fijan y aquí se cumple:
///  · La «G» de cuatro colores sin recortar ni recolorear, con su espacio
///    libre alrededor.
///  · Fondo blanco, texto #1F1F1F, borde #747775.
///  · El texto dice «Continuar con Google» —una de las fórmulas admitidas—,
///    nunca algo inventado.
///
/// LA TIPOGRAFÍA. Google pide Roboto. La app empaqueta sus fuentes y tiene
/// `allowRuntimeFetching = false` (ver `fuentes_empaquetadas_test.dart`), así
/// que meter Roboto solo para este botón añadiría un fichero de fuente entero
/// al tamaño de descarga. Se usa Inter Medium, que es la otra grotesca neutra
/// de la app y se parece lo bastante como para que nadie note la diferencia
/// en tres palabras.
///
/// EL LOGO NO ES UN ICONO DE MATERIAL ni una «G» dibujada a mano: es el PNG
/// oficial en `assets/images/google_g.png`, con sus variantes 2x y 3x.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Continuar con Google',
  });

  final VoidCallback onPressed;

  /// «Continuar con Google» en la pantalla de entrada; «Añadir Google» en el
  /// perfil. Las dos son fórmulas que Google admite.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressScale(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF747775)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 20 puntos es la medida que fija Google para un botón de esta
              // altura. `cacheWidth` a 60 = 20 × 3, el factor de pantalla más
              // alto que existe en un móvil.
              Image.asset(
                'assets/images/google_g.png',
                width: 20,
                height: 20,
                cacheWidth: 60,
                // Vacío a propósito: el `Semantics` de arriba ya nombra el
                // botón entero. Con etiqueta propia, VoiceOver leería
                // «Logotipo de Google, Continuar con Google».
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 12),
              // `Flexible`, no un `Text` suelto: con la letra del sistema
              // ampliada al 310 % «Continuar con Google» no cabe en el ancho
              // de un iPhone, y un `Row` sin medir revienta el layout en vez
              // de recortar.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1F1F1F),
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
