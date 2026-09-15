import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/data/rating_scale.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

/// Hoja inferior con el resumen de un recuerdo, abierta al tocar un
/// marcador (normal o dentro de un grupo "spiderfy") en el mapa.
///
/// No mantiene estado propio: recibe mediante callbacks todo lo que
/// depende de `_MapPageState` (color por categoría, coordenada resuelta,
/// nombre de ubicación inverso) para poder vivir fuera de esa clase sin
/// cambiar ningún comportamiento.
class MemoryBottomSheet {
  const MemoryBottomSheet._();

  static void show({
    required BuildContext context,
    required MemoryModel memory,
    required Color Function(String category) getCategoryColor,
    required LatLng? Function(String memoryId) getCoordinates,
    required Future<String> Function(
      double lat,
      double lng,
      String currentAddress,
    )
    resolveLocationName,
  }) {
    final categoryColor = getCategoryColor(memory.category);

    final coordinates = getCoordinates(memory.id);

    final double? lat = coordinates?.latitude;

    final double? lng = coordinates?.longitude;

    showModalBottomSheet(
      context: context,
      // Por encima del dock (ver gamer_page.dart).
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          decoration: const BoxDecoration(
            color: AppColors.surfaceWarm,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(top: BorderSide(color: AppColors.textPrimary, width: 3)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 25, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    // pill, no un número suelto: cualquier radio >= mitad del
                    // lado corto da la misma cápsula perfecta, así que el paso
                    // "completo" de la escala es la elección correcta aquí.
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),

              // --------------------------------------------------
              // TÍTULO + RATING
              // --------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      memory.title,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      RatingScale.shortLabel(memory.rating) == null
                          ? 'Sin puntuar'
                          : '${RatingScale.shortLabel(memory.rating)} ★',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: categoryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // --------------------------------------------------
              // UBICACIÓN
              // --------------------------------------------------
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: lat != null && lng != null
                        ? FutureBuilder<String>(
                            future: resolveLocationName(
                              lat,
                              lng,
                              memory.location.address,
                            ),
                            builder: (context, snapshot) {
                              final text =
                                  snapshot.data ?? memory.location.address;

                              return Text(
                                text.isNotEmpty
                                    ? text
                                    : 'Ubicación no disponible',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          )
                        : Text(
                            memory.location.address.isNotEmpty
                                ? memory.location.address
                                : 'Ubicación no disponible',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // CHIPS
              // --------------------------------------------------
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(memory.category),
                    backgroundColor: categoryColor.withValues(alpha: 0.15),
                    labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: categoryColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    side: BorderSide(color: categoryColor, width: 1.5),
                  ),
                  Chip(
                    label: Text(
                      memory.wouldReturn ? '¡Volvería!' : 'No volvería',
                    ),
                    // Verde y rojo de la paleta de Material, mezclados al
                    // 12 % sobre lo que hubiera detrás. Dos problemas: no son
                    // los colores de Palito —que tiene los suyos, medidos— y
                    // el texto verde sobre el verde aguado se queda en
                    // **4,2:1**, por debajo del mínimo legible. El texto pasa
                    // a navy (14,7:1) y el color se queda donde sí puede
                    // hacer su trabajo sin comprometer la lectura: el borde.
                    backgroundColor: memory.wouldReturn
                        ? AppColors.tintSuccess
                        : AppColors.tintError,
                    labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    side: BorderSide(
                      color: memory.wouldReturn
                          ? AppColors.success
                          : AppColors.error,
                      width: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --------------------------------------------------
              // BOTÓN DETALLE
              // --------------------------------------------------
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      side: const BorderSide(
                        color: AppColors.textPrimary,
                        width: 2,
                      ),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();

                    Navigator.pop(context);

                    context.push('/memory-detail', extra: memory);
                  },
                  child: Text(
                    'Ver Experiencia Completa',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
