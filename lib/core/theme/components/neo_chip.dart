import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Chip de selección con el estilo neobrutalista de Palito (borde grueso,
/// sombra dura, fondo amarillo si está seleccionado). Es el widget visual
/// compartido por todos los formularios de recuerdo (`factories/*_fields.dart`)
/// — antes cada archivo tenía su propia copia casi idéntica de este widget.
///
/// Altura fija ([height]) para que una rejilla de chips con textos de
/// longitud muy distinta ("Densa" vs "Cemento armado") se vea homogénea en
/// vez de con alturas dispares según el texto ocupe 1 o 2 líneas.
class NeoChip extends StatelessWidget {
  const NeoChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.width,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final double? width;

  /// Altura fija de todo chip, independientemente de si su texto ocupa
  /// una o dos líneas. Compacta a propósito: con 3 columnas + fuente
  /// pequeña, una sola línea basta para casi cualquier etiqueta, así que
  /// no hace falta reservar la altura de dos líneas por defecto.
  static const double height = 42;

  /// Calcula cuántas columnas caben en una rejilla de chips sin que
  /// ninguna palabra individual se vea forzada a partirse a mitad
  /// (el bug original: "Enciclopedia gastronómica" → "Enciclopedi" /
  /// "a gastronó..."). Con el tamaño de fuente de [NeoChip], 3 columnas
  /// admiten cómodamente palabras de hasta ~13 caracteres; solo palabras
  /// más largas que eso fuerzan 2 columnas (más chips por fila = formulario
  /// más corto, así que se evita bajar a 2 salvo que sea necesario).
  static int columnsFor(List<String> labels) {
    final int longestWord = labels
        .expand((label) => label.split(' '))
        .map((word) => word.length)
        .fold(0, (max, len) => len > max ? len : max);

    return longestWord > 13 ? 2 : 3;
  }

  @override
  Widget build(BuildContext context) {
    final Widget chip = AnimatedScale(
      scale: isSelected ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  icon,
                  key: ValueKey('${label}_$isSelected'),
                  size: 13,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: const Color(0xFF0F172A),
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return width != null ? SizedBox(width: width, child: chip) : chip;
  }
}

/// Rejilla de chips de selección (título + [Wrap] de [NeoChip]) con columnas
/// calculadas automáticamente vía [NeoChip.columnsFor]. Cubre el caso común
/// de selección simple o múltiple; los formularios con necesidades extra
/// (campo "Otro", etc.) siguen componiendo [NeoChip] directamente.
class NeoChipGroup extends StatelessWidget {
  const NeoChipGroup({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onToggle,
  });

  final String title;

  /// Cada opción es {'label': String, 'icon': IconData}.
  final List<Map<String, dynamic>> options;
  final Set<String> selectedValues;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final List<String> labels = options
        .map((option) => option['label'] as String)
        .toList();
    final int columns = NeoChip.columnsFor(labels);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 6.0;
              final double chipWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: options.map((option) {
                  final String label = option['label'] as String;

                  return NeoChip(
                    label: label,
                    icon: option['icon'] as IconData,
                    isSelected: selectedValues.contains(label),
                    width: chipWidth,
                    onTap: () => onToggle(label),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
