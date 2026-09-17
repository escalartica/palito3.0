import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/data/field_limits.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

const _kDark = AppColors.textPrimary;
const _kYellow = AppColors.primary;

/// Modal para añadir un nuevo comensal a la mesa. Extraído de
/// gamer_page.dart.
class AddPlayerModal extends StatelessWidget {
  const AddPlayerModal({
    super.key,
    required this.controller,
    required this.onAdd,
    required this.onAddPalito,
    required this.palitoAlreadyPlaying,
  });

  final TextEditingController controller;
  final VoidCallback onAdd;

  /// Sienta a la propia app en la mesa (ver `_isPalito` en `gamer_page`).
  final VoidCallback onAddPalito;

  /// Palito solo puede estar una vez sentado a la mesa.
  final bool palitoAlreadyPlaying;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      left: 24,
      right: 24,
      top: 24,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nuevo comensal',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _kDark,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          autofocus: true,
          // Este nombre se canta a 34 puntos en el escenario de la ruleta y
          // se mete en una ficha de 74. Los dos sitios saben recortar, pero
          // un nombre recortado no sirve para saber a quién le toca: mejor
          // que no quepa escribirlo.
          maxLength: FieldLimits.nombreComensal,
          buildCounter:
              (
                BuildContext context, {
                required int currentLength,
                required bool isFocused,
                required int? maxLength,
              }) => null,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Nombre del amigo o familiar…',
            hintStyle: TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceWarm,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kYellow,
              foregroundColor: _kDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: onAdd,
            child: Text(
              'Añadir a la mesa',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        if (!palitoAlreadyPlaying) ...<Widget>[
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              const Expanded(child: Divider(height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'o',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Expanded(child: Divider(height: 1)),
            ],
          ),
          const SizedBox(height: 14),
          // PALITO SE SIENTA A LA MESA.
          //
          // Esto ya se podía hacer sin saberlo: si escribías "Palito" como
          // nombre de comensal, la ruleta lo sacaba igual que a cualquiera
          // —anunciaba que le tocaba elegir a la app, y la app no elegía
          // nada—. Ahora sí elige, y hay un botón que lo dice en vez de un
          // truco que hay que adivinar.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: _kDark, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onPressed: onAddPalito,
              child: Row(
                children: <Widget>[
                  Image.asset(
                    'assets/icons/IconoRedondoTenedor.png',
                    width: 26,
                    height: 26,
                    cacheWidth: 78,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Que juegue Palito',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: _kDark,
                          ),
                        ),
                        Text(
                          'Si le toca a él, elige plato de vuestro diario',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    ),
  );
}
