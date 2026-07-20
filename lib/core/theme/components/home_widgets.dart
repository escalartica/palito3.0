import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/memory_model.dart'; 

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
            // 1. Imagen de fondo inteligente
            Positioned.fill(
              child: _HeroImageBackground(imagePath: imageUrl),
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

/// Widget auxiliar interno para resolver de forma asíncrona e inteligente 
/// la imagen de fondo del Hero sin bloquear la interfaz.
class _HeroImageBackground extends StatelessWidget {
  final String imagePath;

  const _HeroImageBackground({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    if (imagePath.trim().isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
      );
    }

    // Caso 1: URL de Internet
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.error, color: Colors.redAccent),
        ),
      );
    }

    // Caso 2: Ruta absoluta antigua (comienza con /)
    if (imagePath.startsWith('/')) {
      final oldFile = File(imagePath);
      if (oldFile.existsSync()) {
        return Image.file(
          oldFile, 
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: Colors.grey[300]),
        );
      }
    }

    // Caso 3: Nombre de archivo local (Formato nuevo con UUID)
    return FutureBuilder<Directory>(
      future: getApplicationDocumentsDirectory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final fullPath = '${snapshot.data!.path}/$imagePath';
        final file = File(fullPath);

        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, color: Colors.orange),
            ),
          );
        }

        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
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