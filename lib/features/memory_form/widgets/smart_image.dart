import 'dart:io';
import 'package:flutter/material.dart';

class SmartImage extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;

  const SmartImage({super.key, required this.imagePath, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    // 1. Mejora de validación: Si la ruta está vacía o solo son espacios, mostramos un icono de advertencia
    if (imagePath.trim().isEmpty) {
      return const Icon(Icons.image_not_supported, color: Colors.grey);
    }

    // 2. Si la ruta empieza con http, es de internet
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath, 
        fit: fit, 
        errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.redAccent),
      );
    }
    
    // 3. Si no, es un archivo local del dispositivo
    final file = File(imagePath);
    if (file.existsSync()) {
      return Image.file(file, fit: fit);
    }

    // 4. Fallback si la imagen no existe en la ruta local
    return const Icon(Icons.broken_image, color: Colors.grey);
  }
}