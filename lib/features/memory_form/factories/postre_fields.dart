import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dynamic_field_factory.dart';
import '../../../core/theme/components/neo_chip.dart';

class PostreFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate,
    TextEditingController otroController,
  ) {
    return [
      _buildAnimatedField(
        index: 0,
        child: _buildCustomTextField(
          'nombre_postre',
          'Identidad del Dulce',
          'Nombre del Postre o Helado',
          data,
          onUpdate,
        ),
      ),

      _buildAnimatedField(
        index: 1,
        child: _buildCustomTextField(
          'precio',
          'Precio',
          'Precio (€)',
          data,
          onUpdate,
        ),
      ),

      // ================================================================
      // TIPO DE PRODUCTO
      // ================================================================
      _buildAnimatedField(
        index: 2,
        child: _buildProductTypeSelector(data, onUpdate),
      ),

      // ================================================================
      // INGREDIENTES
      // ================================================================
      _buildAnimatedField(
        index: 3,
        child: _buildCustomTextField(
          'ingredientes',
          'Ingredientes',
          'Escribe los ingredientes del postre o helado...',
          data,
          onUpdate,
          maxLines: 3,
        ),
      ),

      // ================================================================
      // PERFIL DE SABOR
      // ================================================================
      _buildAnimatedField(
        index: 4,
        child: _buildCompactChipGroup(
          'perfil_sabor',
          'Anatomía Sensorial: Perfil de sabor',
          [
            {'label': 'Muy dulce', 'icon': Icons.cake_outlined},
            {'label': 'Equilibrado', 'icon': Icons.balance_outlined},
            {'label': 'Ácido', 'icon': Icons.bolt_rounded},
            {'label': 'Amargo', 'icon': Icons.coffee_outlined},
            {'label': 'Salado', 'icon': Icons.grain_rounded},
            {'label': 'Intenso', 'icon': Icons.local_fire_department_outlined},
            {'label': 'Refrescante', 'icon': Icons.ac_unit_rounded},
            {'label': 'Cremoso', 'icon': Icons.icecream_outlined},
          ],
          data,
          onUpdate,
          isMulti: true,
        ),
      ),

      // ================================================================
      // TEXTURAS
      // ================================================================
      _buildAnimatedField(
        index: 5,
        child: _buildCompactChipGroup(
          'textura',
          'Texturas',
          [
            {'label': 'Muy cremosa', 'icon': Icons.opacity_rounded},
            {'label': 'Aireada', 'icon': Icons.air_rounded},
            {'label': 'Crujiente', 'icon': Icons.flash_on_outlined},
            {'label': 'Esponjosa', 'icon': Icons.cloud_outlined},
            {'label': 'Fundente', 'icon': Icons.water_drop_outlined},
            {'label': 'Perfecta', 'icon': Icons.verified_rounded},
          ],
          data,
          onUpdate,
          isMulti: true,
        ),
      ),

      // ================================================================
      // TEMPERATURA
      // ================================================================
      _buildAnimatedField(
        index: 6,
        child: _buildCompactChipGroup(
          'temperatura',
          'Temperatura',
          [
            {'label': 'Muy caliente', 'icon': Icons.whatshot_rounded},
            {'label': 'Tibio', 'icon': Icons.wb_sunny_outlined},
            {'label': 'Ambiente', 'icon': Icons.thermostat_rounded},
            {'label': 'Frío', 'icon': Icons.ac_unit_rounded},
            {'label': 'Muy frío', 'icon': Icons.severe_cold_rounded},
            {'label': 'Contraste F/C', 'icon': Icons.compare_arrows_rounded},
          ],
          data,
          onUpdate,
          isMulti: false,
        ),
      ),

      // ================================================================
      // INTENSIDAD
      // ================================================================
      _buildAnimatedField(
        index: 7,
        child: _buildCustomSlider(
          'intensidad',
          'Intensidad principal',
          0,
          10,
          data,
          onUpdate,
        ),
      ),

      // ================================================================
      // TAMAÑO
      // ================================================================
      _buildAnimatedField(
        index: 8,
        child: _buildCompactChipGroup(
          'tamano',
          'Tamaño o porción',
          [
            {'label': 'Muy pequeño', 'icon': Icons.remove_rounded},
            {'label': 'Correcto', 'icon': Icons.check_circle_outline_rounded},
            {'label': 'Grande', 'icon': Icons.add_rounded},
            {'label': 'Para compartir', 'icon': Icons.group_outlined},
          ],
          data,
          onUpdate,
          isMulti: false,
        ),
      ),

      // ================================================================
      // MEJOR PARTE
      // ================================================================
      _buildAnimatedField(
        index: 9,
        child: _buildCompactChipGroup(
          'mejor_parte',
          'La Experiencia: ¿Qué destacó más?',
          [
            {'label': 'Sabor', 'icon': Icons.star_border_rounded},
            {'label': 'Textura', 'icon': Icons.layers_outlined},
            {'label': 'Temperatura', 'icon': Icons.thermostat_outlined},
            {'label': 'Presentación', 'icon': Icons.palette_outlined},
            {'label': 'Contraste', 'icon': Icons.swap_horiz_rounded},
            {'label': 'Creatividad', 'icon': Icons.lightbulb_outline_rounded},
          ],
          data,
          onUpdate,
          isMulti: false,
        ),
      ),

      // ================================================================
      // EMOCIÓN
      // ================================================================
      _buildAnimatedField(
        index: 10,
        child: _buildCompactChipGroup(
          'emocion',
          'Emoción predominante',
          [
            {'label': 'Amor', 'icon': Icons.favorite_border_rounded},
            {'label': 'Vicio', 'icon': Icons.local_activity_outlined},
            {'label': 'Sorpresa', 'icon': Icons.bolt_rounded},
            {'label': 'Confort', 'icon': Icons.shield_outlined},
            {'label': 'Nostalgia', 'icon': Icons.history_edu_rounded},
            {'label': 'Increíble', 'icon': Icons.military_tech_rounded},
            {
              'label': 'Decepción',
              'icon': Icons.sentiment_dissatisfied_rounded,
            },
          ],
          data,
          onUpdate,
          isMulti: false,
        ),
      ),

      // ================================================================
      // PREMIO
      // ================================================================
      _buildAnimatedField(
        index: 11,
        child: _buildCompactChipGroup(
          'premio',
          'Premio Palito',
          [
            {'label': 'Más refrescante', 'icon': Icons.wb_sunny_outlined},
            {'label': 'Más goloso', 'icon': Icons.cake_rounded},
            {'label': 'Mejor tarta de queso', 'icon': Icons.circle_outlined},
            {'label': 'Mejor helado', 'icon': Icons.icecream_outlined},
            {'label': 'Mejor contraste', 'icon': Icons.difference_rounded},
            {'label': 'Obra maestra', 'icon': Icons.diamond_outlined},
            {
              'label': 'Para volver mañana',
              'icon': Icons.directions_walk_rounded,
            },
          ],
          data,
          onUpdate,
          isMulti: false,
        ),
      ),

      // ================================================================
      // ÚLTIMA CUCHARADA
      // ================================================================
      _buildAnimatedField(
        index: 12,
        child: _buildCompactChipGroup(
          'ultima_cucharada',
          'El Cierre: Última cucharada',
          [
            {'label': 'Quería otro', 'icon': Icons.plus_one_rounded},
            {
              'label': 'Perfecto, terminó a tiempo',
              'icon': Icons.check_circle_outline_rounded,
            },
            {'label': 'Se hizo pesado', 'icon': Icons.fitness_center_rounded},
            {'label': 'Me sobró', 'icon': Icons.remove_done_rounded},
            {'label': 'Me lo quitaron', 'icon': Icons.block_outlined},
          ],
          data,
          onUpdate,
          isMulti: false,
        ),
      ),

      // ================================================================
      // RECUERDO
      // ================================================================
      _buildAnimatedField(
        index: 13,
        child: _buildCustomTextField(
          'recuerdo',
          'Memoria a largo plazo',
          '¿Qué recordarás dentro de un año?',
          data,
          onUpdate,
          maxLines: 3,
        ),
      ),
    ];
  }

  // =========================================================================
  // ANIMACIÓN DE ENTRADA ESCALONADA
  // =========================================================================

  Widget _buildAnimatedField({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('postre_field_$index'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + (index * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // =========================================================================
  // SELECTOR POSTRE / HELADO
  // =========================================================================

  Widget _buildProductTypeSelector(
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate,
  ) {
    final String? selected = data['tipo_postre'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo de producto',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF0F172A),
                  blurRadius: 0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) => onUpdate('tipo_postre', value),
              child: Row(
                children: [
                  Expanded(
                    child: _buildRadioOption(
                      label: 'Postre',
                      icon: Icons.cake_outlined,
                      value: 'Postre',
                      groupValue: selected,
                      onChanged: (value) {
                        onUpdate('tipo_postre', value);
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildRadioOption(
                      label: 'Helado',
                      icon: Icons.icecream_outlined,
                      value: 'Helado',
                      groupValue: selected,
                      onChanged: (value) {
                        onUpdate('tipo_postre', value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required String label,
    required IconData icon,
    required String value,
    required String? groupValue,
    required Function(String?) onChanged,
  }) {
    final bool isSelected = value == groupValue;

    return InkWell(
      onTap: () {
        onChanged(isSelected ? null : value);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD400) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: const Color(0xFF0F172A),
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Radio<String>(
              value: value,
              activeColor: const Color(0xFF0F172A),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // GRUPO DE CHIPS
  // =========================================================================

  Widget _buildCompactChipGroup(
    String key,
    String label,
    List<Map<String, dynamic>> options,
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate, {
    required bool isMulti,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 8),

          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 6.0;
              // El ancho real y el tamaño de letra del sistema deciden
              // cuántas columnas caben: con el umbral fijo de caracteres que
              // había antes, "Decepcionante" se partía en "Decepcionant"/"e".
              final int columns = NeoChip.columnsFor(
                options.map((o) => o['label'] as String).toList(),
                maxWidth: constraints.maxWidth,
                textScaler: MediaQuery.textScalerOf(context),
              );
              final chipWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: options.map((optionData) {
                  final String option = optionData['label'] as String;

                  final IconData icon = optionData['icon'] as IconData;

                  bool isSelected = false;

                  if (isMulti) {
                    final List selectedItems = data[key] is List
                        ? List.from(data[key])
                        : [];

                    isSelected = selectedItems.contains(option);
                  } else {
                    isSelected = data[key] == option;
                  }

                  return NeoChip(
                    label: option,
                    icon: icon,
                    isSelected: isSelected,
                    width: chipWidth,
                    onTap: () {
                      if (isMulti) {
                        final List selectedItems = data[key] is List
                            ? List.from(data[key])
                            : [];

                        final List newList = List.from(selectedItems);

                        if (isSelected) {
                          newList.remove(option);
                        } else {
                          newList.add(option);
                        }

                        onUpdate(key, newList);
                      } else {
                        onUpdate(key, isSelected ? null : option);
                      }
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CAMPO DE TEXTO
  // =========================================================================

  Widget _buildCustomTextField(
    String key,
    String label,
    String hint,
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 8),

          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
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
            child: TextFormField(
              initialValue: data[key]?.toString() ?? '',
              maxLines: maxLines,
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                onUpdate(key, value);
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SLIDER
  // =========================================================================

  Widget _buildCustomSlider(
    String key,
    String label,
    double min,
    double max,
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate,
  ) {
    final double currentValue = (data[key] ?? min).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 8),

          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            child: Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFF0F172A),
                      inactiveTrackColor: Colors.grey.shade300,
                      thumbColor: const Color(0xFFFFD400),
                      overlayColor: const Color(
                        0xFFFFD400,
                      ).withValues(alpha: 0.2),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: currentValue.clamp(min, max),
                      min: min,
                      max: max,
                      divisions: 10,
                      onChanged: (value) {
                        onUpdate(key, value);
                      },
                    ),
                  ),
                ),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Container(
                    key: ValueKey(currentValue.round()),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD400),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF0F172A),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      currentValue.toStringAsFixed(0),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
