import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Piezas de UI de bajo nivel compartidas por varias secciones del
/// formulario de recuerdo (`memory_form_page.dart` y los widgets bajo
/// `features/memory_form/widgets/`). Antes vivían como métodos privados
/// de `_MemoryFormPageState`; se extraen aquí porque los widgets de
/// sección ya no tienen acceso a esos métodos privados.

/// Etiqueta de sección ("Categoría", "Ubicación"...) con el estilo
/// tipográfico estándar del formulario.
class SectionLabel extends StatelessWidget {
  final String title;

  const SectionLabel(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF0F172A),
      ),
    );
  }
}

/// Contenedor "neo-brutalista" (borde negro grueso + sombra dura) que
/// envuelve los campos de texto/desplegables del formulario.
class NeoContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const NeoContainer({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0F172A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0F172A),
            blurRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Decoración de `InputDecoration` estándar (sin borde, hint gris) usada
/// por los campos de texto del formulario de recuerdo.
InputDecoration memoryFormInputDecoration(
  String hint, {
  EdgeInsetsGeometry? contentPadding,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(
      color: Colors.grey.shade400,
      fontWeight: FontWeight.w400,
      fontSize: 14,
    ),
    border: InputBorder.none,
    contentPadding:
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
