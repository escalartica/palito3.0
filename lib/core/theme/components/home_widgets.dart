import 'package:flutter/material.dart';
import '../../models/memory_model.dart'; 
import '../../../features/memory_form/widgets/smart_image.dart'; 

class HomeHero extends StatelessWidget {
  final MemoryModel? memory;

  const HomeHero({super.key, this.memory});

  @override
  Widget build(BuildContext context) {
    // Obtenemos la primera imagen si existe, o usamos la predeterminada
    final imageUrl = (memory != null && memory!.imageUrls.isNotEmpty) 
        ? memory!.imageUrls.first 
        : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800';
        
    final title = memory?.title ?? "Tu mejor experiencia gastronómica";

    return Container(
      height: 340,
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      // Usamos ClipRRect para que la imagen de fondo respete los bordes redondeados del Stack
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // 1. Imagen de fondo inteligente usando SmartImage directamente
            Positioned.fill(
              child: SmartImage(imagePath: imageUrl, fit: BoxFit.cover),
            ),
            // 2. Gradiente y Texto encima de la imagen
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.bottomLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 26, 
                    fontWeight: FontWeight.bold,
                  ),
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
    child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
  );
}