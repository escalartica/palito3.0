import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

/// ===========================================================================
/// EL CAMPO DE TEXTO DE LAS CATEGORÍAS
/// ===========================================================================
///
/// Un solo campo, usado por las ocho fábricas de categoría. Antes cada una
/// llevaba su propia copia de un `_buildCustomTextField` de cincuenta líneas
/// —siete copias del mismo código, con siete oportunidades de divergir— y en
/// una de ellas se había colado esto:
///
/// ```dart
/// TextFormField(
///   key: ValueKey('${key}_${data[key] ?? ''}'),   // ← el texto, en la clave
///   initialValue: data[key]?.toString() ?? '',
///   onChanged: (v) => onUpdate(key, v),           // ← y un setState detrás
/// )
/// ```
///
/// Flutter usa la clave para decidir si un widget que vuelve a aparecer es
/// **el mismo** de antes. Al meter el contenido dentro de la clave, escribir
/// una letra cambiaba la clave, y Flutter concluía —correctamente— que ese
/// ya no era el mismo campo: destruía el anterior con todo su estado, y con
/// él el foco. El teclado se cerraba después de cada pulsación. Escribir
/// "croquetas" eran nueve toques en el campo y nueve letras perdidas.
///
/// Las tres reglas que hacen que esto no pueda repetirse:
///
/// 1. **La clave es la clave del campo y nada más.** Identifica *qué* campo
///    es, nunca *qué pone dentro*. Además así el campo sobrevive a que
///    aparezca o desaparezca otro por encima suyo, que es lo que pasa cuando
///    marcas "Otro" en un chip.
///
/// 2. **El controlador es suyo y vive lo que vive el campo.** Nada de
///    `initialValue`, que se relee en cada reconstrucción y devuelve el
///    cursor al principio a mitad de palabra.
///
/// 3. **Escribir no reconstruye el formulario.** El texto se guarda
///    directamente en el mapa de datos, que es el mismo objeto que lee
///    `memory_form_page` al guardar. Antes cada letra disparaba un
///    `setState` de la pantalla entera: foto, ubicación, sliders y los
///    treinta chips de la categoría, repintados sesenta veces por palabra.
class MemoryTextField extends StatefulWidget {
  MemoryTextField({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.data,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    // La clave ES la clave del campo. Ver la regla 1 de arriba: nunca su
    // contenido, y nunca `null` —sin clave, Flutter empareja por posición y
    // el campo se confunde con su vecino cuando aparece uno nuevo encima.
  }) : super(key: ValueKey<String>('campo-$fieldKey'));

  /// Clave dentro de [data]. Es también la identidad del campo.
  final String fieldKey;
  final String label;
  final String hint;

  /// El mapa de respuestas de la categoría. Se escribe aquí directamente:
  /// es el mismo objeto que el formulario lee al guardar.
  final Map<String, dynamic> data;

  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;

  /// Solo para el caso raro en que algo de la interfaz dependa de este texto.
  /// Por defecto no se avisa a nadie, que es justamente lo que evita el
  /// repintado del formulario entero en cada tecla.
  final ValueChanged<String>? onChanged;

  @override
  State<MemoryTextField> createState() => _MemoryTextFieldState();
}

class _MemoryTextFieldState extends State<MemoryTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.data[widget.fieldKey]?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    // Vacío es ausencia, no cadena vacía: así el recuerdo guardado no lleva
    // campos en blanco y la comparación de "¿hay cambios sin guardar?" no
    // ve una diferencia donde no la hay.
    if (value.trim().isEmpty) {
      widget.data.remove(widget.fieldKey);
    } else {
      widget.data[widget.fieldKey] = value;
    }
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      // MergeSemantics: la etiqueta de arriba y el campo, un solo nodo.
      //
      // El patrón era un `Text(label)` visual encima y un campo que por
      // dentro solo llevaba `hintText`. En Flutter un `Text` hermano NO se
      // asocia al campo: VoiceOver anunciaba la pista, no la etiqueta. Y en
      // cuanto escribes una letra la pista desaparece, así que el campo se
      // quedaba literalmente sin nombre.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.textPrimary,
                  width: AppBorder.thin,
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: AppColors.textPrimary,
                    blurRadius: 0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                keyboardType: widget.keyboardType,
                textCapitalization: TextCapitalization.sentences,
                // Con varias líneas, Enter salta de línea; con una sola,
                // Enter salta al campo siguiente en vez de cerrar el
                // teclado y dejarte a medias.
                textInputAction: widget.maxLines > 1
                    ? TextInputAction.newline
                    : TextInputAction.next,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onChanged: _handleChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
