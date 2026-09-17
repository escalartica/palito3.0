import 'package:flutter/material.dart';
// `services.dart` ya reexporta `Uint8List`, así que el `dart:typed_data` que
// había aquí pasó a ser redundante al añadir la háptica.
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/components/smart_image.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';
import '../../../core/theme/tokens/app_animation.dart';
import '../../../../core/theme/components/app_motion.dart';

/// Recuadro de foto del formulario de recuerdo: muestra la miniatura
/// recién elegida, la foto ya guardada (vía [SmartImage]) o un estado
/// vacío invitando a añadir una. Tocar cualquiera de los tres estados
/// dispara [onTap] (en `_MemoryFormPageState`, esto abre el selector de
/// fuente cámara/galería).
class PhotoSection extends StatelessWidget {
  final VoidCallback onTap;
  final AnimationController photoAnimationController;
  final XFile? tempMediaFile;
  final Uint8List? tempMediaBytes;
  final String? existingImagePath;

  const PhotoSection({
    super.key,
    required this.onTap,
    required this.photoAnimationController,
    required this.tempMediaFile,
    required this.tempMediaBytes,
    required this.existingImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        tempMediaFile != null ||
        (existingImagePath != null && existingImagePath!.isNotEmpty);

    // Tope de descodificación para la foto recién elegida. Ver el comentario
    // largo junto a `Image.memory`, más abajo.
    final int decodeWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(200, 1600);

    return Semantics(
      button: true,
      // Un `GestureDetector` pelado no tiene rol: VoiceOver leía el texto de
      // dentro ("Añadir foto del plato o lugar") como si fuera una etiqueta
      // suelta, sin decir que se pudiera tocar.
      label: hasImage
          ? 'Cambiar la foto del recuerdo'
          : 'Añadir una foto del plato o del lugar',
      child: ExcludeSemantics(
        child: PressScale(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: ScaleTransition(
            // `drive`, no `CurvedAnimation`.
            //
            // `CurvedAnimation` se SUSCRIBE a su animación padre, y esa
            // suscripción solo se deshace llamando a `dispose()`. Aquí se
            // creaba una nueva en CADA construcción de este widget —y el
            // formulario se reconstruye constantemente mientras se
            // rellena—, sin destruir ninguna: cada reconstrucción dejaba un
            // oyente más colgado del `AnimationController`, que además
            // sobrevive a este widget.
            //
            // `drive(...chain(CurveTween(...)))` calcula exactamente la misma
            // curva sin suscribirse a nada, así que no hay nada que destruir.
            scale: photoAnimationController.drive(
              Tween<double>(
                begin: 0.96,
                end: 1.0,
              ).chain(CurveTween(curve: AppAnimation.pop)),
            ),
            child: AnimatedContainer(
              duration: AppMotion.dur(context, AppAnimation.slow),
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                border: Border.all(
                  color: AppColors.textPrimary,
                  width: AppBorder.normal,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.textPrimary,
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                // 2 pt menos que el radio exterior (AppRadius.md): con el mismo
                // radio, el borde grueso deja una franja recta visible en las
                // esquinas en vez de seguir la curva.
                borderRadius: BorderRadius.circular(AppRadius.md - 2),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (tempMediaBytes != null)
                      // ── El agujero de memoria que quedaba sin tapar ──
                      //
                      // `SmartImage` ya limita cuánto se descodifica de las
                      // fotos YA GUARDADAS, pero esta es la otra: la que
                      // acabas de hacer con la cámara, todavía en memoria y
                      // sin subir. Sin `cacheWidth`, Flutter la descodifica a
                      // su tamaño original para pintarla en un recuadro de
                      // 180 puntos de alto. Una foto de iPhone de 4032×3024
                      // ocupa 4032 × 3024 × 4 bytes = **46,5 MB** de caché de
                      // imágenes, cuyo tope por defecto es 100 MB.
                      //
                      // O sea: dos fotos seguidas llenaban el caché entero y
                      // empezaban a expulsar todo lo demás. Con el ancho de la
                      // pantalla como tope son unos 4 MB — once veces menos, y
                      // en pantalla se ve exactamente igual.
                      Image.memory(
                        tempMediaBytes!,
                        fit: BoxFit.cover,
                        cacheWidth: decodeWidth,
                      )
                    else if (existingImagePath != null &&
                        existingImagePath!.isNotEmpty)
                      SmartImage(imagePath: existingImagePath, fit: BoxFit.cover)
                    else
                      const _EmptyPhotoState(),

                    if (hasImage)
                      const Positioned(
                        bottom: 12,
                        right: 12,
                        child: _ChangePhotoBadge(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPhotoState extends StatelessWidget {
  const _EmptyPhotoState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: AppMotion.dur(context, AppAnimation.slow),
          curve: AppAnimation.pop,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppBorder.normal,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.textPrimary,
                  blurRadius: 0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 24,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Añadir foto del plato o lugar",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ChangePhotoBadge extends StatelessWidget {
  const _ChangePhotoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
                color: AppColors.textPrimary,
                width: AppBorder.normal,
              ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.textPrimary,
            blurRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text(
            "Cambiar foto",
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
