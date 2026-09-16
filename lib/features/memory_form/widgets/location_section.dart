import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'form_field_containers.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_animation.dart';
import '../../../core/theme/tokens/app_shape.dart';

/// Campo de ubicación del formulario de recuerdo: texto libre + botón de
/// GPS. El estado de la geolocalización (coordenadas actuales, si se
/// están obteniendo...) lo sigue gestionando `_MemoryFormPageState`; este
/// widget solo pinta el campo y reenvía sus eventos hacia arriba.
class LocationSection extends StatelessWidget {
  final TextEditingController controller;
  final bool isGettingLocation;
  final AnimationController gpsAnimationController;
  final VoidCallback onGpsTap;
  final ValueChanged<String>? onAddressChanged;

  const LocationSection({
    super.key,
    required this.controller,
    required this.isGettingLocation,
    required this.gpsAnimationController,
    required this.onGpsTap,
    this.onAddressChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel("Ubicación"),
        const SizedBox(height: 8),
        NeoContainer(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onAddressChanged,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  decoration: memoryFormInputDecoration(
                    "Escribe una ciudad o dirección",
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _GpsButton(
                  isGettingLocation: isGettingLocation,
                  animationController: gpsAnimationController,
                  onGpsTap: onGpsTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GpsButton extends StatelessWidget {
  final bool isGettingLocation;
  final AnimationController animationController;
  final VoidCallback onGpsTap;

  const _GpsButton({
    required this.isGettingLocation,
    required this.animationController,
    required this.onGpsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !isGettingLocation,
      // Era un `GestureDetector` sin etiqueta ni rol: VoiceOver anunciaba el
      // botón como nada en absoluto. Y mientras busca la posición no basta
      // con que el icono gire — girar no se oye.
      label: isGettingLocation
          ? 'Buscando tu ubicación'
          : 'Usar mi ubicación actual',
      child: GestureDetector(
        // `opaque` para que el toque cuente en TODO el cuadro de 44, no solo
        // encima del dibujo del icono.
        behavior: HitTestBehavior.opaque,
        onTap: isGettingLocation
            ? null
            : () {
                HapticFeedback.selectionClick();
                onGpsTap();
              },
        // 44x44 de zona táctil, que es el mínimo de las guías de Apple. El
        // botón medía 8 + 18 + 8 = **34**, y es de los que más se fallan:
        // está pegado al borde derecho del campo de texto, así que un dedo
        // que se queda corto no pulsa nada y uno que se pasa abre el teclado.
        // El dibujo no cambia de tamaño; lo que crece es lo que escucha.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: AppAnimation.standard,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // Tinte OPACO de la paleta mientras busca, no el amarillo al
                // 50 %: con alfa, el color que sale depende de lo que haya
                // detrás, y aquí detrás hay una tarjeta con borde y sombra.
                color: isGettingLocation
                    ? AppColors.tintPrimary
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.textPrimary,
                  width: AppBorder.normal,
                ),
                boxShadow: isGettingLocation
                    ? const <BoxShadow>[]
                    : const <BoxShadow>[
                        BoxShadow(
                          color: AppColors.textPrimary,
                          blurRadius: 0,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: RotationTransition(
                turns: animationController,
                child: Icon(
                  isGettingLocation
                      ? Icons.sync_rounded
                      : Icons.my_location_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
