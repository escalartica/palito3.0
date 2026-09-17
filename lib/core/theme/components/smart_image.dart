import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import 'skeleton.dart';

/// Gris frío neutro para el hueco de una foto que aún no ha llegado o que no
/// existe. Deliberadamente distinto de `AppColors.surface`/`surfaceWarm`
/// (blancos cálidos de marca): aquí se necesita leerse como "placeholder",
/// no como parte del fondo cálido de la app.
const Color _kPlaceholderBg = Color(0xFFF1F2F4);

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
  /// [targetWidth] son **píxeles reales**, no dp: quien llama multiplica por
  /// la densidad de la pantalla. Aquí había un `* 2` fijo, y un factor fijo
  /// se equivoca en los dos sentidos a la vez: en un iPhone moderno (×3) las
  /// miniaturas de 60 dp pedían 120 px para un hueco de 180 y se veían
  /// blandas, mientras que la portada de Inicio pedía 1600 px para pintarse
  /// a 918 — tres veces el área necesaria, descargada y decodificada.
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

    return '${url.substring(0, insertAt)}'
        'w_$targetWidth,c_limit,q_auto,f_auto/'
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

    // Píxeles reales que va a ocupar la imagen en esta pantalla concreta.
    //
    // El tope de 1600 no es un número bonito: por encima de eso, la
    // diferencia no se ve en un móvil y sí se paga en descarga y en RAM.
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int? targetPx = widget.width == null
        ? null
        : (widget.width! * dpr).round().clamp(50, 1600);

    final String url = targetPx != null
        ? SmartImage._withCloudinaryResize(rawUrl, targetPx)
        : rawUrl;

    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: CachedNetworkImage(
        key: ValueKey<String>('$url#$_retryToken'),
        imageUrl: url,
        fit: widget.fit,
        // TOPE DE DECODIFICACIÓN.
        //
        // Sin esto, el mapa de bits vive en memoria al tamaño en que venga
        // el JPEG, no al tamaño al que se pinta. Una foto de móvil de
        // 4032×3024 ocupa **46,5 MB** descomprimida (ancho × alto × 4
        // bytes), y el caché de imágenes de Flutter tiene 100 MB: dos fotos
        // seguidas y empieza a tirar cosas; en un iPhone antiguo, a
        // cerrarse. Con el tope, esa misma foto ocupa 1,8 MB.
        memCacheWidth: targetPx,
        // ── EL HUECO DE LA FOTO YA ES EL ESQUELETO ──
        //
        // Aquí había un rectángulo gris con un indicador de 20 px girando
        // en medio. Pero este hueco **ya tiene el tamaño exacto de la foto
        // que viene**: es literalmente el caso para el que sirve un
        // esqueleto, y encima estaba puesto el indicador, que es para otra
        // cosa —una acción en curso, no un contenido que llega—.
        //
        // Un indicador sobre un hueco del tamaño correcto es decirlo dos
        // veces: el hueco ya dice "aquí va algo y ocupa esto". Latiendo,
        // dice además "todavía no ha llegado", sin añadir un objeto encima.
        //
        // Y pasa en todas partes: la portada de Inicio, cada fila de la
        // lista, la cabecera de la ficha, las chinchetas del mapa. Es el
        // estado de carga que más veces se ve en la app.
        placeholder: (BuildContext context, String url) => const Skeleton(
          width: double.infinity,
          height: double.infinity,
          radius: 0,
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
          color: _kPlaceholderBg,
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
