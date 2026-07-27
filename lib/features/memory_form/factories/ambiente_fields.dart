import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../../core/factories/dynamic_field_factory.dart';

class AmbienteFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(
    Map<String, dynamic> data, 
    Function(String, dynamic) onUpdate, 
    TextEditingController otroController,
  ) {
    return [
      _buildCompactChipGroup(
        'estilo', 
        'El ADN del Lugar: Estilo', 
        [
          {'label': 'Tradicional', 'icon': Icons.history_edu_rounded},
          {'label': 'Moderno', 'icon': Icons.bolt_rounded},
          {'label': 'Minimalista', 'icon': Icons.check_box_outline_blank_rounded},
          {'label': 'Industrial', 'icon': Icons.architecture_rounded},
          {'label': 'Rústico', 'icon': Icons.cabin_rounded},
          {'label': 'Elegante', 'icon': Icons.diamond_outlined},
          {'label': 'Vintage', 'icon': Icons.watch_later_outlined},
          {'label': 'Mediterráneo', 'icon': Icons.wb_sunny_outlined},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCustomSlider(
        'nota_espacio', 
        'Nota del espacio (0-10)', 
        0, 
        10, 
        data, 
        onUpdate,
      ),
      _buildCompactChipGroup(
        'luz', 
        'Clima Sensorial: Iluminación', 
        [
          {'label': 'Muy oscura', 'icon': Icons.dark_mode_outlined},
          {'label': 'Tenue', 'icon': Icons.nights_stay_outlined},
          {'label': 'Cálida', 'icon': Icons.wb_incandescent_outlined},
          {'label': 'Natural', 'icon': Icons.wb_sunny_outlined},
          {'label': 'Perfecta', 'icon': Icons.verified_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCustomSlider(
        'ruido', 
        'Nivel de ruido (Silencio -> Caos)', 
        0, 
        10, 
        data, 
        onUpdate,
      ),
      _buildCompactChipGroup(
        'olor', 
        'Aroma del local', 
        [
          {'label': 'No recuerdo', 'icon': Icons.help_outline_rounded},
          {'label': 'Cocina', 'icon': Icons.soup_kitchen_rounded},
          {'label': 'Agradable', 'icon': Icons.air_rounded},
          {'label': 'Intenso', 'icon': Icons.local_fire_department_outlined},
          {'label': 'Aroma característico', 'icon': Icons.auto_awesome_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCustomTextField(
        'pelicula', 
        'La Psicología del Restaurante: Película', 
        'Si fuera una película, ¿cuál sería?', 
        data, 
        onUpdate,
      ),
      _buildCustomTextField(
        'banda_sonora', 
        'Banda sonora', 
        '¿Qué banda sonora tendría?', 
        data, 
        onUpdate,
      ),
      _buildCustomTextField(
        'personalidad', 
        'Personalidad', 
        'Si fuera una persona, ¿quién sería?', 
        data, 
        onUpdate,
      ),
      _buildCompactChipGroup(
        'tiempo_espera', 
        'El Poder de Permanencia: Tiempo tras comer', 
        [
          {'label': 'Me levanté al terminar', 'icon': Icons.exit_to_app_rounded},
          {'label': 'Un café y nos vamos', 'icon': Icons.coffee_outlined},
          {'label': 'Una copa más', 'icon': Icons.wine_bar_outlined},
          {'label': 'Se nos hizo de noche sin darnos cuenta', 'icon': Icons.nightlight_outlined},
          {'label': 'Podría vivir aquí', 'icon': Icons.home_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'limpieza', 
        'Higiene y Detalles: Limpieza', 
        [
          {'label': 'Excelente', 'icon': Icons.verified_rounded},
          {'label': 'Muy buena', 'icon': Icons.thumb_up_outlined},
          {'label': 'Correcta', 'icon': Icons.check_rounded},
          {'label': 'Mejorable', 'icon': Icons.remove_rounded},
          {'label': 'Mala', 'icon': Icons.warning_amber_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'banos', 
        'Estado de los baños', 
        [
          {'label': 'No entré', 'icon': Icons.block_outlined},
          {'label': 'Muy cuidados', 'icon': Icons.star_border_rounded},
          {'label': 'Correctos', 'icon': Icons.check_circle_outline_rounded},
          {'label': 'Mejorables', 'icon': Icons.hourglass_bottom_rounded},
          {'label': 'Muy sucios', 'icon': Icons.error_outline_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCustomSlider(
        'detalle', 
        '¿Cuánta atención al detalle hay?', 
        0, 
        10, 
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