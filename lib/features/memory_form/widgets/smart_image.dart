import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class SmartImage extends StatelessWidget {
  final String? imagePath;
  final BoxFit fit;

  const SmartImage({super.key, this.imagePath, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    // 1. Validación inicial: si no hay path, mostramos icono de error
    if (imagePath == null || imagePath!.trim().isEmpty) {
      return Container(
        color: Colors.grey[200], 
        child: const Icon(Icons.image_not_supported, color: Colors.grey)
      );
    }

    // 2. Si es una URL de internet, cargamos directamente
    if (imagePath!.startsWith('http')) {
      return Image.network(
        imagePath!,
        fit: fit,
        errorBuilder: (_, _, _) => const Icon(Icons.error, color: Colors.red),
      );
    }

    // 3. Carga local: Usamos ApplicationDocumentsDirectory para asegurar persistencia real en iOS
    return FutureBuilder<Directory>(
      future: getApplicationDocumentsDirectory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[100], 
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2))
          );
        }

        if (snapshot.hasData) {
          // Limpiamos el nombre del archivo (por si viniera con rutas previas)
          final String fileName = path.basename(imagePath!);
          final File file = File(path.join(snapshot.data!.path, fileName));

          if (file.existsSync()) {
            return Image.file(
              file,
              fit: fit,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.orange),
            );
          } else {
            debugPrint("SmartImage: Archivo no encontrado en ${file.path}");
          }
        }

        // Si no existe o falló la carga
        return Container(
          color: Colors.grey[100], 
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
  }
}