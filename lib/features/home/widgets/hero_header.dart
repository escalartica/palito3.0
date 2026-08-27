import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/theme/components/smart_image.dart';
import 'circle_button.dart';

/// Cabecera hero del detalle de recuerdo: foto a pantalla completa con
/// gradiente, botón de volver, botón de editar y título superpuesto.
class HeroHeader extends StatelessWidget {
  final MemoryModel memory;
  final String? firstImageUrl;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback? onImageTap;

  const HeroHeader({
    super.key,
    required this.memory,
    required this.firstImageUrl,
    required this.onBack,
    required this.onEdit,
    required this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFFFFFDF5),
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

      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CircleButton(
            icon: Icons.edit_rounded,
            tooltip: 'Editar recuerdo',
            onTap: onEdit,
          ),
        ),
      ],

      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: _PressableHeroImage(
          onTap: onImageTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'memory-image-${memory.id}',
                child: firstImageUrl != null && firstImageUrl!.isNotEmpty
                    ? SmartImage(imagePath: firstImageUrl, fit: BoxFit.cover)
                    : _buildImagePlaceholder(),
              ),

              _buildImageGradient(),

              if (firstImageUrl != null && firstImageUrl!.isNotEmpty)
                Positioned(
                  right: 18,
                  bottom: 48,
                  child: _buildImagePreviewBadge(),
                ),

              Positioned(
                left: 24,
                right: 24,
                bottom: 46,
                child: _buildHeroTitle(memory),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 70,
          color: Color(0xFF0F172A),
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
          colors: [
            Colors.black.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.78),
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
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0F172A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0F172A),
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
            color: Color(0xFF0F172A),
          ),
          const SizedBox(width: 6),
          Text(
            'Ver foto',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
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
                color: Color(0xFFFFD400),
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

  const _PressableHeroImage({required this.onTap, required this.child});

  @override
  State<_PressableHeroImage> createState() => _PressableHeroImageState();
}

class _PressableHeroImageState extends State<_PressableHeroImage> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
