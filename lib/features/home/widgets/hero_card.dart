import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart'; // Añadido para mantener las tipografías
import '../../memory_form/widgets/smart_image.dart'; 
import '../../../core/models/memory_model.dart';

class HeroCard extends ConsumerWidget {
  final MemoryModel? memory;

  const HeroCard({super.key, this.memory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (memory == null) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.35,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF0F172A), width: 2.0),
          boxShadow: const [
            BoxShadow(color: Color(0xFF0F172A), blurRadius: 0, offset: Offset(0, 4))
          ],
        ),
        child: Center(
          child: Text(
            "Aún no tienes recuerdos",
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      );
    }

    final String? path = (memory!.imageUrls.isNotEmpty) ? memory!.imageUrls.first : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0F172A), width: 2.0),
        boxShadow: const [
          BoxShadow(color: Color(0xFF0F172A), blurRadius: 0, offset: Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          // Imagen de fondo o placeholder
          Positioned.fill(
            child: (path != null && path.isNotEmpty)
                ? SmartImage(imagePath: path, fit: BoxFit.cover)
                : Container(
                    color: const Color(0xFFF8FAFC), 
                    child: const Icon(Icons.image_rounded, size: 50, color: Color(0xFF0F172A)),
                  ),
          ),
          
          // Gradiente inferior para legibilidad del texto
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color(0xFF0F172A).withValues(alpha: 0.85), 
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          // Contenido de texto con tipografías Outfit / Inter
          Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory!.title, 
                    style: GoogleFonts.outfit(
                      color: Colors.white, 
                      fontSize: 22, 
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.store_rounded, size: 14, color: Color(0xFFFFD400)),
                      const SizedBox(width: 6),
                      Text(
                        memory!.restaurantName, 
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFD400), 
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}