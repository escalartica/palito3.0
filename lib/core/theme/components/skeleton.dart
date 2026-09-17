import 'package:flutter/material.dart';

import '../tokens/app_animation.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_shape.dart';
import 'app_motion.dart';

/// ===========================================================================
/// EL HUECO DE LO QUE VIENE
/// ===========================================================================
///
/// Un bloque gris con la forma de lo que se está cargando.
///
/// POR QUÉ ESTO Y NO UN RULETÍN. Mientras Inicio cargaba, la pantalla
/// enseñaba una tarjeta con un indicador dando vueltas y "Cargando tus
/// recuerdos…". Eso dice que hay que esperar, y nada más. Un esqueleto dice
/// además **qué va a venir y qué tamaño tiene**, y eso hace dos cosas que el
/// ruletín no puede hacer:
///
///   1. **La pantalla no pega un salto al llegar los datos.** Con el
///      indicador, el contenido aparecía de golpe en un hueco que no existía
///      un momento antes y todo se recolocaba. Con el esqueleto, lo que
///      llega ocupa el sitio que ya estaba ocupado.
///   2. **La espera se percibe más corta.** No es una impresión: una
///      pantalla que ya tiene estructura se lee como una pantalla que ya casi
///      está, aunque el cronómetro diga exactamente lo mismo.
///
/// EL LATIDO ES DE OPACIDAD, NO UN BRILLO QUE BARRE. El barrido diagonal de
/// las apps que lo llevan es un degradado moviéndose, y hay que repintarlo
/// entero en cada fotograma. Una opacidad que va y viene la compone la GPU
/// sin volver a dibujar nada, se lee igual de bien como "esto todavía no
/// está", y no hace ruido: esto tiene que verse poco, no lucirse.
///
/// Con "Reducir movimiento" no late: se queda quieto, y sigue diciendo lo
/// mismo.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppRadius.sm,
  });

  /// `double.infinity` para ocupar lo que le den.
  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppAnimation.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.stop();
      _c.value = 1.0;
    } else if (!_c.isAnimating) {
      // Ida y vuelta, no un salto al empezar de nuevo: `repeat(reverse: true)`
      // hace que el latido no tenga costura.
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c.drive(
        Tween<double>(
          begin: 0.55,
          end: 1.0,
        ).chain(CurveTween(curve: AppAnimation.tint)),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.tintMuted,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// El hueco de una fila de recuerdo: foto a la izquierda, dos líneas de texto.
///
/// Las medidas salen de `MemoryCardCompact`, no de la nada: si el esqueleto
/// no tiene el tamaño de lo que viene, no sirve para lo único que tiene que
/// servir — que al llegar el contenido no se mueva nada.
class MemoryRowSkeleton extends StatelessWidget {
  const MemoryRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.textPrimary,
          width: AppBorder.normal,
        ),
        boxShadow: AppShadow.sm,
      ),
      child: Row(
        children: const <Widget>[
          Skeleton(width: 62, height: 62, radius: AppRadius.sm),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Skeleton(width: 140, height: 15),
                SizedBox(height: 9),
                Skeleton(width: 90, height: 12),
                SizedBox(height: 9),
                Skeleton(width: 110, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
