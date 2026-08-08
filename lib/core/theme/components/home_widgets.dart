import 'package:flutter/material.dart';
import '../../models/memory_model.dart';
import '../../../features/memory_form/widgets/smart_image.dart';

// Paleta de colores neo-brutalista
const Color palitoDark = Color(0xFF0F172A);
const Color palitoYellow = Color(0xFFFFD400);

class HomeHero extends StatelessWidget {
  final MemoryModel? memory;

  const HomeHero({super.key, this.memory});

  @override
  Widget build(BuildContext context) {
    // Obtenemos la primera imagen si existe, o usamos una por defecto
    final imageUrl = (memory != null && memory!.imageUrls.isNotEmpty)
        ? memory!.imageUrls.first
        : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800';

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
            // 1. Imagen de fondo inteligente
            Positioned.fill(
              child: SmartImage(imagePath: imageUrl, fit: BoxFit.cover),
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
