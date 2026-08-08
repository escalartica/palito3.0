import 'package:flutter/material.dart';

/// Todas las fotos de la app viven en Firebase Storage (URLs `https://`),
/// nunca en el almacenamiento local del dispositivo — así son visibles en
/// todos los móviles del hogar y en la PWA, que no tiene acceso al disco
/// del teléfono. Este widget es deliberadamente simple: no usa `dart:io`,
/// lo que lo hace compatible con Flutter Web.
class SmartImage extends StatelessWidget {
  final String? imagePath;
  final BoxFit fit;

  const SmartImage({super.key, this.imagePath, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final url = imagePath?.trim();

    if (url == null || url.isEmpty || !url.startsWith('http')) {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.grey[100],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[100],
        child: const Icon(Icons.broken_image, color: Colors.orange),
      ),
    );
  }
}
