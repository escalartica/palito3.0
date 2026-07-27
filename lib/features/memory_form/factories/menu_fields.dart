import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../../core/factories/dynamic_field_factory.dart';

class MenuFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(
    Map<String, dynamic> data, 
    Function(String, dynamic) onUpdate, 
    TextEditingController otroController,
  ) {
    return [
      _buildCustomTextField(
        'nombre_menu', 
        'Datos del Menú', 
        'Nombre del Menú', 
        data, 
        onUpdate,
      ),
      _buildCustomTextField(
        'precio_menu', 
        'Precio', 
        'Precio por persona', 
        data, 
        onUpdate,
      ),
      _buildCompactChipGroup(
        'tipo_menu', 
        'Tipo de menú', 
        [
          {'label': 'Menú del día', 'icon': Icons.wb_sunny_outlined},
          {'label': 'Degustación', 'icon': Icons.restaurant_menu_rounded},
          {'label': 'Ejecutivo', 'icon': Icons.badge_outlined},
          {'label': 'Fin de semana', 'icon': Icons.weekend_outlined},
          {'label': 'Festival', 'icon': Icons.celebration_outlined},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'ritmo', 
        'La Evolución del Viaje: Ritmo del servicio', 
        [
          {'label': 'Demasiado rápido', 'icon': Icons.fast_forward_rounded},
          {'label': 'Algo acelerado', 'icon': Icons.speed_rounded},
          {'label': 'Perfecto', 'icon': Icons.check_circle_outline_rounded},
          {'label': 'Se hizo largo', 'icon': Icons.hourglass_bottom_rounded},
          {'label': 'Eterno', 'icon': Icons.update_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'evolucion', 
        'Evolución de los platos', 
        [
          {'label': 'Empezó fuerte, terminó flojo', 'icon': Icons.trending_down_rounded},
          {'label': 'Fue creciendo', 'icon': Icons.trending_up_rounded},
          {'label': 'Siempre arriba', 'icon': Icons.star_border_rounded},
          {'label': 'Altibajos', 'icon': Icons.swap_vert_rounded},
          {'label': 'El postre salvó todo', 'icon': Icons.cake_outlined},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'coherencia', 
        'Equilibrio y Coherencia: ¿Coherente?', 
        [
          {'label': 'Sí, totalmente', 'icon': Icons.verified_rounded},
          {'label': 'Bastante', 'icon': Icons.thumb_up_outlined},
          {'label': 'Platos sin relación', 'icon': Icons.shuffle_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'demasiado_de', 
        'Demasiado presencia de...', 
        [
          {'label': 'Carne', 'icon': Icons.kebab_dining_rounded},
          {'label': 'Pescado', 'icon': Icons.set_meal_rounded},
          {'label': 'Harinas', 'icon': Icons.bakery_dining_rounded},
          {'label': 'Fritos', 'icon': Icons.oil_barrel_outlined},
          {'label': 'Dulces', 'icon': Icons.icecream_outlined},
          {'label': 'Equilibrado', 'icon': Icons.balance_outlined},
        ], 
        data, 
        onUpdate,
        isMulti: true,
      ),
      _buildCompactChipGroup(
        'personalidad', 
        'Personalidad y Recuerdo: Estilo', 
        [
          {'label': 'Tradicional', 'icon': Icons.history_edu_rounded},
          {'label': 'Creativo', 'icon': Icons.lightbulb_outline_rounded},
          {'label': 'Técnico', 'icon': Icons.science_outlined},
          {'label': 'Divertido', 'icon': Icons.sports_esports_outlined},
          {'label': 'Elegante', 'icon': Icons.diamond_outlined},
          {'label': 'Atrevido', 'icon': Icons.local_fire_department_outlined},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'momento_estrella', 
        'Momento estrella', 
        [
          {'label': 'Aperitivo', 'icon': Icons.tapas_outlined},
          {'label': 'Primer plato', 'icon': Icons.soup_kitchen_rounded},
          {'label': 'Principal', 'icon': Icons.restaurant_rounded},
          {'label': 'Postre', 'icon': Icons.cake_rounded},
          {'label': 'Café', 'icon': Icons.coffee_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'pan_detector', 
        'El Detector Palito: Repetición de pan', 
        [
          {'label': 'Ninguno', 'icon': Icons.block_outlined},
          {'label': 'Una vez', 'icon': Icons.looks_one_outlined},
          {'label': 'Dos veces', 'icon': Icons.looks_two_outlined},
          {'label': 'Perdí la cuenta', 'icon': Icons.all_inclusive_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'pelea_plato', 
        'Dinámica en la mesa', 
        [
          {'label': 'Pelea por el último bocado', 'icon': Icons.sports_kabaddi_rounded},
          {'label': 'Compartimos todo', 'icon': Icons.group_outlined},
          {'label': 'Intercambio de platos', 'icon': Icons.swap_horiz_rounded},
          {'label': 'Nadie compartió', 'icon': Icons.person_outline_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'pelicula', 
        '¿Qué película vimos?', 
        [
          {'label': 'Ganaría un Oscar', 'icon': Icons.emoji_events_outlined},
          {'label': 'Cine independiente', 'icon': Icons.theaters_outlined},
          {'label': 'Un clásico', 'icon': Icons.movie_outlined},
          {'label': 'Mucho tráiler, poca peli', 'icon': Icons.visibility_off_outlined},
          {'label': 'Éxito inesperado', 'icon': Icons.auto_awesome_rounded},
        ], 
        data, 
        onUpdate,
        isMulti: false,
      ),
      _buildCompactChipGroup(
        'estado_final', 
        'La Salida del Restaurante: Estado final', 
        [
          {'label': 'Con ganas de volver', 'icon': Icons.replay_rounded},
          {'label': 'Pensando en un plato', 'icon': Icons.psychology_outlined},
          {'label': 'Feliz y satisfecho', 'icon': Icons.sentiment_very_satisfied_rounded},
          {'label': 'Con una buena historia', 'icon': Icons.menu_book_rounded},
          {'label': 'Solo siesta', 'icon': Icons.bed_outlined},
          {'label': 'Esperaba más', 'icon': Icons.sentiment_dissatisfied_rounded},
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
}