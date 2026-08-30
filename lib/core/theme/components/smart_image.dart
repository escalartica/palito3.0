import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Todas las fotos de la app viven en Firebase Storage (URLs `https://`),
/// nunca en el almacenamiento local del dispositivo — así son visibles en
/// todos los móviles del grupo y en la PWA, que no tiene acceso al disco
/// del teléfono. Este widget es deliberadamente simple: no usa `dart:io`,
/// lo que lo hace compatible con Flutter Web.
///
/// Usa [CachedNetworkImage] en vez de [Image.network] porque las mismas
/// fotos de Cloudinary aparecen repetidas en la card, el mapa y el
/// detalle — sin caché de disco/memoria se re-descargarían en cada
/// aparición, gastando datos y tiempo en cada scroll.
class SmartImage extends StatelessWidget {
  final String? imagePath;
  final BoxFit fit;

  /// Ancho lógico (dp) al que se va a pintar la imagen. Si se indica y
  /// [imagePath] es una URL de Cloudinary, se pide una versión ya
  /// redimensionada/comprimida en vez de la foto original a resolución
  /// de cámara — evita descargar varios MB para una miniatura de unos
  /// pocos centímetros. Se deja sin usar (`null`) en las vistas donde sí
  /// se quiere ver la foto a máxima calidad (detalle a pantalla
  /// completa, previsualización del formulario).
  final int? width;

  const SmartImage({
    super.key,
    this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
  });

  /// Inserta una transformación de Cloudinary (`w_...,c_limit,q_auto,f_auto`)
  /// justo después de `/image/upload/`. Si [url] no tiene esa forma (no es
  /// de Cloudinary, o ya trae una transformación propia), se devuelve tal
  /// cual — nunca rompe una URL que no reconoce.
  static String _withCloudinaryResize(String url, int targetWidth) {
    const uploadMarker = '/image/upload/';
    final markerIndex = url.indexOf(uploadMarker);

    if (markerIndex == -1) {
      return url;
    }

    // *2 pensando en pantallas de alta densidad (retina); tope superior
    // para no pedir una transformación absurdamente grande por un uso
    // incorrecto del parámetro `width`.
    final requestedWidth = (targetWidth * 2).clamp(50, 1600);

    final insertAt = markerIndex + uploadMarker.length;

    return '${url.substring(0, insertAt)}'
        'w_$requestedWidth,c_limit,q_auto,f_auto/'
        '${url.substring(insertAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final rawUrl = imagePath?.trim();

    if (rawUrl == null || rawUrl.isEmpty || !rawUrl.startsWith('http')) {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    final url = width != null
        ? _withCloudinaryResize(rawUrl, width!)
        : rawUrl;

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (context, url) => Container(
        color: Colors.grey[100],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[100],
        child: const Icon(Icons.broken_image, color: Colors.orange),
      ),
    );
  }
}
