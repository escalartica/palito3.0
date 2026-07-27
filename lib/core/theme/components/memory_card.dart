import 'package:flutter/material.dart';
import '../../models/memory_model.dart';
import '../../../features/home/memory_detail_page.dart';
import '../../../features/memory_form/widgets/smart_image.dart';

// Paleta de colores neo-brutalista
const Color palitoDark = Color(0xFF1A1A1A);
const Color palitoYellow = Color(0xFFFFD400);

// 1. Variante Compacta (Para listas principales)
class MemoryCardCompact extends StatelessWidget {
  final MemoryModel memory;
  const MemoryCardCompact({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    // Tomamos la primera imagen si existe
    final firstImageUrl = memory.imageUrls.isNotEmpty ? memory.imageUrls.first : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palitoDark, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: palitoDark,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MemoryDetailPage(memory: memory)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palitoDark, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: firstImageUrl != null
                            ? SizedBox(
                                width: 60,
                                height: 60,
                                child: SmartImage(imagePath: firstImageUrl, fit: BoxFit.cover),
                              )
                            : Container(width: 60, height: 60, color: Colors.grey.shade200),
                      ),
                    ),
                    if (memory.isRecent)
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: palitoYellow, 
                            shape: BoxShape.circle, 
                            border: Border.all(color: palitoDark, width: 2)
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: palitoDark, width: 1.5),
                            ),
                            child: Text(
                              memory.category, 
                              style: const TextStyle(
                                color: palitoDark, 
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (memory.rating > 0) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              memory.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: palitoDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: palitoDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 2. Variante Grande (Para el scroll horizontal)
class MemoryCardLarge extends StatelessWidget {
  final MemoryModel? memory;
  const MemoryCardLarge({super.key, this.memory});

  @override
  Widget build(BuildContext context) {
    final firstImageUrl = (memory != null && memory!.imageUrls.isNotEmpty) ? memory!.imageUrls.first : null;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palitoDark, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: palitoDark,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: memory == null ? null : () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MemoryDetailPage(memory: memory!)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: firstImageUrl != null
                      ? SmartImage(imagePath: firstImageUrl, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade100, child: const Center(child: Icon(Icons.image, size: 40, color: Colors.grey))),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(21),
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Text(
                  memory?.title ?? "Recuerdo destacado",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}