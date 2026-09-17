import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_animation.dart';
import '../tokens/app_shape.dart';
import 'app_motion.dart';

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

  /// Altura MÍNIMA de todo chip. Antes era fija (42 px): con el texto del
  /// sistema ampliado, la segunda línea se recortaba y el `ellipsis` se comía
  /// la etiqueta. 44 px es además el objetivo táctil mínimo de las HIG.
  static const double minHeight = 44;

  /// Compatibilidad con el código que leía la altura fija.
  static const double height = minHeight;

  static const double fontSize = 11;
  static const double gridSpacing = 6;

  /// Espacio que consumen borde + padding + icono + separación dentro del
  /// chip, es decir, lo que NO queda para el texto.
  static const double _chrome = 2 * 2 + 2 * 6 + 13 + 4;

  /// Calcula cuántas columnas caben en una rejilla de chips sin que ninguna
  /// palabra se parta a mitad.
  ///
  /// La versión anterior usaba un umbral fijo de caracteres (`> 13 ? 2 : 3`)
  /// sin mirar el ancho real de la pantalla ni el tamaño de letra del
  /// sistema. "Decepcionante" tiene exactamente 13 caracteres, así que caía
  /// en la rama de 3 columnas: en un móvil de 360 dp el texto necesita ~79 dp
  /// y solo hay ~71, y Flutter lo partía en "Decepcionant" / "e" — el defecto
  /// que se ve en el vídeo. Con el texto ampliado fallaba en cualquier móvil.
  ///
  /// Ahora se mide de verdad con un [TextPainter] contra el ancho disponible.
  /// [maxWidth] y [textScaler] son opcionales para no romper las llamadas
  /// antiguas, pero conviene pasarlos siempre.
  static int columnsFor(
    List<String> labels, {
    double? maxWidth,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final List<String> words = labels
        .expand((String label) => label.split(RegExp(r'[\s/]+')))
        .where((String w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return 3;

    if (maxWidth == null || maxWidth <= 0) {
      // Sin ancho no se puede medir: heurística conservadora (antes 13, que
      // dejaba fuera justo el caso que fallaba).
      final int longest = words
          .map((String w) => w.length)
          .fold(0, (int max, int len) => len > max ? len : max);
      return longest > 11 ? 2 : 3;
    }

    // TextStyle plana, no `GoogleFonts.inter(...)`: esta función es lógica
    // pura, invocada desde tests que no inicializan el binding de Flutter.
    // `GoogleFonts` intenta comprobar/cargar la fuente vía el asset bundle en
    // cuanto se construye el estilo, lo que revienta fuera de un widget test.
    // Para una heurística de "cuántas columnas caben" la métrica de la
    // fuente del sistema es suficiente — no hace falta el glifo exacto de
    // Inter.
    const TextStyle style = TextStyle(
      fontWeight: FontWeight.w700, // el más ancho de los dos estados
      fontSize: fontSize,
      height: 1.1,
    );

    double widestWord = 0;
    for (final String word in words) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      if (painter.width > widestWord) widestWord = painter.width;
      painter.dispose();
    }

    for (final int columns in <int>[3, 2]) {
      final double chipWidth =
          (maxWidth - gridSpacing * (columns - 1)) / columns;
      if (chipWidth - _chrome >= widestWord) return columns;
    }

    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final Widget chip = AnimatedScale(
      scale: isSelected ? 1.02 : 1.0,
      duration: reduceMotion
          ? Duration.zero
          : AppAnimation.fast,
      curve: AppAnimation.pop,
      // Sin un Material propio, la onda del InkWell se pintaba por DETRÁS del
      // AnimatedContainer opaco: al tocar un chip no había ninguna
      // confirmación visual.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : AppAnimation.fast,
            curve: AppAnimation.enter,
            constraints: const BoxConstraints(minHeight: minHeight),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textPrimary.withValues(alpha: 0.35),
                width: AppBorder.normal,
              ),
              boxShadow: isSelected
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: AppColors.textPrimary,
                        blurRadius: 0,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : AppAnimation.fast,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return AppMotion.popIn(animation, child);
                      },
                  child: Icon(
                    icon,
                    key: ValueKey<String>('${label}_$isSelected'),
                    size: 13,
                    color: AppColors.textPrimary,
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
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: AppColors.textPrimary,
                      fontSize: fontSize,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: ExcludeSemantics(
        child: width != null ? SizedBox(width: width, child: chip) : chip,
      ),
    );
  }
}
