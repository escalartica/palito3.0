import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/factories/dynamic_field_factory.dart';

class CroquetasFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate,
    TextEditingController otroController,
  ) {
    return [
      // =======================================================================
      // INGREDIENTES / SABOR
      // =======================================================================
      _buildCompactChipGroup(
        'sabor',
        '¿Qué ingredientes llevan?',
        [
          {'label': 'Jamón', 'icon': Icons.set_meal_rounded},
          {'label': 'Cocido', 'icon': Icons.soup_kitchen_outlined},
          {'label': 'Boletus', 'icon': Icons.eco_outlined},
          {'label': 'Cecina', 'icon': Icons.kebab_dining_outlined},
          {'label': 'Bacalao', 'icon': Icons.phishing_outlined},
          {'label': 'Rabo de toro', 'icon': Icons.restaurant_outlined},
          {'label': 'Gamba', 'icon': Icons.set_meal_rounded},
          {'label': 'Queso', 'icon': Icons.egg_outlined},
          {'label': 'Pollo', 'icon': Icons.dinner_dining_outlined},
          {'label': 'Espinacas', 'icon': Icons.grass_outlined},
          {'label': 'Otro', 'icon': Icons.add_circle_outline_rounded},
        ],
        data,
        onUpdate,
        otroController,
      ),

      // =======================================================================
      // SENSACIONES
      // =======================================================================
      _buildCompactChipGroup(
        'sensacion',
        '¿Qué sensaciones te dejaron?',
        [
          {'label': 'Meh', 'icon': Icons.sentiment_neutral_rounded},
          {'label': 'Mediocres', 'icon': Icons.sentiment_dissatisfied_rounded},
          {'label': 'Buenas', 'icon': Icons.thumb_up_outlined},
          {'label': 'Muy buenas', 'icon': Icons.star_border_rounded},
          {
            'label': 'Emocionantes',
            'icon': Icons.local_fire_department_outlined,
          },
          {'label': 'Religiosas', 'icon': Icons.auto_awesome_rounded},
          {'label': 'Basura', 'icon': Icons.delete_outline_rounded},
        ],
        data,
        onUpdate,
        null,
      ),

      // =======================================================================
      // BECHAMEL
      // =======================================================================
      _buildCompactChipGroup(
        'bechamel',
        'La bechamel era...',
        [
          {'label': 'Demasiado líquida', 'icon': Icons.water_drop_outlined},
          {'label': 'Muy cremosa', 'icon': Icons.icecream_outlined},
          {'label': 'Equilibrada', 'icon': Icons.balance_outlined},
          {'label': 'Densa', 'icon': Icons.layers_outlined},
          {'label': 'Cemento armado', 'icon': Icons.shield_outlined},
          {'label': 'Mazacote', 'icon': Icons.block_outlined},
        ],
        data,
        onUpdate,
        null,
      ),

      // =======================================================================
      // REBOZADO
      // =======================================================================
      _buildCompactChipGroup(
        'rebozado',
        'Prueba Chicote - Tiro al plato (Rebozado):',
        [
          {'label': 'Muy fino', 'icon': Icons.linear_scale_rounded},
          {'label': 'Crujiente perfecto', 'icon': Icons.flash_on_outlined},
          {'label': 'Sonido metálico', 'icon': Icons.volume_up_outlined},
          {'label': 'Desintegración', 'icon': Icons.grain_rounded},
          {'label': 'Aceitoso', 'icon': Icons.opacity_outlined},
          {'label': 'Hormigón armado', 'icon': Icons.foundation_outlined},
        ],
        data,
        onUpdate,
        null,
      ),

      // =======================================================================
      // CREATIVIDAD
      // =======================================================================
      _buildCompactChipGroup(
        'creatividad',
        'Creatividad en la presentación:',
        [
          {'label': 'Clásica', 'icon': Icons.history_edu_rounded},
          {'label': 'Original', 'icon': Icons.lightbulb_outline_rounded},
          {'label': 'Innovadora', 'icon': Icons.trending_up_rounded},
          {'label': 'Sorprendente', 'icon': Icons.bolt_rounded},
          {
            'label': 'Decepcionante',
            'icon': Icons.sentiment_dissatisfied_rounded,
          },
        ],
        data,
        onUpdate,
        null,
      ),
    ];
  }

  // ===========================================================================
  // GRUPO DE CHIPS
  // ===========================================================================

  Widget _buildCompactChipGroup(
    String key,
    String label,
    List<Map<String, dynamic>> options,
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate,
    TextEditingController? otroController,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =====================================================================
          // TÍTULO
          // =====================================================================
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 8),

          // =====================================================================
          // CHIPS
          // =====================================================================
          // Ancho fijo por columna (3 por fila): así todas las filas quedan
          // alineadas entre sí, como los inputs de más abajo, en vez de que
          // cada chip ocupe solo el ancho de su texto.
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 6.0;
              const columns = 3;
              final chipWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: options.map((optionData) {
                  final String option = optionData['label'] as String;

                  final IconData icon = optionData['icon'] as IconData;

                  final List selectedItems = data[key] is List
                      ? List.from(data[key])
                      : [];

                  final bool isSelected = selectedItems.contains(option);

                  return _buildAnimatedChip(
                    option: option,
                    icon: icon,
                    isSelected: isSelected,
                    width: chipWidth,
                    onTap: () {
                      final newList = List.from(selectedItems);

                      if (isSelected) {
                        newList.remove(option);
                      } else {
                        newList.add(option);
                      }

                      onUpdate(key, newList);
                    },
                  );
                }).toList(),
              );
            },
          ),

          // =====================================================================
          // CAMPO "OTRO"
          // =====================================================================
          if (key == 'sabor' &&
              (data['sabor']?.contains('Otro') ?? false) &&
              otroController != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildOtroField(otroController, onUpdate),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CHIP ANIMADO
  // ===========================================================================

  Widget _buildAnimatedChip({
    required String option,
    required IconData icon,
    required bool isSelected,
    required double width,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: AnimatedScale(
        scale: isSelected ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFD400) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF0F172A).withValues(alpha: 0.25),
                width: 2.0,
              ),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color(0xFF0F172A),
                        blurRadius: 0,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    icon,
                    key: ValueKey('${option}_$isSelected'),
                    size: 14,
                    color: const Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(width: 5),

                Flexible(
                  child: Text(
                    option,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: const Color(0xFF0F172A),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // CAMPO PERSONALIZADO "OTRO"
  // ===========================================================================

  Widget _buildOtroField(
    TextEditingController controller,
    Function(String, dynamic) onUpdate,
  ) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF0F172A),
              blurRadius: 0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.edit_rounded,
              size: 18,
              color: Color(0xFF0F172A),
            ),
            labelText: 'Especifica el sabor',
            labelStyle: GoogleFonts.inter(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onChanged: (value) {
            onUpdate('otro_sabor', value);
          },
        ),
      ),
    );
  }
}
