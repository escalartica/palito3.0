import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dynamic_field_factory.dart';
import '../../../core/theme/components/neo_chip.dart';

class PlatoEstrellaFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate,
    TextEditingController otroController,
  ) {
    return [
      _buildCustomTextField(
        'nombre_plato',
        'Datos del Plato',
        'Nombre del plato',
        data,
        onUpdate,
      ),

      // ---------------------------------------------------------
      // TIPO DE PLATO
      // ---------------------------------------------------------
      _buildCompactChipGroup(
        'tipo_plato',
        'Tipo de plato',
        [
          {'label': 'Carne', 'icon': Icons.kebab_dining_rounded},
          {'label': 'Pescado', 'icon': Icons.set_meal_rounded},
          {'label': 'Pasta', 'icon': Icons.ramen_dining_rounded},
          {'label': 'Arroz', 'icon': Icons.rice_bowl_rounded},
          {'label': 'Verduras', 'icon': Icons.eco_outlined},
          {'label': 'Cuchara', 'icon': Icons.soup_kitchen_rounded},
          {'label': 'Brasa', 'icon': Icons.local_fire_department_outlined},
          {'label': 'Marisco', 'icon': Icons.tsunami_rounded},
          {'label': 'Internacional', 'icon': Icons.public_rounded},
          {'label': 'Otro', 'icon': Icons.edit_outlined},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      // Campo dinámico para "Otro tipo de plato"
      if (data['tipo_plato'] == 'Otro')
        _buildCustomTextField(
          'otro_tipo_plato',
          'Otro tipo de plato',
          'Escribe el tipo de plato',
          data,
          onUpdate,
        ),

      // ---------------------------------------------------------
      // TÉCNICA
      // ---------------------------------------------------------
      _buildCompactChipGroup(
        'tecnica',
        'Técnica y Equilibrio: Técnica aplicada',
        [
          {
            'label': 'Brasa perfecta',
            'icon': Icons.local_fire_department_outlined,
          },
          {'label': 'Baja temperatura', 'icon': Icons.thermostat_rounded},
          {'label': 'Frito impecable', 'icon': Icons.oil_barrel_outlined},
          {'label': 'Crujiente', 'icon': Icons.flash_on_outlined},
          {'label': 'Ahumado', 'icon': Icons.blur_on_rounded},
          {'label': 'Confitado', 'icon': Icons.hourglass_top_rounded},
          {'label': 'Fermentado', 'icon': Icons.science_outlined},
          {'label': 'Otro', 'icon': Icons.edit_outlined},
        ],
        data,
        onUpdate,
        isMulti: true,
      ),

      // Campo dinámico para "Otra técnica"
      if (_containsValue(data['tecnica'], 'Otro'))
        _buildCustomTextField(
          'otra_tecnica',
          'Otra técnica',
          'Describe la técnica aplicada',
          data,
          onUpdate,
        ),

      // ---------------------------------------------------------
      // PUNTO DE COCCIÓN
      // ---------------------------------------------------------
      _buildCompactChipGroup(
        'coccion',
        'Punto de cocción',
        [
          {'label': 'Crudo', 'icon': Icons.water_drop_outlined},
          {'label': 'Poco hecho', 'icon': Icons.remove_rounded},
          {'label': 'Al punto', 'icon': Icons.check_circle_outline_rounded},
          {'label': 'Muy hecho', 'icon': Icons.whatshot_rounded},
          {'label': 'Perfecto', 'icon': Icons.verified_rounded},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      // ---------------------------------------------------------
      // EQUILIBRIO DE SABORES
      // ---------------------------------------------------------
      _buildCompactChipGroup(
        'equilibrio',
        'Equilibrio de sabores',
        [
          {'label': 'Perfecto', 'icon': Icons.balance_outlined},
          {'label': 'Muy salado', 'icon': Icons.grain_rounded},
          {'label': 'Muy dulce', 'icon': Icons.cake_outlined},
          {'label': 'Muy ácido', 'icon': Icons.bolt_rounded},
          {'label': 'Falta intensidad', 'icon': Icons.trending_down_rounded},
          {'label': 'Otro', 'icon': Icons.edit_outlined},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      // Campo dinámico para "Otro equilibrio"
      if (data['equilibrio'] == 'Otro')
        _buildCustomTextField(
          'otro_equilibrio',
          'Otro equilibrio de sabores',
          'Describe el equilibrio de sabores',
          data,
          onUpdate,
        ),

      // ---------------------------------------------------------
      // PRIMER BOCADO
      // ---------------------------------------------------------
      _buildCompactChipGroup(
        'primer_bocado',
        'Impacto Sensorial: Primer bocado',
        [
          {'label': 'Correcto', 'icon': Icons.check_rounded},
          {'label': 'Interesante', 'icon': Icons.lightbulb_outline_rounded},
          {'label': 'Muy bueno', 'icon': Icons.thumb_up_outlined},
          {'label': 'Sonreí', 'icon': Icons.sentiment_very_satisfied_rounded},
          {'label': 'Acertamos', 'icon': Icons.military_tech_rounded},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      // ---------------------------------------------------------
      // EMOCIÓN
      // ---------------------------------------------------------
      _buildCompactChipGroup(
        'emocion',
        'Emoción predominante',
        [
          {'label': 'Reconfortado', 'icon': Icons.favorite_border_rounded},
          {'label': 'Sorprendido', 'icon': Icons.bolt_rounded},
          {'label': 'Feliz', 'icon': Icons.sentiment_satisfied_alt_rounded},
          {'label': 'Nostálgico', 'icon': Icons.history_edu_rounded},
          {'label': 'Impresionado', 'icon': Icons.auto_awesome_rounded},
          {'label': 'Divertido', 'icon': Icons.sports_esports_outlined},
        ],
        data,
        onUpdate,
        isMulti: true,
      ),

      // ---------------------------------------------------------
      // PREMIO
      // ---------------------------------------------------------
      _buildCompactChipGroup(
        'premio',
        'Premio Palito y Decisión',
        [
          {'label': 'Obra maestra', 'icon': Icons.diamond_outlined},
          {
            'label': 'Vale el viaje',
            'icon': Icons.directions_car_filled_outlined,
          },
          {'label': 'Amor a primer bocado', 'icon': Icons.favorite_rounded},
          {'label': 'Motivo para volver', 'icon': Icons.replay_rounded},
          {'label': 'Joya escondida', 'icon': Icons.star_border_rounded},
          {'label': 'El mejor del año', 'icon': Icons.emoji_events_outlined},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      // ---------------------------------------------------------
      // MOMENTO ESPECIAL
      // ---------------------------------------------------------
      _buildCompactChipGroup(
        'momento_especial',
        'Momento más especial',
        [
          {'label': 'Antes de probar', 'icon': Icons.visibility_outlined},
          {'label': 'Primer bocado', 'icon': Icons.star_half_rounded},
          {'label': 'Mitad', 'icon': Icons.sync_rounded},
          {'label': 'Último bocado', 'icon': Icons.last_page_rounded},
          {'label': 'Al día siguiente', 'icon': Icons.wb_sunny_outlined},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      // ---------------------------------------------------------
      // VOLVER
      // ---------------------------------------------------------
      _buildCompactChipGroup(
        'harias_por_volver',
        '¿Qué harías por volver?',
        [
          {'label': 'Lo pediré otra vez', 'icon': Icons.repeat_rounded},
          {'label': 'Cambiaría mi ruta', 'icon': Icons.alt_route_rounded},
          {
            'label': 'Haría un viaje solo',
            'icon': Icons.directions_walk_rounded,
          },
          {'label': 'Lo echaré de menos', 'icon': Icons.cloud_off_rounded},
          {'label': 'Ya planificando', 'icon': Icons.calendar_today_rounded},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),
    ];
  }

  // =============================================================
  // HELPER PARA COMPROBAR OPCIONES MULTISELECT
  // =============================================================

  bool _containsValue(dynamic value, String target) {
    if (value is List) {
      return value.contains(target);
    }

    return false;
  }

  // =============================================================
  // GRUPO DE CHIPS
  // =============================================================

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

                          // Si se desmarca "Otro", limpiamos el campo personalizado.
                          if (option == 'Otro') {
                            onUpdate('otra_tecnica', null);
                          }
                        } else {
                          newList.add(option);
                        }

                        onUpdate(key, newList);
                      } else {
                        // Si se pulsa el chip ya seleccionado,
                        // se deselecciona.
                        if (isSelected) {
                          onUpdate(key, null);

                          // Limpiamos los datos personalizados asociados.
                          if (key == 'tipo_plato') {
                            onUpdate('otro_tipo_plato', null);
                          }

                          if (key == 'equilibrio') {
                            onUpdate('otro_equilibrio', null);
                          }
                        } else {
                          onUpdate(key, option);
                        }
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

  // =============================================================
  // CAMPO DE TEXTO PERSONALIZADO
  // =============================================================

  Widget _buildCustomTextField(
    String key,
    String label,
    String hint,
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
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
                  BoxShadow(
                    color: Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                key: ValueKey('${key}_${data[key] ?? ''}'),
                initialValue: data[key]?.toString() ?? '',
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
                  onUpdate(key, value.trim().isEmpty ? null : value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
