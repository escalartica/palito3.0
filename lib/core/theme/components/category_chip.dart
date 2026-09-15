import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tokens/app_animation.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_shape.dart';

/// ===========================================================================
/// CHIP DE CATEGORÍA — uno para toda la app
/// ===========================================================================
///
/// Convivían TRES chips distintos para el mismo trabajo:
///
///   1. Este, en Inicio: esquinas recortadas a mano, borde fino, hundimiento
///      al pulsar. Vivía como clase privada dentro de `home_page.dart`.
///   2. En el Mapa, el **`FilterChip` de serie de Material**: pastilla
///      perfecta, palomita de Material al seleccionar, tipografía del
///      sistema. Un componente de catálogo dentro de una app con lenguaje
///      propio — de esas cosas que se notan sin saber decir por qué.
///   3. `NeoChip`, para los formularios.
///
/// Un usuario no distingue tres implementaciones, pero sí nota que el filtro
/// de Inicio y el del Mapa "no son el mismo control". Ahora lo son.
///
/// Sigue siendo `StatefulWidget` y no un método: el hundimiento al pulsar
/// vive en un `setState` local, así que pulsar un chip no reconstruye la
/// pantalla entera — y estos se pulsan muchas veces por sesión.
class CategoryChip extends StatefulWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<CategoryChip> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: widget.isSelected,
        label: widget.label,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: reduceMotion ? Duration.zero : AppAnimation.press,
            curve: AppAnimation.enter,
            child: AnimatedContainer(
              duration: reduceMotion ? Duration.zero : AppAnimation.standard,
              curve: AppAnimation.enter,
              alignment: Alignment.center,
              // Objetivo táctil de 48 px de alto (el tamaño visual sigue
              // siendo el mismo: el relleno crece, no la caja pintada).
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isSelected ? AppColors.textPrimary : AppColors.surface,
                // Cada categoría con sus propias esquinas. Ver AppHandCut:
                // la silueta sale del texto, así que "Croquetas" tendrá
                // siempre la misma y la fila entera se lee recortada a mano
                // en vez de estampada con un molde.
                borderRadius: AppHandCut.of(widget.label),
                // Un chip no seleccionado era blanco sin borde sobre un fondo
                // casi blanco: el trozo que el ListView recortaba en el borde
                // derecho se veía como un "chip en blanco" sin texto.
                border: widget.isSelected
                    ? null
                    : Border.all(
                        color: AppColors.textPrimary.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(
                      alpha: widget.isSelected ? 0.12 : 0.03,
                    ),
                    blurRadius: widget.isSelected ? 6 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ExcludeSemantics(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: widget.isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
