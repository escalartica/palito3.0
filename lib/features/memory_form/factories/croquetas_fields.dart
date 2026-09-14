import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dynamic_field_factory.dart';
import '../../../core/theme/components/neo_chip.dart';

class CroquetasFields implements DynamicFieldGenerator {
  // ===========================================================================
  // OPCIONES COMPARTIDAS
  // ===========================================================================
  //
  // Se reutilizan tanto en el modo "un solo sabor" (chips múltiples) como en
  // el modo "surtido variado" (selector de una variedad a la vez), para no
  // mantener dos listas duplicadas.

  static const List<Map<String, dynamic>> _saboresOptions = [
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
  ];

  static const List<Map<String, dynamic>> _sensacionOptions = [
    {'label': 'Meh', 'icon': Icons.sentiment_neutral_rounded},
    {'label': 'Mediocres', 'icon': Icons.sentiment_dissatisfied_rounded},
    {'label': 'Buenas', 'icon': Icons.thumb_up_outlined},
    {'label': 'Muy buenas', 'icon': Icons.star_border_rounded},
    {'label': 'Emocionantes', 'icon': Icons.local_fire_department_outlined},
    {'label': 'Religiosas', 'icon': Icons.auto_awesome_rounded},
    {'label': 'Basura', 'icon': Icons.delete_outline_rounded},
  ];

  @override
  List<Widget> buildFields(
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate,
    TextEditingController otroController,
  ) {
    final bool esSurtido = data['es_surtido'] == true;

    return [
      // =======================================================================
      // ¿ES UN SURTIDO VARIADO?
      // =======================================================================
      _buildSurtidoToggle(data, onUpdate),

      // =======================================================================
      // INGREDIENTES / SABOR (un sabor) O VARIEDADES (surtido)
      // =======================================================================
      if (esSurtido)
        _VariedadesBuilder(
          variedades: (data['variedades'] is List)
              ? List<Map<String, dynamic>>.from(
                  (data['variedades'] as List).map(
                    (item) => Map<String, dynamic>.from(item as Map),
                  ),
                )
              : const <Map<String, dynamic>>[],
          onChanged: (variedades) => onUpdate('variedades', variedades),
        )
      else
        _buildCompactChipGroup(
          'sabor',
          '¿Qué ingredientes llevan?',
          _saboresOptions,
          data,
          onUpdate,
          otroController,
        ),

      // =======================================================================
      // SENSACIONES
      // =======================================================================
      _buildCompactChipGroup(
        'sensacion',
        esSurtido
            ? '¿Sensación general del surtido?'
            : '¿Qué sensaciones te dejaron?',
        _sensacionOptions,
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
          // "Desintegración" (una sola palabra de 15 letras) se cortaba a
          // mitad de palabra en la rejilla de 3 columnas, igual que pasaba
          // con "Enciclopedia gastronómica" en atencion_fields.dart.
          {'label': 'Se deshace', 'icon': Icons.grain_rounded},
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
  // TOGGLE "SURTIDO VARIADO"
  // ===========================================================================

  Widget _buildSurtidoToggle(
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate,
  ) {
    final bool esSurtido = data['es_surtido'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        onTap: () => onUpdate('es_surtido', !esSurtido),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: esSurtido ? const Color(0xFFFFF6D6) : Colors.white,
            borderRadius: BorderRadius.circular(12),
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
              Icon(
                Icons.dining_outlined,
                size: 18,
                color: const Color(0xFF0F172A),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Croquetas variadas?',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Actívalo si el surtido mezcla más de un sabor',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: esSurtido,
                activeTrackColor: const Color(0xFFFFD400),
                onChanged: (value) => onUpdate('es_surtido', value),
              ),
            ],
          ),
        ),
      ),
    );
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
          // El número de columnas se calcula automáticamente según la
          // palabra más larga entre las opciones (ver NeoChip.columnsFor),
          // para que ninguna etiqueta se corte a mitad de palabra.
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

                  final List selectedItems = data[key] is List
                      ? List.from(data[key])
                      : [];

                  final bool isSelected = selectedItems.contains(option);

                  return NeoChip(
                    label: option,
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

// =============================================================================
// CONSTRUCTOR DE VARIEDADES (SURTIDO)
// =============================================================================
//
// Permite valorar cada sabor de un surtido de croquetas por separado (p. ej.
// "las de jamón buenísimas, las de boletus flojas"), en vez de forzar una
// única valoración global para todo el plato. Cada variedad añadida se
// guarda como {'sabor': String, 'valoracion': String} dentro de
// data['variedades'].
//
// Es un StatefulWidget propio (y no parte de la factory sin estado) porque
// necesita mantener la selección "en construcción" (sabor + valoración
// todavía sin confirmar) mientras el usuario decide, sin escribir campos
// temporales en el mapa de datos que se persiste.

class _VariedadesBuilder extends StatefulWidget {
  const _VariedadesBuilder({required this.variedades, required this.onChanged});

  final List<Map<String, dynamic>> variedades;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  @override
  State<_VariedadesBuilder> createState() => _VariedadesBuilderState();
}

class _VariedadesBuilderState extends State<_VariedadesBuilder> {
  String? _saborEnEdicion;
  String? _valoracionEnEdicion;
  final TextEditingController _otroController = TextEditingController();

  @override
  void dispose() {
    _otroController.dispose();
    super.dispose();
  }

  void _confirmarVariedad() {
    final String? sabor = _saborEnEdicion == 'Otro'
        ? (_otroController.text.trim().isEmpty
              ? 'Otro'
              : _otroController.text.trim())
        : _saborEnEdicion;

    if (sabor == null || _valoracionEnEdicion == null) return;

    final List<Map<String, dynamic>> updated = [
      ...widget.variedades,
      {'sabor': sabor, 'valoracion': _valoracionEnEdicion},
    ];

    widget.onChanged(updated);

    setState(() {
      _saborEnEdicion = null;
      _valoracionEnEdicion = null;
      _otroController.clear();
    });
  }

  void _eliminarVariedad(int index) {
    final List<Map<String, dynamic>> updated = List.of(widget.variedades)
      ..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final bool puedeConfirmar =
        _saborEnEdicion != null && _valoracionEnEdicion != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sabores del surtido',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Añade cada sabor con su propia valoración',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF0F172A).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),

          // ── Variedades ya añadidas ──────────────────────────────────────
          if (widget.variedades.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.variedades.asMap().entries.map((entry) {
                final int index = entry.key;
                final Map<String, dynamic> variedad = entry.value;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD400),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0F172A),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF0F172A),
                        blurRadius: 0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${variedad['sabor']} · ${variedad['valoracion']}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _eliminarVariedad(index),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          if (widget.variedades.isNotEmpty) const SizedBox(height: 14),

          // ── Formulario de nueva variedad ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0F172A).withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sabor',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: CroquetasFields._saboresOptions.map((option) {
                    final String label = option['label'] as String;
                    final bool selected = _saborEnEdicion == label;

                    return _buildMiniChip(
                      label: label,
                      icon: option['icon'] as IconData,
                      selected: selected,
                      onTap: () => setState(() => _saborEnEdicion = label),
                    );
                  }).toList(),
                ),
                if (_saborEnEdicion == 'Otro')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: _otroController,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Especifica el sabor',
                        hintStyle: GoogleFonts.inter(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Valoración de este sabor',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: CroquetasFields._sensacionOptions.map((option) {
                    final String label = option['label'] as String;
                    final bool selected = _valoracionEnEdicion == label;

                    return _buildMiniChip(
                      label: label,
                      icon: option['icon'] as IconData,
                      selected: selected,
                      onTap: () => setState(() => _valoracionEnEdicion = label),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    onTap: puedeConfirmar ? _confirmarVariedad : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: puedeConfirmar
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF0F172A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: puedeConfirmar
                                ? Colors.white
                                : const Color(
                                    0xFF0F172A,
                                  ).withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Añadir sabor al surtido',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: puedeConfirmar
                                  ? Colors.white
                                  : const Color(
                                      0xFF0F172A,
                                    ).withValues(alpha: 0.4),
                            ),
                          ),
                        ],
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

  Widget _buildMiniChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFD400) : const Color(0xFFF4F4F8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF0F172A)
                : const Color(0xFF0F172A).withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFF0F172A)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
