import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SmartImage extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;

  const SmartImage({super.key, required this.imagePath, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (imagePath.trim().isEmpty) {
      return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey));
    }

    // 1. Si es una URL de internet
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: fit,
        errorBuilder: (_, _, _) => const Icon(Icons.error, color: Colors.redAccent),
      );
    }

    // 2. Si es una ruta absoluta antigua (comienza con /)
    // Esto evita que intentemos concatenar la ruta de documentos dos veces
    if (imagePath.startsWith('/')) {
      final oldFile = File(imagePath);
      if (oldFile.existsSync()) {
        return Image.file(oldFile, fit: fit, errorBuilder: (_, _, _) => const Icon(Icons.broken_image));
      }
    }

    // 3. Si es un nombre de archivo local (el formato nuevo)
    return FutureBuilder<Directory>(
      future: getApplicationDocumentsDirectory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final fullPath = '${snapshot.data!.path}/$imagePath';
        final file = File(fullPath);

        if (file.existsSync()) {
          return Image.file(
            file,
            fit: fit,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.orange),
          );
        }

        // Si no existe, no hacemos ruido, simplemente mostramos el icono
        return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
      },
    );
  }
}