import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/theme/components/smart_image.dart';
import 'circle_button.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_animation.dart';
import '../../../core/theme/tokens/app_shape.dart';
import '../../../../core/theme/components/app_motion.dart';

/// Cabecera hero del detalle de recuerdo: foto a pantalla completa con
/// gradiente, botón de volver, botón de editar y título superpuesto.
class HeroHeader extends StatelessWidget {
  final MemoryModel memory;
  final String? firstImageUrl;
  final VoidCallback onBack;
  final VoidCallback? onImageTap;

  const HeroHeader({
    super.key,
    required this.memory,
    required this.firstImageUrl,
    required this.onBack,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      automaticallyImplyLeading: false,

      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleButton(
          // arrow_back_rounded para igualar el peso visual de
          // edit_rounded (el chevron "ios_new" tiene un trazo mucho más
          // grueso al mismo tamaño lógico) y para usar el mismo icono de
          // "volver" que el resto de la app (perfil, gamer).
          icon: Icons.arrow_back_rounded,
          tooltip: 'Volver',
          onTap: onBack,
        ),
      ),

      // AQUÍ HABÍA UN SEGUNDO BOTÓN DE EDITAR.
      //
      // Un `CircleButton` con un lápiz, que llamaba exactamente a la misma
      // función que el botón flotante "Editar" de abajo. Dos controles para
      // una acción no dan el doble de acceso: obligan a preguntarse en qué
      // se diferencian. Se queda el de abajo, que es el que lleva la palabra
      // escrita y tiene tamaño táctil de sobra.

      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: _PressableHeroImage(
          onTap: onImageTap,
          semanticHint: 'Abrir la foto a pantalla completa',
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'memory-image-${memory.id}',
                child: firstImageUrl != null && firstImageUrl!.isNotEmpty
                    ? SmartImage(
                        imagePath: firstImageUrl,
                        fit: BoxFit.cover,
                        // SIN `width` SE PEDÍA LA FOTO ORIGINAL.
                        //
                        // `SmartImage` solo pide a Cloudinary una versión
                        // redimensionada cuando recibe un ancho; sin él
                        // descargaba el JPEG tal como salió de la cámara.
                        // Una foto de móvil de 4032×3024 ocupa **46,5 MB**
                        // descomprimida, y el caché de imágenes de Flutter
                        // tiene 100 MB: dos recuerdos vistos seguidos y el
                        // sistema empieza a tirar cosas; en un iPhone
                        // antiguo, a cerrar la app. Y todo para pintarlo en
                        // una cabecera de 390 dp de ancho.
                        width: 400,
                        semanticLabel: 'Foto de ${memory.title}',
                      )
                    : _buildImagePlaceholder(),
              ),

              _buildImageGradient(),

              // La pastilla de "Ver foto" estaba en un `Positioned` a
              // `bottom: 48` y el título a `bottom: 46`: la misma banda.
              // Como el título se pintaba después, un nombre de plato largo
              // se dibujaba ENCIMA de la pastilla. Ahora van en la misma
              // columna y no pueden pisarse.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildTitleBand(memory),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.textPrimary.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 70,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildImageGradient() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Este degradado es ambiente, no legibilidad: oscurece un poco
          // arriba para que se lean los botones y funde la foto hacia abajo.
          // De que el título se lea se encarga la banda que lo envuelve (ver
          // `_buildTitleBand`), porque un degradado sobre el alto total no
          // puede garantizar nada: el texto cae a una altura u otra según
          // ocupe una línea o dos.
          colors: [
            AppColors.textPrimary.withValues(alpha: 0.12),
            Colors.transparent,
            AppColors.textPrimary.withValues(alpha: 0.35),
          ],
          stops: const [0.0, 0.42, 1.0],
        ),
      ),
    );
  }

  Widget _buildImagePreviewBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        // Blanco entero. Ese 0.94 dejaba pasar un 6 % de la sombra navy
        // y ensuciaba la pastilla sin ganar nada a cambio.
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.textPrimary, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.textPrimary,
            blurRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.fullscreen_rounded,
            size: 16,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            'Ver foto',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// La banda inferior: velo garantizado, pastilla de "Ver foto" y título.
  ///
  /// Envuelve al texto en vez de estar pintada a una altura fija, que es la
  /// única forma de que el contraste no dependa de si el nombre del plato
  /// ocupa una línea o dos. Con el degradado anterior, un título de dos
  /// líneas sobre una foto clara se quedaba en 2,4:1; dentro de la banda,
  /// el texto se apoya siempre sobre navy al 86 % o más — por encima de
  /// 12:1 en el peor caso.
  Widget _buildTitleBand(MemoryModel memory) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x000F172A),
            Color(0xDB0F172A),
            Color(0xF00F172A),
          ],
          stops: <double>[0.0, 0.34, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (firstImageUrl != null && firstImageUrl!.isNotEmpty) ...<Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: _buildImagePreviewBadge(),
            ),
            const SizedBox(height: 12),
          ],
          _buildHeroTitle(memory),
        ],
      ),
    );
  }

  Widget _buildHeroTitle(MemoryModel memory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          memory.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.8,
            height: 1.05,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        if (memory.restaurantName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  memory.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ============================================================
// IMAGEN DE CABECERA PULSABLE
// ============================================================

/// Aísla el estado de "presionado" (para el efecto de escala al tocar la
/// foto) en su propio widget, en vez de un `bool` en el estado de la
/// página que envuelve esta cabecera — así tocar la imagen solo
/// reconstruye este widget pequeño en lugar de todo el detalle de
/// recuerdo.
class _PressableHeroImage extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  /// Qué pasa al tocar. Sin esto, la superficie pulsable más grande de la
  /// pantalla principal —la foto de portada entera— no se anunciaba como
  /// pulsable: un `GestureDetector` pelado no tiene rol, así que VoiceOver
  /// leía la foto y el título y no decía en ningún momento que se pudiera
  /// abrir. La pastilla de "Ver foto" tampoco es un botón de verdad: es
  /// texto decorado dentro de esta misma zona.
  final String semanticHint;

  const _PressableHeroImage({
    required this.onTap,
    required this.child,
    required this.semanticHint,
  });

  @override
  State<_PressableHeroImage> createState() => _PressableHeroImageState();
}

class _PressableHeroImageState extends State<_PressableHeroImage> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      // Sin `label` ni `ExcludeSemantics`: lo de dentro (la foto con su
      // descripción, el título del plato, la nota) sigue leyéndose. Lo único
      // que se añade es el rol de botón y qué pasa al tocar.
      onTapHint: widget.semanticHint,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1.0,
          duration: AppMotion.dur(context, AppAnimation.fast),
          curve: AppAnimation.enter,
          child: widget.child,
        ),
      ),
    );
  }
}
