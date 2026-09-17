import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_shape.dart';
import 'app_dock.dart';

/// ===========================================================================
/// LO QUE LA APP TE CONTESTA
/// ===========================================================================
///
/// Todos los avisos de Palito, en un solo sitio y hablando el idioma de la
/// app.
///
/// POR QUÉ HACÍA FALTA. Había **dieciocho** `SnackBar` escritos a mano por la
/// app, y diecisiete de ellos usaban el aspecto que trae Material de fábrica:
/// una barra gris oscura, con sus esquinas y su tipografía. Es decir que la
/// única respuesta que da la app cuando guardas un recuerdo, cuando copias un
/// código o cuando algo falla venía **de otra aplicación**: ni el navy, ni el
/// borde, ni la sombra maciza, ni una sola cosa del lenguaje de Palito.
///
/// Y había algo peor que el aspecto. Un `SnackBar` flotante se coloca abajo,
/// dentro del `Scaffold` de la pantalla; pero en las cuatro pestañas el dock
/// se pinta **por encima** de esa pantalla, en el `Stack` del andamio (ver
/// main.dart). O sea que en Inicio, Mapa, La ruleta y Perfil los avisos
/// salían medio tapados por la barra de navegación. Lo importante que tenía
/// que decir la app quedaba detrás del mueble.
///
/// TRES TIPOS Y NO MÁS. Un aviso sirve para una de tres cosas: confirmar que
/// algo ha salido bien, avisar de que algo no ha ido del todo bien, o decir
/// que ha fallado. Cada uno tiene su color, su icono y su háptica, así que se
/// reconocen antes de leerlos.
enum FeedbackKind { success, warning, error }

abstract final class AppFeedback {
  /// Ha salido bien.
  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(context, message, FeedbackKind.success, actionLabel, onAction);

  /// Ha salido, pero con un pero.
  static void warning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(context, message, FeedbackKind.warning, actionLabel, onAction);

  /// No ha salido.
  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(context, message, FeedbackKind.error, actionLabel, onAction);

  static void _show(
    BuildContext context,
    String message,
    FeedbackKind kind, [
    String? actionLabel,
    VoidCallback? onAction,
  ]) {
    // ── La háptica llega ANTES que el texto ──
    //
    // Se dispara aquí, en el mismo instante en que se pide el aviso, no
    // cuando termina de entrar. Un golpecito que llega medio segundo después
    // del gesto no se lee como respuesta al gesto: se lee como otra cosa que
    // ha pasado luego.
    switch (kind) {
      case FeedbackKind.success:
        HapticFeedback.lightImpact();
      case FeedbackKind.warning:
        HapticFeedback.selectionClick();
      case FeedbackKind.error:
        HapticFeedback.mediumImpact();
    }

    final (Color fondo, IconData icono, Color tintaIcono) = switch (kind) {
      FeedbackKind.success => (
        AppColors.tintSuccess,
        Icons.check_rounded,
        AppColors.success,
      ),
      FeedbackKind.warning => (
        AppColors.tintPrimary,
        Icons.info_outline_rounded,
        AppColors.textPrimary,
      ),
      FeedbackKind.error => (
        AppColors.tintError,
        Icons.error_outline_rounded,
        AppColors.error,
      ),
    };

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      // Sin esto, tocar dos veces algo que falla encola dos avisos y el
      // segundo espera a que el primero se vaya. Quien lo ve piensa que la
      // app va con retraso.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // La `SnackBar` de Material no pinta nada: pone el sitio, y el
          // dibujo es nuestro.
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          behavior: SnackBarBehavior.floating,
          // Un error hay que poder leerlo dos veces; un "hecho" se entiende
          // de un vistazo.
          duration: kind == FeedbackKind.error
              ? const Duration(seconds: 5)
              : const Duration(seconds: 3),
          // Por encima del dock SIEMPRE, también en las pantallas que no lo
          // tienen. Vale más un aviso dos centímetros más arriba de lo
          // necesario que uno tapado por la barra, y así todos los avisos de
          // la app aparecen exactamente a la misma altura — que es lo que
          // hace que se reconozcan sin leerlos.
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom:
                AppDock.height + 16 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppBorder.normal,
              ),
              boxShadow: AppShadow.lg,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // Tinte OPACO, no un alfa: una `BoxDecoration` pinta la
                    // sombra antes que el fondo, y con alfa la sombra navy se
                    // ve a través. Ver AppColors.
                    color: fondo,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                      color: AppColors.textPrimary,
                      width: AppBorder.thin,
                    ),
                  ),
                  child: Icon(icono, size: 17, color: tintaIcono),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    message,
                    maxLines: 4,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // La salida, cuando el aviso ofrece una. Dos avisos de la app
                // llevaban una: "Ajustes" cuando faltan permisos de
                // ubicación y "Deshacer" al reiniciar la partida. Sin esto
                // habrían tenido que quedarse con el aspecto de Material y
                // seguiríamos con dos idiomas.
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      onAction();
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: AppColors.textPrimary,
                      textStyle: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
  }
}
