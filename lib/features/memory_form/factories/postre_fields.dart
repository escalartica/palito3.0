import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../../core/factories/dynamic_field_factory.dart';

class PostreFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(
    Map<String, dynamic> data, 
    Function(String, dynamic) onUpdate, 
    TextEditingController otroController,
  ) {
    return [
      _buildCustomTextField(
        'nombre_postre', 
        'Identidad del Dulce', 
        'Nombre del Postre o Helado', 
        data, 
        onUpdate,
      ),
      _buildCustomTextField(
        'precio', 
        'Precio', 
        'Precio (€)', 
        data, 
        onUpdate,
      ),
      _buildCompactChipGroup(
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
      _buildCompactChipGroup(
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
      _buildCompactChipGroup(
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
      _buildCustomSlider(
        'intensidad', 
        'Intensidad principal', 
        0, 
        10, 
        data, 
        onUpdate,
      ),
      _buildCompactChipGroup(
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
      _buildCompactChipGroup(
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
      _buildCompactChipGroup(
        'emocion', 
        'Emoción predominante', 
        [
          {'label': 'Amor', 'icon': Icons.favorite_border_rounded},
          {'label': 'Vicio', 'icon': Icons.local_activity_outlined},
          {'label': 'Sorpresa', 'icon': Icons.bolt_rounded},
          {'label': 'Confort', 'icon': Icons.shield_outlined},
          {'label': 'Nostalgia', 'icon': Icons.history_edu_rounded},
          {'label': 'Increíble', 'icon': Icons.military_tech_rounded},
          {'label': 'Decepción', 'icon': Icons.sentiment_dissatisfied_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'premio', 
        'Premio Palito', 
        [
          {'label': 'Más refrescante', 'icon': Icons.wb_sunny_outlined},
          {'label': 'Más goloso', 'icon': Icons.cake_rounded},
          {'label': 'Mejor tarta de queso', 'icon': Icons.circle_outlined},
          {'label': 'Mejor helado', 'icon': Icons.icecream_outlined},
          {'label': 'Mejor contraste', 'icon': Icons.difference_rounded},
          {'label': 'Obra maestra', 'icon': Icons.diamond_outlined},
          {'label': 'Para volver mañana', 'icon': Icons.directions_walk_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'ultima_cucharada', 
        'El Cierre: Última cucharada', 
        [
          {'label': 'Quería otro', 'icon': Icons.plus_one_rounded},
          {'label': 'Perfecto, terminó a tiempo', 'icon': Icons.check_circle_outline_rounded},
          {'label': 'Se hizo pesado', 'icon': Icons.fitness_center_rounded},
          {'label': 'Me sobró', 'icon': Icons.remove_done_rounded},
          {'label': 'Me lo quitaron', 'icon': Icons.block_outlined},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCustomTextField(
        'recuerdo', 
        'Memoria a largo plazo', 
        '¿Qué recordarás dentro de un año?', 
        data, 
        onUpdate,
      ),
    ];
  }

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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((optionData) {
              final String option = optionData['label'] as String;
              final IconData icon = optionData['icon'] as IconData;
              
              bool isSelected = false;
              if (isMulti) {
                final List selectedItems = data[key] is List ? List.from(data[key]) : [];
                isSelected = selectedItems.contains(option);
              } else {
                isSelected = data[key] == option;
              }

              return InkWell(
                onTap: () {
                  if (isMulti) {
                    final List selectedItems = data[key] is List ? List.from(data[key]) : [];
                    final newList = List.from(selectedItems);
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
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFD400) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0F172A), 
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected 
                        ? const [BoxShadow(color: Color(0xFF0F172A), blurRadius: 0, offset: Offset(0, 2))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon, 
                        size: 14, 
                        color: const Color(0xFF0F172A),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        option,
                        style: GoogleFonts.inter(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: const Color(0xFF0F172A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextField(
    String key, 
    String label, 
    String hint, 
    Map<String, dynamic> data, 
    Function(String, dynamic) onUpdate,
  ) {
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
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Color(0xFF0F172A), blurRadius: 0, offset: Offset(0, 2))
              ],
            ),
            child: TextFormField(
              initialValue: data[key],
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A), 
                fontWeight: FontWeight.w600, 
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 12),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (v) => onUpdate(key, v),
            ),
          ),
        ],
      ),
    );
  }

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Color(0xFF0F172A), blurRadius: 0, offset: Offset(0, 2))
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
                      overlayColor: const Color(0xFFFFD400).withValues(alpha: 0.2),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: currentValue,
                      min: min,
                      max: max,
                      divisions: 10,
                      onChanged: (v) => onUpdate(key, v),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD400),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}