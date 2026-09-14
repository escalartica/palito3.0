import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/data/rating_scale.dart';

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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFDF5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0xFF0F172A), width: 3)),
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '${memories.length} recuerdos en este lugar',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Elige cuál quieres ver',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
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
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          onMemorySelected(memory);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0F172A), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF0F172A),
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
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0F172A),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.restaurant_rounded,
                  color: categoryColor,
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
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      memory.category,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    RatingScale.shortLabel(memory.rating) ?? '—',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF0F172A)),
            ],
          ),
        ),
      ),
    );
  }
}
