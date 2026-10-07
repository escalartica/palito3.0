import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../data/rating_scale.dart';
import '../../models/memory_model.dart';
import 'smart_image.dart';
import '../../utils/relative_date.dart';
import '../tokens/app_colors.dart';
import 'neo_pressable.dart';
import '../tokens/app_shape.dart';

// Paleta de colores neo-brutalista (alias locales sobre AppColors, la
// fuente única de verdad — ver core/theme/tokens/app_colors.dart).
const Color palitoDark = AppColors.textPrimary;
const Color palitoYellow = AppColors.primary;

// 1. Variante Compacta (Para listas principales)
class MemoryCardCompact extends StatelessWidget {
  final MemoryModel memory;
  const MemoryCardCompact({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    // Tomamos la primera imagen si existe
    final firstImageUrl = memory.imageUrls.isNotEmpty
        ? memory.imageUrls.first
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: NeoPressable(
        borderRadius: 16,
        borderWidth: 2,
        padding: const EdgeInsets.all(12),
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/memory-detail', extra: memory);
        },
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: palitoDark, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: firstImageUrl != null
                        ? Hero(
                            tag: 'memory-image-${memory.id}',
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: SmartImage(
                                imagePath: firstImageUrl,
                                fit: BoxFit.cover,
                                width: 60,
                                semanticLabel: memory.title,
                              ),
                            ),
                          )
                        // Relleno "sin imagen": un tinte del propio navy de
                        // marca en vez de un gris neutro suelto, para que el
                        // hueco de foto no desentone con el resto del token.
                        : Container(
                            width: 60,
                            height: 60,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.08,
                            ),
                          ),
                  ),
                ),
                if (memory.isRecent)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: palitoYellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: palitoDark, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: palitoDark,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Dónde fue, cuando el titular ya dice qué se comió.
                  //
                  // Desde que el formulario pregunta el plato, `title` es el
                  // plato y no el bar. Sin esta línea, Inicio pasaría a ser
                  // una lista de platos sin sitio — y el sitio es justo lo
                  // que uno busca cuando quiere volver.
                  //
                  // Solo aparece cuando los dos son distintos: en los
                  // recuerdos guardados antes de este cambio son iguales, y
                  // ahí sigue saliendo una sola línea, como siempre.
                  // ── DÓNDE Y CUÁNDO, EN LA MISMA LÍNEA ──
                  //
                  // La fecha estaba abajo, peleando por el sitio con la
                  // categoría y la nota. Tres datos en una fila de 180
                  // puntos no caben, y repartir mejor solo cambia a quién
                  // se recorta: con nota puesta, «Croquetas» salía «Cr…».
                  //
                  // Pero es que la fecha no pertenece a esa fila. Va con el
                  // sitio: dónde fue y cuándo fue son la misma pregunta, y
                  // esta línea tiene hueco de sobra porque el nombre de un
                  // bar rara vez lo llena.
                  //
                  // `Wrap` y no `Row`: si con el texto del sistema ampliado
                  // dejan de caber, la fecha baja sola a la línea de abajo
                  // en vez de desbordar. Es lo mismo que hace un párrafo, y
                  // no hace falta medir nada para conseguirlo.
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 2,
                    children: <Widget>[
                      if (memory.restaurantName.trim().isNotEmpty &&
                          memory.restaurantName.trim().toLowerCase() !=
                              memory.title.trim().toLowerCase())
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.storefront_rounded,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            // ── `Flexible`, NO UN TOPE EN PUNTOS ──
                            //
                            // Aquí había un `ConstrainedBox(maxWidth: 150)`.
                            // Un número fijo solo funciona mientras el hueco
                            // sea mayor que él, y en un iPhone SE con el
                            // texto al 310 % esta columna mide 116: el
                            // nombre del bar pedía sus 150, nadie se los
                            // negaba y la fila se salía 50 pixels. Lo cazan
                            // las pruebas de texto ampliado.
                            //
                            // `Flexible` no necesita saber cuánto hay: coge
                            // lo que quede después del icono, sea 116 o sea
                            // 400, y el `ellipsis` se encarga del resto. Un
                            // tope en puntos es una medida adivinada; esto
                            // es la medida de verdad.
                            Flexible(
                              child: Text(
                                memory.restaurantName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      Text(
                        relativeDate(memory.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // ── QUÉ ERA Y QUÉ TAL ──
                  //
                  // Sin la fecha, esta fila vuelve a tener sitio para lo
                  // suyo: la categoría entera y la nota. También en `Wrap`,
                  // por lo mismo que arriba.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWarm,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            border: Border.all(color: palitoDark, width: 1.5),
                          ),
                          child: Text(
                            memory.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: palitoDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (RatingScale.isRated(memory.rating))
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFB58100),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              RatingScale.shortLabel(memory.rating)!,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: palitoDark,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: palitoDark,
            ),
          ],
        ),
      ),
    );
  }
}
