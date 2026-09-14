import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Las fotos de la app viven en Cloudinary (URLs `https://`), nunca en el
/// almacenamiento local del dispositivo — así son visibles en todos los
/// móviles del grupo y en la PWA, que no tiene acceso al disco del teléfono.
/// Este widget es deliberadamente simple: no usa `dart:io`, lo que lo hace
/// compatible con Flutter Web.
///
/// Usa [CachedNetworkImage] en vez de [Image.network] porque las mismas fotos
/// aparecen repetidas en la card, el mapa y el detalle — sin caché se
/// re-descargarían en cada aparición.
class SmartImage extends StatefulWidget {
  const SmartImage({
    super.key,
    this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.semanticLabel,
  });

  final String? imagePath;
  final BoxFit fit;

  /// Ancho lógico (dp) al que se va a pintar la imagen. Si se indica y
  /// [imagePath] es una URL de Cloudinary, se pide una versión ya
  /// redimensionada en vez de la foto original a resolución de cámara.
  final int? width;

  /// Descripción para lectores de pantalla. Sin ella, las fotos de los
  /// recuerdos eran elementos mudos para VoiceOver.
  final String? semanticLabel;

  /// Inserta una transformación de Cloudinary (`w_...,c_limit,q_auto,f_auto`)
  /// justo después de `/image/upload/`. Si [url] no tiene esa forma, o ya
  /// trae una transformación propia, se devuelve tal cual.
  static String _withCloudinaryResize(String url, int targetWidth) {
    const String uploadMarker = '/image/upload/';
    final int markerIndex = url.indexOf(uploadMarker);

    if (markerIndex == -1) return url;

    final int insertAt = markerIndex + uploadMarker.length;
    final String rest = url.substring(insertAt);

    // El comentario original decía que respetaba las URLs que ya traen una
    // transformación, pero no lo comprobaba: insertaba la suya igualmente.
    final String firstSegment = rest.split('/').first;
    final bool alreadyTransformed =
        firstSegment.contains(',') ||
        firstSegment.startsWith('w_') ||
        firstSegment.startsWith('c_') ||
        firstSegment.startsWith('q_') ||
        firstSegment.startsWith('f_');

    if (alreadyTransformed) return url;

    // *2 pensando en pantallas de alta densidad; tope superior para no pedir
    // una transformación absurda por un uso incorrecto del parámetro.
    final int requestedWidth = (targetWidth * 2).clamp(50, 1600).toInt();

    return '${url.substring(0, insertAt)}'
        'w_$requestedWidth,c_limit,q_auto,f_auto/'
        '$rest';
  }

  @override
  State<SmartImage> createState() => _SmartImageState();
}

class _SmartImageState extends State<SmartImage> {
  int _retryToken = 0;

  @override
  Widget build(BuildContext context) {
    final String? rawUrl = widget.imagePath?.trim();

    if (rawUrl == null || rawUrl.isEmpty) {
      return _Placeholder(
        icon: Icons.photo_outlined,
        message: 'Sin foto',
        semanticLabel: widget.semanticLabel,
      );
    }

    if (!rawUrl.startsWith('http')) {
      // Recuerdos anteriores a la migración a Cloudinary guardaron una ruta
      // local del móvil. Antes se pintaba un icono gris sin más, y el usuario
      // creía que la app había perdido su foto.
      return _Placeholder(
        icon: Icons.cloud_off_rounded,
        message: 'Foto no migrada',
        semanticLabel: widget.semanticLabel,
      );
    }

    final String url = widget.width != null
        ? SmartImage._withCloudinaryResize(rawUrl, widget.width!)
        : rawUrl;

    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: CachedNetworkImage(
        key: ValueKey<String>('$url#$_retryToken'),
        imageUrl: url,
        fit: widget.fit,
        placeholder: (BuildContext context, String url) => Container(
          color: const Color(0xFFF1F2F4),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (BuildContext context, String url, Object error) {
          // Un corte de red puntual dejaba un icono naranja permanente hasta
          // reconstruir el widget: ahora se puede reintentar tocándolo.
          return InkWell(
            onTap: () => setState(() => _retryToken++),
            child: _Placeholder(
              icon: Icons.refresh_rounded,
              message: 'Tocar para reintentar',
              semanticLabel: 'La foto no se pudo cargar. Tocar para reintentar',
            ),
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.message,
    this.semanticLabel,
  });

  final IconData icon;
  final String message;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? message,
      child: ExcludeSemantics(
        child: Container(
          color: const Color(0xFFF1F2F4),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool tiny = constraints.maxHeight < 72;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    icon,
                    color: AppColors.textSecondary,
                    size: tiny ? 20 : 28,
                  ),
                  if (!tiny) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
