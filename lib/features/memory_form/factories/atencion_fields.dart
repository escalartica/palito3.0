import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../../core/factories/dynamic_field_factory.dart';

class AtencionFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(
    Map<String, dynamic> data, 
    Function(String, dynamic) onUpdate, 
    TextEditingController otroController,
  ) {
    return [
      _buildCustomTextField(
        'nombre_staff', 
        'El Factor Humano', 
        '¿Quién hizo especial la experiencia?', 
        data, 
        onUpdate,
      ),
      _buildCustomSlider(
        'nota_atencion', 
        'Nota de la atención (0-10)', 
        0, 
        10, 
        data, 
        onUpdate,
      ),
      _buildCompactChipGroup(
        'espera', 
        'Ritmo y Disponibilidad: Tiempo de espera', 
        [
          {'label': 'Inmediato', 'icon': Icons.bolt_rounded},
          {'label': 'Muy rápido', 'icon': Icons.fast_forward_rounded},
          {'label': 'Correcto', 'icon': Icons.check_circle_outline_rounded},
          {'label': 'Lento', 'icon': Icons.hourglass_bottom_rounded},
          {'label': 'Desesperante', 'icon': Icons.warning_amber_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'disponibilidad', 
        'Disponibilidad del equipo', 
        [
          {'label': 'Siempre', 'icon': Icons.visibility_outlined},
          {'label': 'Casi siempre', 'icon': Icons.track_changes_rounded},
          {'label': 'Normal', 'icon': Icons.balance_outlined},
          {'label': 'Difícil', 'icon': Icons.visibility_off_outlined},
          {'label': 'Imposible', 'icon': Icons.block_outlined},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'conocimiento', 
        'Conocimiento y Recomendaciones: Dominio de carta', 
        [
          {'label': 'No supo responder', 'icon': Icons.help_outline_rounded},
          {'label': 'Dudó', 'icon': Icons.psychology_outlined},
          {'label': 'Correcto', 'icon': Icons.thumb_up_outlined},
          {'label': 'Sabía todo', 'icon': Icons.school_outlined},
          {'label': 'Parecía el chef', 'icon': Icons.military_tech_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'recomendaciones', 
        'Calidad de las recomendaciones', 
        [
          {'label': 'No pregunté', 'icon': Icons.remove_done_rounded},
          {'label': 'No supieron', 'icon': Icons.sentiment_dissatisfied_rounded},
          {'label': 'Correctas', 'icon': Icons.check_rounded},
          {'label': 'Muy buenas', 'icon': Icons.star_border_rounded},
          {'label': 'Increíbles', 'icon': Icons.auto_awesome_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'despedida', 
        'El Toque Personal: Despedida', 
        [
          {'label': 'Ni nos miraron', 'icon': Icons.visibility_off_outlined},
          {'label': 'Un "hasta luego"', 'icon': Icons.waving_hand_outlined},
          {'label': 'Nos dieron las gracias', 'icon': Icons.favorite_border_rounded},
          {'label': 'Nos despidieron por nuestro nombre', 'icon': Icons.badge_outlined},
          {'label': 'Salimos con una sonrisa', 'icon': Icons.sentiment_very_satisfied_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCustomTextField(
        'personaje_staff', 
        'Casting del Equipo', 
        'Si el equipo fuera un personaje, ¿quién sería?', 
        data, 
        onUpdate,
      ),
      _buildCustomTextField(
        'frase_recordada', 
        'Frase memorable', 
        '¿Alguna frase que merezca ser recordada?', 
        data, 
        onUpdate,
      ),
      _buildCompactChipGroup(
        'premio_servicio', 
        'Premios Palito', 
        [
          {'label': 'Servicio 5 estrellas', 'icon': Icons.star_rounded},
          {'label': 'Mejor sonrisa', 'icon': Icons.sentiment_satisfied_alt_rounded},
          {'label': 'Como en casa', 'icon': Icons.home_rounded},
          {'label': 'Enciclopedia gastronómica', 'icon': Icons.menu_book_rounded},
          {'label': 'Equipo inolvidable', 'icon': Icons.groups_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
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