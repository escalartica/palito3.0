import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/factories/dynamic_field_factory.dart';

class TortillaFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(
    Map<String, dynamic> data, 
    Function(String, dynamic) onUpdate, 
    TextEditingController otroController,
  ) {
    return [
      _buildCompactChipGroup(
        'ingredientes', 
        'Ingredientes', 
        [
          {'label': 'Patata', 'icon': Icons.data_usage_rounded},
          {'label': 'Huevo', 'icon': Icons.egg_rounded},
          {'label': 'Cebolla', 'icon': Icons.circle_outlined},
          {'label': 'Trufa', 'icon': Icons.spa_outlined},
          {'label': 'Pimientos', 'icon': Icons.local_florist_outlined},
          {'label': 'Verduras', 'icon': Icons.eco_outlined},
          {'label': 'Jamón', 'icon': Icons.set_meal_rounded},
          {'label': 'Bacalao', 'icon': Icons.phishing_outlined},
        ], 
        data, 
        onUpdate,
        isMulti: true,
      ),
      _buildCompactChipGroup(
        'interior', 
        '¿Cómo estaba el interior?', 
        [
          {'label': 'Muy cuajada', 'icon': Icons.cake_outlined},
          {'label': 'Cuajada', 'icon': Icons.done_rounded},
          {'label': 'Equilibrada', 'icon': Icons.balance_outlined},
          {'label': 'Melosa', 'icon': Icons.opacity_rounded},
          {'label': 'Muy líquida', 'icon': Icons.water_drop_outlined},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'corte_patata', 
        'Corte de la patata', 
        [
          {'label': 'Muy fina', 'icon': Icons.linear_scale_rounded},
          {'label': 'Fina', 'icon': Icons.remove_rounded},
          {'label': 'Dados', 'icon': Icons.grid_view_rounded},
          {'label': 'Gruesa', 'icon': Icons.layers_outlined},
          {'label': 'Irregular', 'icon': Icons.grain_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'al_cortar', 
        '¿Qué pasó al cortarla?', 
        [
          {'label': 'No salió nada', 'icon': Icons.block_outlined},
          {'label': 'Muy poca crema', 'icon': Icons.hourglass_empty_rounded},
          {'label': 'Salió ligeramente', 'icon': Icons.waves_rounded},
          {'label': 'Se desparramó', 'icon': Icons.water_rounded},
          {'label': 'Fue pornografía gastronómica', 'icon': Icons.auto_awesome_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'sensaciones', 
        'Sensaciones', 
        [
          {'label': 'Reconfortante', 'icon': Icons.favorite_border_rounded},
          {'label': 'Sorprendente', 'icon': Icons.bolt_rounded},
          {'label': 'Elegante', 'icon': Icons.diamond_outlined},
          {'label': 'Casera', 'icon': Icons.home_rounded},
          {'label': 'Valiente', 'icon': Icons.local_fire_department_outlined},
          {'label': 'Tradicional', 'icon': Icons.history_edu_rounded},
          {'label': 'Inolvidable', 'icon': Icons.star_border_rounded},
          {'label': 'Decepcionante', 'icon': Icons.sentiment_dissatisfied_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: true,
      ),
      _buildCompactChipGroup(
        'personalidad', 
        'Personalidad: Esta tortilla es...', 
        [
          {'label': 'La que haría tu abuela', 'icon': Icons.family_restroom_rounded},
          {'label': 'Un bar de toda la vida', 'icon': Icons.local_bar_rounded},
          {'label': 'Una tortilla con ego', 'icon': Icons.psychology_outlined},
          {'label': 'Dura y de mala calidad', 'icon': Icons.cancel_outlined},
          {'label': 'Una estrella Michelin disfrazada', 'icon': Icons.military_tech_rounded},
          {'label': 'Una tortilla que no entendí', 'icon': Icons.help_outline_rounded},
          {'label': 'Sabe a la del mercadona', 'icon': Icons.shopping_bag_outlined},
          {'label': 'Una que pediría otra vez sin mirar la carta', 'icon': Icons.thumb_up_outlined},
          {'label': 'La tortilla del domingo', 'icon': Icons.wb_sunny_outlined},
          {'label': 'Para discutir media hora', 'icon': Icons.forum_outlined},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'premio', 
        'Premio Palito', 
        [
          {'label': 'La tortilla del barrio', 'icon': Icons.location_on_outlined},
          {'label': 'Reina absoluta', 'icon': Icons.emoji_events_outlined},
          {'label': 'Para cruzar la ciudad', 'icon': Icons.directions_walk_rounded},
          {'label': 'Refugio emocional', 'icon': Icons.shield_outlined},
          {'label': 'Infravalorada', 'icon': Icons.trending_down_rounded},
          {'label': 'Siempre cumple', 'icon': Icons.check_circle_outline_rounded},
          {'label': 'Más bonita que rica', 'icon': Icons.visibility_outlined},
          {'label': 'Mucho ruido', 'icon': Icons.volume_up_outlined},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCustomTextField(
        'titular', 
        'El titular', 
        'Describe esta tortilla en una frase...', 
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
}