import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/data/rating_scale.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

/// Selector de recuerdos para un grupo de marcadores que comparten
/// coordenada.
///
/// Un marcador de grupo abre esta hoja con la lista de recuerdos en ese
/// punto en vez de "spiderfy" (expandir espacialmente los marcadores):
/// en un mapa con marcadores cercanos entre sí, el toque para elegir uno
/// de los marcadores expandidos coincidía con el gesto de pointer-down
/// del propio mapa, que los volvía a colapsar antes de registrar el tap.
/// Una lista es además más accesible y profesional que depender de la
/// precisión táctil sobre marcadores diminutos.
///
/// No mantiene estado propio: recibe mediante callbacks todo lo que
/// depende de `_MapPageState` (color por categoría, selección de un
/// recuerdo) para poder vivir fuera de esa clase sin cambiar ningún
/// comportamiento.
class MemoryGroupPicker {
  const MemoryGroupPicker._();

  static void show({
    required BuildContext context,
    required List<MemoryModel> memories,
    required Color Function(String category) getCategoryColor,
    required void Function(MemoryModel memory) onMemorySelected,
  }) {
    showModalBottomSheet(
      context: context,
      // Por encima del dock (ver gamer_page.dart).
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: AppColors.surfaceWarm,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppColors.textPrimary, width: 3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    // pill, no un número suelto: cualquier radio >= mitad del
                    // lado corto da la misma cápsula perfecta, así que el paso
                    // "completo" de la escala es la elección correcta aquí.
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Text(
                '${memories.length} recuerdos en este lugar',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Elige cuál quieres ver',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: memories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final memory = memories[index];
                    return _buildGroupPickerRow(
                      context,
                      memory,
                      getCategoryColor(memory.category),
                      onMemorySelected,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildGroupPickerRow(
    BuildContext context,
    MemoryModel memory,
    Color categoryColor,
    void Function(MemoryModel memory) onMemorySelected,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          Navigator.pop(context);
          onMemorySelected(memory);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.textPrimary, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.textPrimary,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                // Mismo caso que la pastilla de la hoja de detalle: icono
                // del color del fondo sobre ese mismo color al 15 %. Un
                // icono es un elemento gráfico y las guías piden 3:1; así
                // no llega nunca. Tinte opaco, icono navy.
                decoration: BoxDecoration(
                  color: Color.lerp(
                    AppColors.surface,
                    categoryColor,
                    0.15,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: AppBorder.thin,
                  ),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      memory.category,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // `Colors.amber` sobre blanco mide 1,63:1. Un icono
                  // que aporta información necesita 3:1 como mínimo; a esa
                  // distancia del fondo, la estrella era un borrón claro.
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    RatingScale.shortLabel(memory.rating) ?? '—',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
