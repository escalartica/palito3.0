import 'package:flutter/material.dart';
import '../../models/memory_model.dart';
import 'smart_image.dart';
import '../tokens/app_colors.dart';

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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palitoDark, width: 2),
        boxShadow: const [
          BoxShadow(color: palitoDark, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          children: [
            // 1. Imagen de fondo inteligente (o estado vacío si no hay foto)
            Positioned.fill(
              child: imageUrl != null
                  ? SmartImage(
                      imagePath: imageUrl,
                      fit: BoxFit.cover,
                      width: 800,
                    )
                  : _buildEmptyImage(),
            ),

            // 2. Gradiente oscuro inferior para mejorar la lectura del texto
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.3),
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
                        borderRadius: BorderRadius.circular(8),
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
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palitoDark, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: palitoDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // 4. Título principal en la parte inferior
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF6D6), palitoYellow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
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
            'Aún sin foto — ¡sube la primera!',
            style: TextStyle(
              color: palitoDark.withValues(alpha: 0.65),
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
