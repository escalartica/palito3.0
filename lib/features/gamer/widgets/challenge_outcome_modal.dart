import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

const _kDark = AppColors.textPrimary;

/// Modal para evaluar el resultado (superado / no superado) del Juicio
/// Picante asignado a un comensal. Extraído de gamer_page.dart.
class ChallengeOutcomeModal extends StatelessWidget {
  const ChallengeOutcomeModal({
    super.key,
    required this.playerName,
    required this.challengeText,
    required this.onOutcome,
  });

  final String playerName;
  final String challengeText;

  /// Se invoca con `true` si el reto fue superado, `false` en caso
  /// contrario. El modal se cierra a continuación.
  final ValueChanged<bool> onOutcome;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(
      // Crema deliberadamente más cálido que AppColors.surfaceWarm: este
      // modal es el momento de evaluar un reto superado o no, y el tono se
      // eligió para destacar frente al resto de hojas inferiores en blanco
      // de la ruleta, no por descuido.
      color: Color(0xFFFFF8EE),
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              // pill, no un número suelto: cualquier radio >= mitad del
              // lado corto da la misma cápsula perfecta, así que el paso
              // "completo" de la escala es la elección correcta aquí.
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '🎯 Evaluar Juicio de $playerName',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _kDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              challengeText,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _kDark,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    onOutcome(false);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tintError,
                    foregroundColor: AppColors.error,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    '❌ No Superado',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    onOutcome(true);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    '✅ ¡Superado!',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
