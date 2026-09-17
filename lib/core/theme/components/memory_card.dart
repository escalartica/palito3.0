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
                  if (memory.restaurantName.trim().isNotEmpty &&
                      memory.restaurantName.trim().toLowerCase() !=
                          memory.title.trim().toLowerCase()) ...<Widget>[
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.storefront_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
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
                  ],

                  const SizedBox(height: 4),
                  // Sin `Flexible` ni `ellipsis`, una categoría larga
                  // ("Decoración / Espacio") desbordaba la fila con la
                  // franja amarilla y negra en la lista principal de
                  // Inicio — la pantalla más vista de la app.
                  Row(
                    children: [
                      Flexible(
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
                      if (RatingScale.isRated(memory.rating)) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          // Oro de estrella, deliberadamente distinto del
                          // amarillo de marca: sobre `surfaceWarm` el
                          // primary (#FFD400) casi desaparece por falta de
                          // contraste con el fondo, así que la estrella
                          // necesita su propio tono, más oscuro.
                          color: Color(0xFFB58100),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          RatingScale.shortLabel(memory.rating)!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: palitoDark,
                          ),
                        ),
                      ],

                      // CUÁNDO FUE.
                      //
                      // No estaba en ninguna parte de la app. En un diario
                      // de comidas, «¿fui la semana pasada o hace un año?»
                      // es de las primeras cosas que uno quiere saber al
                      // mirar la lista, y el único indicio de recencia era
                      // un punto amarillo de 14 píxeles que solo dura cinco
                      // minutos y no lleva etiqueta.
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          relativeDate(memory.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
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
