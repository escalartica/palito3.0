import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_animation.dart';
import '../../../core/theme/tokens/app_shape.dart';
import '../../../../core/theme/components/app_motion.dart';

/// Piezas de UI de bajo nivel compartidas por varias secciones del
/// formulario de recuerdo (`memory_form_page.dart` y los widgets bajo
/// `features/memory_form/widgets/`). Antes vivían como métodos privados
/// de `_MemoryFormPageState`; se extraen aquí porque los widgets de
/// sección ya no tienen acceso a esos métodos privados.

/// ===========================================================================
/// LOS RÓTULOS QUE EL AVISO DE «FALTA ESTO» TIENE QUE PODER NOMBRAR
/// ===========================================================================
///
/// Cuando le das a guardar sin rellenar algo obligatorio, la app dice «Para
/// guardar, rellena «X»» y hace scroll hasta ese sitio. Para que eso sirva de
/// algo, la X tiene que ser **exactamente** lo que pone en pantalla.
///
/// Ya pasó una vez: el aviso decía «Nombre de restaurante» y la sección se
/// llamaba «Restaurante / Lugar». Dos nombres para la misma cosa obligan a
/// deducir cuál es, justo en el momento en que la app te está diciendo que
/// algo va mal.
///
/// Y hoy mismo, en otra pantalla, ha aparecido el mismo problema con
/// consecuencias peores: el mensaje de invitación mandaba a la gente a tocar
/// un botón del Perfil renombrado hacía meses. Había un comentario pidiendo
/// cuidado. No sirvió — un comentario le pide cuidado a quien edita ESE
/// fichero, y quien renombra un rótulo está editando otro.
///
/// Así que estos cuatro no son literales sueltos: el rótulo y el aviso leen
/// la misma constante, y renombrar uno cambia el otro. No hay nada que
/// recordar.
abstract final class SectionLabels {
  static const String restaurante = 'Restaurante / Lugar';
  static const String ubicacion = 'Ubicación';
  static const String puntuacion = 'Puntuación general';
  static const String volverias = '¿Volverías a este lugar?';
}

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
        color: AppColors.textPrimary,
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
      duration: AppMotion.dur(context, AppAnimation.fast),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.textPrimary, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.textPrimary,
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
    // Sin contador. Los topes de este formulario no son una cuota que haya
    // que administrar —doscientos caracteres para el nombre de un plato es
    // muchísimo—: son una barrera para que nadie llegue a un límite del
    // servidor sin enterarse. Un «0/200» bajo cada campo convertiría un
    // seguro invisible en una cuenta atrás.
    counterText: '',
    hintText: hint,
    hintStyle: GoogleFonts.inter(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w400,
      fontSize: 14,
    ),
    border: InputBorder.none,
    contentPadding:
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
