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
                  //
                  // El `LayoutBuilder` está aquí para poder ponerle TECHO a
                  // la fecha en proporción al ancho real de la fila. Ver el
                  // comentario largo de más abajo: es lo que permite que la
                  // categoría se quede con lo que sobra sin que nada
                  // desborde cuando el texto del sistema está al 310 %.
                  // CUANDO NO CABE EN UNA LÍNEA, SE PARTE EN DOS.
                  //
                  // Esta fila lleva tres cosas: la categoría, la nota y
                  // cuándo fue. En un iPhone SE con el texto del sistema al
                  // 310 % no caben las tres en una línea — no es cuestión de
                  // repartir mejor el hueco, es que no hay hueco. La versión
                  // anterior "pasaba" la prueba porque todo era flexible y
                  // todo se recortaba: la categoría quedaba en «Pla…», la
                  // nota en un número a medias. Pasar no es lo mismo que
                  // funcionar.
                  //
                  // Así que por encima de 1,6 —el punto donde las tres dejan
                  // de caber— la fecha se va a su propia línea y las otras
                  // dos respiran. Es lo que haría cualquiera al maquetarlo a
                  // mano, y es exactamente lo que pide el tamaño de letra
                  // que ha elegido esa persona: menos apretado, no más
                  // recortado.
                  Builder(
                    builder: (BuildContext context) {
                      final double escala = MediaQuery.textScalerOf(
                        context,
                      ).scale(1);

                      final Widget categoria = Flexible(
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
                      );

                      final List<Widget> nota = <Widget>[
                        if (RatingScale.isRated(memory.rating)) ...<Widget>[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFB58100),
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              RatingScale.shortLabel(memory.rating)!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: palitoDark,
                              ),
                            ),
                          ),
                        ],
                      ];

                      final Widget cuando = Text(
                        relativeDate(memory.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      );

                      if (escala > 1.6) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(children: <Widget>[categoria, ...nota]),
                            const SizedBox(height: 4),
                            cuando,
                          ],
                        );
                      }

                      // En una línea, la fecha sale del reparto flexible
                      // —así la categoría se lleva lo que sobra en vez de
                      // la mitad justa, que es lo que dejaba «Plato Estr…»
                      // con sitio libre al lado— pero con techo, para que
                      // nunca empuje a las otras fuera de la fila.
                      return LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints fila) => Row(
                              children: <Widget>[
                                categoria,
                                ...nota,
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: fila.maxWidth * 0.45,
                                  ),
                                  child: cuando,
                                ),
                              ],
                            ),
                      );
                    },
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
