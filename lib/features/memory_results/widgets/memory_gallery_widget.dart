import 'package:flutter/material.dart';
import '../../../core/theme/components/smart_image.dart';

class MemoryGalleryWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const MemoryGalleryWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Obtenemos la lista de URLs del modelo o el campo individual
    final List<dynamic>? imageUrls = data['imageUrls'];
    final String? imagePath = (imageUrls != null && imageUrls.isNotEmpty)
        ? imageUrls.first
        : data['image_path'];
    final String? videoPath = data['video_path'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Galería del Recuerdo",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),

        // Imagen Principal con manejo de estado
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: (imagePath != null && imagePath.isNotEmpty)
              ? SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: SmartImage(imagePath: imagePath),
                )
              : Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image, size: 50, color: Colors.grey),
                ),
        ),

        // Botón de Vídeo si existe
        if (videoPath != null && videoPath.isNotEmpty) ...[
          const SizedBox(height: 15),
          ListTile(
            onTap: () {
              // Lógica de navegación a vídeo
            },
            leading: const Icon(
              Icons.play_circle_fill,
              color: Colors.indigoAccent,
              size: 40,
            ),
            title: const Text("Ver momento ambiente"),
            subtitle: const Text("Toca para revivir el sonido y el entorno"),
            tileColor: Colors.indigoAccent.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ],
    );
  }
}
