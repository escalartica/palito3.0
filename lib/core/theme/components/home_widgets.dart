import 'package:flutter/material.dart';
import '../../models/memory_model.dart';
import 'smart_image.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_shape.dart';
import '../tokens/app_typography.dart';

// Paleta de colores neo-brutalista (alias locales sobre AppColors, la
// fuente única de verdad — ver core/theme/tokens/app_colors.dart).
const Color palitoDark = AppColors.textPrimary;
const Color palitoYellow = AppColors.primary;

class HomeHero extends StatelessWidget {
  final MemoryModel? memory;

  const HomeHero({super.key, this.memory});

  @override
  Widget build(BuildContext context) {
    // Solo mostramos una imagen real del propio recuerdo. Antes, si no
    // había foto, se rellenaba con una foto de stock de un restaurante
    // aleatorio de Unsplash — parecía una foto real del sitio/plato
    // cuando no lo era. Mejor ser honestos: mostramos un estado vacío
    // reconocible en vez de una imagen que no tiene nada que ver.
    final imageUrl = (memory != null && memory!.imageUrls.isNotEmpty)
        ? memory!.imageUrls.first
        : null;

    final title = memory?.title ?? "Tu mejor experiencia";
    final category = memory?.category ?? "Palito";
    final rating = memory?.rating;

    return Container(
      width: double.infinity,
      // Margen exterior y la sombra dura característica del estilo brutalista
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: palitoDark, width: 2),
        boxShadow: const [
          BoxShadow(color: palitoDark, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: ClipRRect(
        // Concéntrico con el borde xl (2 px) del Container que lo envuelve.
        borderRadius: BorderRadius.circular(AppRadius.xl - AppBorder.normal),
        child: Stack(
          children: [
            // 1. Imagen de fondo inteligente (o estado vacío si no hay foto)
            Positioned.fill(
              child: imageUrl != null
                  ? SmartImage(
                      imagePath: imageUrl,
                      fit: BoxFit.cover,
                      // La tarjeta se pinta a unos 306 dp en un iPhone de
                      // 390 pt. Pedía 800 dp, que con el `*2` que llevaba
                      // dentro `SmartImage` eran 1600 px para un hueco de
                      // 918: **tres veces el área**, descargada por la red
                      // del usuario y decodificada en su memoria.
                      width: 340,
                    )
                  : _buildEmptyImage(),
            ),

            // 2. Velo oscuro inferior para poder leer el texto blanco SOBRE
            //    LA FOTO. Antes se pintaba siempre, también cuando no había
            //    ninguna foto: el resultado era que la tarjeta destacada de
            //    un diario recién estrenado —lo primero que ve alguien que se
            //    acaba de descargar la app— aparecía como un degradado
            //    dorado emborronado hacia el negro, el único degradado sucio
            //    de una interfaz que por lo demás es de colores planos.
            if (imageUrl != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    // Navy, no negro puro: mismo criterio que el resto de
                    // la marca (bordes y sombras usan textPrimary, nunca
                    // negro).
                    gradient: LinearGradient(
                      colors: [
                        AppColors.textPrimary.withValues(alpha: 0.85),
                        AppColors.textPrimary.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),

            // 3. Píldora superior con la categoría y puntuación (si existe recuerdo)
            if (memory != null)
              Positioned(
                top: 16,
                left: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: palitoYellow,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(color: palitoDark, width: 2),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          color: palitoDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (rating != null && rating > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(color: palitoDark, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              // Mismo oro de estrella que memory_card.dart —
                              // ver ahí la razón de no usar el amarillo de
                              // marca.
                              color: Color(0xFFB58100),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: palitoDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                fontFeatures: AppTypography.tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // 4. Título principal en la parte inferior — solo si hay un
            //    recuerdo de verdad. Sin recuerdos, la versión anterior
            //    seguía rotulando "PLATO ESTRELLA / Tu mejor experiencia",
            //    que prometía algo que no existe y dejaba al usuario
            //    buscando cuál era ese plato.
            if (memory != null)
              Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "PLATO ESTRELLA",
                      style: TextStyle(
                        color: palitoYellow,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Solo se ve cuando NINGÚN recuerdo de la categoría seleccionada tiene
  // foto todavía (el caso normal es que la portada ya elige automáticamente
  // el mejor valorado que SÍ tenga foto — ver home_page.dart). Con el mismo
  // botón circular de cámara que ya se usa en el formulario, para que se
  // sienta parte del mismo sistema visual en vez de un relleno genérico.
  Widget _buildEmptyImage() {
    return Container(
      // Amarillo plano de marca, en tinte pálido. El degradado que había
      // aquí era, junto con el velo negro de arriba, lo que ensuciaba la
      // tarjeta.
      color: AppColors.primary.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palitoYellow,
              shape: BoxShape.circle,
              border: Border.all(color: palitoDark, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: palitoDark,
                  blurRadius: 0,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 24,
              color: palitoDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tu mejor plato aparecerá aquí',
            style: const TextStyle(
              color: palitoDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'El recuerdo con mejor nota y foto de este diario',
            textAlign: TextAlign.center,
            // 0,65 de opacidad sobre amarillo dejaba este texto en el límite
            // de lo legible; el gris de marca cumple AA de sobra.
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: palitoDark,
        letterSpacing: -0.5,
      ),
    ),
  );
}
