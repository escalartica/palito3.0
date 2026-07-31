
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../../core/factories/dynamic_field_factory.dart';
import 'package:flutter/services.dart';
class EnsaladillaFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate,
    TextEditingController otroController,
  ) {
    return [
      _buildCompactChipGroup(
        'estado_patata',
        'Consistencia de la patata',
        [
          {'label': 'Muy firme', 'icon': Icons.hardware_rounded},
          {'label': 'Dura', 'icon': Icons.shield_outlined},
          {'label': 'Equilibrada', 'icon': Icons.balance_outlined},
          {'label': 'Cremosa', 'icon': Icons.icecream_outlined},
          {'label': 'Puré', 'icon': Icons.blur_on_rounded},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      // ============================================================
      // TIPO DE MAYONESA
      // ============================================================

      _buildCompactChipGroup(
        'tipo_mayonesa',
        'Tipo de mayonesa',
        [
          {'label': 'Casera', 'icon': Icons.home_rounded},
          {
            'label': 'Casera espectacular',
            'icon': Icons.auto_awesome_rounded,
          },
          {'label': 'Industrial', 'icon': Icons.factory_rounded},
          {'label': 'Bote', 'icon': Icons.inventory_2_outlined},
          {'label': 'No sé', 'icon': Icons.help_outline_rounded},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      _buildCompactChipGroup(
        'cantidad_mayo',
        'Cantidad de mayonesa',
        [
          {'label': 'Escasa', 'icon': Icons.water_drop_outlined},
          {'label': 'Justa', 'icon': Icons.check_circle_outline_rounded},
          {'label': 'Muy cremosa', 'icon': Icons.opacity_rounded},
          {'label': 'Excesiva', 'icon': Icons.waves_rounded},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      _buildCompactChipGroup(
        'sensacion_mayo',
        'Sensaciones de la mayonesa',
        [
          {'label': 'Sedosa', 'icon': Icons.air_rounded},
          {'label': 'Ligera', 'icon': Icons.grain_rounded},
          {'label': 'Untuosa', 'icon': Icons.layers_outlined},
          {'label': 'Muy ácida', 'icon': Icons.bolt_rounded},
          {'label': 'Dulzona', 'icon': Icons.favorite_border_rounded},
          {'label': 'Pesada', 'icon': Icons.fitness_center_rounded},
        ],
        data,
        onUpdate,
        isMulti: true,
      ),

      _buildCompactChipGroup(
        'presencia_huevo',
        'Presencia de huevo',
        [
          {'label': 'Mucho', 'icon': Icons.egg_rounded},
          {'label': 'Correcto', 'icon': Icons.done_rounded},
          {'label': 'Poco', 'icon': Icons.remove_rounded},
          {'label': 'Inexistente', 'icon': Icons.block_outlined},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      _buildCompactChipGroup(
        'integracion_huevo',
        'Integración del huevo',
        [
          {
            'label': 'Muy bien mezclado',
            'icon': Icons.join_inner_rounded,
          },
          {'label': 'En trozos', 'icon': Icons.grid_view_rounded},
          {
            'label': 'Solo decorativo',
            'icon': Icons.visibility_outlined,
          },
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      // ============================================================
      // CALIDAD DEL ATÚN
      // ============================================================

      _buildCompactChipGroup(
        'calidad_atun',
        'Calidad del atún',
        [
          {'label': 'Excelente', 'icon': Icons.star_border_rounded},
          {'label': 'Muy bueno', 'icon': Icons.thumb_up_outlined},
          {'label': 'Correcto', 'icon': Icons.check_rounded},
          {'label': 'Flojo', 'icon': Icons.sentiment_neutral_rounded},
          {'label': 'Insípido', 'icon': Icons.sentiment_dissatisfied_rounded},
          {'label': 'No llevaba', 'icon': Icons.cancel_outlined},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      // ============================================================
      // INGREDIENTES EXTRA
      // SE PUEDEN SELECCIONAR VARIOS
      // ============================================================

      _buildCompactChipGroup(
        'extras',
        'Ingredientes extra',
        [
          {
            'label': 'Aceitunas',
            'icon': Icons.radio_button_checked_rounded,
          },
          {'label': 'Piparras', 'icon': Icons.eco_outlined},
          {'label': 'Anchoa', 'icon': Icons.phishing_outlined},
          {'label': 'Ventresca', 'icon': Icons.set_meal_rounded},
          {'label': 'Gambas', 'icon': Icons.restaurant_menu_rounded},
          {'label': 'Langostinos', 'icon': Icons.tsunami_rounded},
          {'label': 'Pulpo', 'icon': Icons.blur_circular_rounded},
          {'label': 'Trufa', 'icon': Icons.spa_outlined},
          {'label': 'Huevas', 'icon': Icons.bubble_chart_rounded},
          {'label': 'Pepinillo', 'icon': Icons.extension_outlined},
          {'label': 'Pimiento', 'icon': Icons.local_florist_outlined},
          {'label': 'Otra', 'icon': Icons.add_circle_outline_rounded},
        ],
        data,
        onUpdate,
        isMulti: true,
        otroController: otroController,
      ),

      // ============================================================
      // PRIMERA CUCHARADA
      // ============================================================

      _buildCompactChipGroup(
        'primer_bocado',
        'Experiencia en la primera cucharada',
        [
          {
            'label': 'Normalita',
            'icon': Icons.sentiment_neutral_rounded,
          },
          {'label': 'Muy buena', 'icon': Icons.thumb_up_outlined},
          {'label': 'Ojo con esto', 'icon': Icons.visibility_rounded},
          {'label': 'Necesito otra', 'icon': Icons.repeat_rounded},
          {'label': 'De las mejores', 'icon': Icons.military_tech_rounded},
          {'label': 'Para olvidar', 'icon': Icons.delete_outline_rounded},
          {'label': 'Ni Fú Ni Fá', 'icon': Icons.remove_circle_outline_rounded},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      // ============================================================
      // EQUILIBRIO
      // SE PUEDEN SELECCIONAR VARIOS
      // ============================================================

      _buildCompactChipGroup(
        'destaca_demasiado',
        'Equilibrio (¿Qué le falta?)',
        [
          {'label': 'Salada', 'icon': Icons.grain_rounded},
          {
            'label': 'Fuerte de vinagre',
            'icon': Icons.science_outlined,
          },
          {'label': 'Huevo', 'icon': Icons.egg_outlined},
          {'label': 'Atún', 'icon': Icons.set_meal_outlined},
          {'label': 'Perfecta', 'icon': Icons.verified_rounded},
          {'label': 'Falta sal', 'icon': Icons.add_rounded},
          {'label': 'Falta vinagre', 'icon': Icons.water_drop_outlined},
          {
            'label': 'Insípida',
            'icon': Icons.sentiment_dissatisfied_rounded,
          },
          {
            'label': 'Falta punch',
            'icon': Icons.local_fire_department_outlined,
          },
        ],
        data,
        onUpdate,
        isMulti: true,
      ),

      // ============================================================
      // ÁREAS DE MEJORA
      // SE PUEDEN SELECCIONAR VARIAS
      // ============================================================

      _buildCompactChipGroup(
        'mejoras',
        'Áreas de mejora sugeridas',
        [
          {'label': 'Más mayo', 'icon': Icons.add_rounded},
          {'label': 'Menos mayo', 'icon': Icons.remove_rounded},
          {'label': 'Más patata', 'icon': Icons.data_usage_rounded},
          {'label': 'Más atún', 'icon': Icons.set_meal_rounded},
          {'label': 'Más huevo', 'icon': Icons.egg_outlined},
          {
            'label': 'Menos sal',
            'icon': Icons.cancel_presentation_rounded,
          },
          {'label': 'Más sal', 'icon': Icons.grain_rounded},
          {
            'label': 'Más vinagre',
            'icon': Icons.water_drop_outlined,
          },
          {'label': 'Texturas', 'icon': Icons.layers_outlined},
          {
            'label': 'Algún extra',
            'icon': Icons.add_circle_outline_rounded,
          },
        ],
        data,
        onUpdate,
        isMulti: true,
      ),

      _buildCompactChipGroup(
        'premio',
        'Premio Palito',
        [
          {'label': 'Reina del vermut', 'icon': Icons.local_bar_rounded},
          {
            'label': 'Cucharada obligatoria',
            'icon': Icons.restaurant_rounded,
          },
          {'label': 'La de siempre', 'icon': Icons.history_edu_rounded},
          {'label': 'Sabor a verano', 'icon': Icons.wb_sunny_outlined},
          {'label': 'Una joya', 'icon': Icons.diamond_outlined},
          {
            'label': 'Para recorrer kms',
            'icon': Icons.directions_walk_rounded,
          },
          {'label': 'Nunca falla', 'icon': Icons.star_rounded},
          {'label': 'Poca gloria', 'icon': Icons.cloud_off_rounded},
          {'label': 'De bote', 'icon': Icons.inventory_2_outlined},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),

      _buildCompactChipGroup(
        'ultimo_bocado',
        'Sensación en el último bocado',
        [
          {'label': 'Lo dejé', 'icon': Icons.close_rounded},
          {'label': 'Me dio igual', 'icon': Icons.remove_done_rounded},
          {'label': 'Me supo a poco', 'icon': Icons.trending_up_rounded},
          {
            'label': 'Rebañé el plato',
            'icon': Icons.cleaning_services_rounded,
          },
          {'label': 'Pedimos otra', 'icon': Icons.plus_one_rounded},
          {'label': 'Pa los perros', 'icon': Icons.pets_rounded},
        ],
        data,
        onUpdate,
        isMulti: false,
      ),
    ];
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
    TextEditingController? otroController,
  }) {
    final bool hasOtro =
        key == 'extras' &&
        (data[key] is List
            ? (data[key] as List).contains('Otra')
            : false) &&
        otroController != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =================================================================
          // TÍTULO
          // =================================================================

          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 8),

          // =================================================================
          // CHIPS
          // =================================================================

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((optionData) {
              final String option =
                  optionData['label'] as String;

              final IconData icon =
                  optionData['icon'] as IconData;

              bool isSelected = false;

              if (isMulti) {
                final List selectedItems =
                    data[key] is List
                        ? List.from(data[key])
                        : [];

                isSelected =
                    selectedItems.contains(option);
              } else {
                isSelected =
                    data[key] == option;
              }

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();

                  if (isMulti) {
                    final List selectedItems =
                        data[key] is List
                            ? List.from(data[key])
                            : [];

                    final List newList =
                        List.from(selectedItems);

                    if (isSelected) {
                      newList.remove(option);
                    } else {
                      newList.add(option);
                    }

                    onUpdate(
                      key,
                      newList,
                    );
                  } else {
                    onUpdate(
                      key,
                      isSelected
                          ? null
                          : option,
                    );
                  }
                },
                borderRadius:
                    BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds: 220,
                  ),
                  curve:
                      Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration:
                      BoxDecoration(
                    color: isSelected
                        ? const Color(
                            0xFFFFD400,
                          )
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    border:
                        Border.all(
                      color:
                          const Color(
                        0xFF0F172A,
                      ),
                      width:
                          isSelected
                              ? 2.0
                              : 1.0,
                    ),
                    boxShadow:
                        isSelected
                            ? const [
                                BoxShadow(
                                  color:
                                      Color(
                                    0xFF0F172A,
                                  ),
                                  blurRadius:
                                      0,
                                  offset:
                                      Offset(
                                    0,
                                    2,
                                  ),
                                ),
                              ]
                            : null,
                  ),
                  child: AnimatedScale(
                    scale:
                        isSelected
                            ? 1.02
                            : 1.0,
                    duration:
                        const Duration(
                      milliseconds: 180,
                    ),
                    curve:
                        Curves.easeOutBack,
                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 14,
                          color:
                              const Color(
                            0xFF0F172A,
                          ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          option,
                          style:
                              GoogleFonts.inter(
                            fontWeight:
                                isSelected
                                    ? FontWeight
                                        .w700
                                    : FontWeight
                                        .w500,
                            color:
                                const Color(
                              0xFF0F172A,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // =================================================================
          // CAMPO "OTRA"
          // =================================================================

          AnimatedSwitcher(
            duration:
                const Duration(
              milliseconds: 250,
            ),
            switchInCurve:
                Curves.easeOutCubic,
            switchOutCurve:
                Curves.easeInCubic,
            transitionBuilder:
                (
              child,
              animation,
            ) {
              return SizeTransition(
                sizeFactor:
                    animation,
                axisAlignment:
                    -1,
                child:
                    FadeTransition(
                  opacity:
                      animation,
                  child:
                      child,
                ),
              );
            },
            child: hasOtro
                ? Padding(
                    key: const ValueKey(
                      'otro_visible',
                    ),
                    padding:
                        const EdgeInsets.only(
                      top: 10,
                    ),
                    child:
                        Container(
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white,
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                        border:
                            Border.all(
                          color:
                              const Color(
                            0xFF0F172A,
                          ),
                          width:
                              1.5,
                        ),
                        boxShadow:
                            const [
                          BoxShadow(
                            color:
                                Color(
                              0xFF0F172A,
                            ),
                            blurRadius:
                                0,
                            offset:
                                Offset(
                              0,
                              2,
                            ),
                          ),
                        ],
                      ),
                      child:
                          TextField(
                        controller:
                            otroController,
                        style:
                            GoogleFonts
                                .inter(
                          color:
                              const Color(
                            0xFF0F172A,
                          ),
                          fontWeight:
                              FontWeight
                                  .w600,
                          fontSize:
                              13,
                        ),
                        decoration:
                            InputDecoration(
                          labelText:
                              'Añade otro ingrediente',
                          labelStyle:
                              GoogleFonts
                                  .inter(
                            color:
                                Colors
                                    .grey
                                    .shade600,
                            fontSize:
                                12,
                          ),
                          hintText:
                              'Ej. huevo de codorniz...',
                          hintStyle:
                              GoogleFonts
                                  .inter(
                            color:
                                Colors
                                    .grey
                                    .shade400,
                            fontSize:
                                12,
                          ),
                          border:
                              InputBorder
                                  .none,
                          contentPadding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                12,
                            vertical:
                                10,
                          ),
                        ),
                        onChanged:
                            (value) {
                          onUpdate(
                            'otro_extra',
                            value,
                          );
                        },
                      ),
                    ),
                  )
                : const SizedBox
                    .shrink(
                    key: ValueKey(
                      'otro_hidden',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

