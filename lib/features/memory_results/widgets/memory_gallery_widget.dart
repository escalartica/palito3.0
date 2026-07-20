import 'package:flutter/material.dart';
// Asumiendo que tu widget SmartImage está en esta ruta
import '../../memory_form/widgets/smart_image.dart'; 

class MemoryGalleryWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const MemoryGalleryWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final String? imagePath = data['image_path'];
    final String? videoPath = data['video_path'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Galería del Recuerdo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        
        // Imagen Principal
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: imagePath != null 
              ? SmartImage(imagePath: imagePath)
              : Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.image, size: 50)),
        ),

        // Botón de Vídeo si existe
        if (videoPath != null) ...[
          const SizedBox(height: 15),
          ListTile(
            onTap: () {
              // Aquí dispararías la navegación a tu reproductor de vídeo
            },
            leading: const Icon(Icons.play_circle_fill, color: Colors.indigoAccent, size: 40),
            title: const Text("Ver momento ambiente (15s)"),
            subtitle: const Text("Toca para revivir el sonido y el entorno"),
            tileColor: Colors.indigoAccent.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ],
      ],
    );
  }
}