import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/theme/tokens/app_animation.dart';
import '../../../core/theme/components/app_motion.dart';

/// El título de la tarjeta de resumen de La ruleta.
///
/// La hoja de «Cómo se juega» lo nombra por escrito para decir dónde se
/// ponen los puntos a cero. Si el título cambia y esa frase no, las
/// instrucciones del juego mandan a un sitio que no existe.
const String kResumenDeLaPartida = 'Resumen de la partida';

class ZonaGamerCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final VoidCallback onTap;

  const ZonaGamerCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  State<ZonaGamerCard> createState() => _ZonaGamerCardState();
}

class _ZonaGamerCardState extends State<ZonaGamerCard> {
  static const Offset _restOffset = Offset(4, 4);
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final currentShadowOffset = _pressed ? Offset.zero : _restOffset;
    final translation = _pressed ? _restOffset : Offset.zero;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: AppMotion.dur(context, AppAnimation.press),
        curve: AppAnimation.enter,
        transform: Matrix4.translationValues(translation.dx, translation.dy, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          // Color plano. El degradado era el único de esta pantalla y no
          // encaja con un lenguaje de bordes duros y sombras macizas: lo que
          // da profundidad aquí es el desplazamiento, no el difuminado.
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.textPrimary, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary,
              offset: currentShadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── ESTA FILA TENÍA QUE PODER ENCOGER Y NO PODÍA ──
            //
            // La `Row` de dentro (icono + textos) no llevaba `Expanded`, así
            // que pedía todo el ancho que necesitara su texto más largo. Y
            // el subtítulo dejó de ser fijo el día que pasó a contar las
            // decisiones de la partida: "3 decisiones · puntos, historial e
            // insignias" no cabe, y Flutter pintaba encima la banda amarilla
            // y negra de `OVERFLOWED BY 0.0965 PIXELS`.
            //
            // Nueve centésimas de píxel, que en compilación de depuración
            // son un cartel de obra en mitad de la pantalla y en release son
            // una palabra recortada en seco. Se veía en La ruleta desde que
            // cambié ese subtítulo.
            Expanded(
              child: Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _pressed ? 0.85 : 1),
                    duration: AppMotion.dur(context, AppAnimation.press),
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          // Dos líneas, no una: el subtítulo cuenta las
                          // decisiones de la partida y con el texto del
                          // sistema ampliado una sola línea lo dejaría en
                          // "3 decisiones · punt…", que es peor que
                          // partirlo.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedSlide(
              duration: AppMotion.dur(context, AppAnimation.fast),
              curve: AppAnimation.enter,
              offset: _pressed ? const Offset(0.15, 0) : Offset.zero,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
