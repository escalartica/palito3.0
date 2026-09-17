import 'package:flutter/material.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_typography.dart';
import 'tokens/app_shape.dart';

class AppTheme {
  /// Grosor del borde neobrutalista. Los componentes usaban 1.5, 2, 2.5 y 3
  /// según el archivo; estas dos constantes son las únicas admitidas.
  static const double borderWidth = 2.0;
  static const double borderWidthThin = 1.5;
  static const double borderRadius = 16.0;
  static const Offset shadowOffset = Offset(3, 3);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // Los roles `on*` se declaran a mano: si se dejan a Material,
      // `onPrimary` se resuelve a blanco sobre el amarillo de marca (1,43:1),
      // y cualquier componente estándar (ElevatedButton, Chip, Checkbox) sale
      // ilegible. Hoy no se nota porque todas las pantallas pintan sus
      // colores a mano, que es justo el problema de fondo.
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.accent,
        onSecondary: AppColors.onAccent,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerLow: AppColors.background,
        error: AppColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.textPrimary, width: borderWidth),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
      ),

      // Los diálogos y snackbars sí usan los roles del tema, así que aquí sí
      // importa que estén bien.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),

      // ── EL MISMO FALLO QUE EL DE LOS BOTONES, EN LOS INDICADORES ──
      //
      // Un `CircularProgressIndicator` sin color propio usa
      // `colorScheme.primary`, que aquí es el amarillo de marca. Amarillo
      // #FFD400 sobre blanco mide **1,6:1**; un elemento gráfico necesita
      // 3:1. O sea que los indicadores de carga de la app —el del mapa, el
      // de la hoja de diarios, el de la foto que se descarga, el de la
      // invitación— se pintaban en un tono que apenas se distingue del
      // fondo. Justo el elemento cuya única función es hacerse notar
      // mientras esperas.
      //
      // Es el mismo fallo que ya se corrigió aquí abajo para `TextButton`;
      // el indicador se quedó fuera. Navy sobre blanco mide 17,85:1.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.textPrimary,
      ),

      // ── HOVER Y FOCO PARA TODO LO QUE SEA UN `InkWell` ──
      //
      // Aquí no había nada, así que Material usaba sus grises de fábrica: un
      // velo casi invisible sobre un fondo crema. En la práctica, pasar el
      // ratón por encima de algo pulsable en la PWA de escritorio no se
      // notaba, y tabular con un teclado tampoco.
      //
      // Los dos velos son del amarillo de marca y se diferencian en la
      // fuerza: el hover es una insinuación (vas por encima), el foco es una
      // afirmación (estás AQUÍ, y esto es lo que se va a activar).
      //
      // Con alfa y no opacos, a propósito: un velo de tinta se pinta ENCIMA
      // del contenido y no es el fondo de una `BoxDecoration`, así que no le
      // afecta el problema de las sombras macizas que documenta AppColors.
      hoverColor: AppColors.primary.withValues(alpha: 0.10),
      focusColor: AppColors.primary.withValues(alpha: 0.28),

      // La escala completa, no dos entradas sueltas: así los diálogos, los
      // menús, los SnackBar y los mensajes de error de los formularios —todo
      // lo que pinta Material por su cuenta— dejan de salir en Roboto.
      textTheme: AppTypography.textTheme,

      // ── EL PEOR CONTRASTE DE LA APP, Y ESTABA EN TODOS LOS DIÁLOGOS ──
      //
      // Un `TextButton` sin color propio usa `colorScheme.primary`, que aquí
      // es el amarillo de marca. Amarillo #FFD400 sobre blanco mide
      // **1,43:1**. El mínimo para texto es 4,5:1.
      //
      // Eso no afectaba a un botón: afectaba a las acciones de TODOS los
      // `AlertDialog` de la app —"Seguir editando", "Descartar", "Cancelar",
      // "Salir", "Quitar"— porque ninguno declaraba color. Se vio en el
      // simulador al intentar salir del formulario: las dos opciones del
      // diálogo eran dos manchas amarillas sobre blanco.
      //
      // Lo llamativo es que este archivo ya documentaba ese mismo 1,43:1
      // para el par inverso (`onPrimary: white` sobre amarillo) y lo había
      // corregido. La misma pareja de colores, al revés, seguía viva aquí.
      //
      // Se arregla en el tema y no diálogo por diálogo: son diez pantallas
      // distintas y lo que falla es el valor por defecto.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary, // 17,85:1 sobre blanco
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            color: AppColors.textPrimary,
            width: borderWidth,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: AppTypography.headlineSmall,
        contentTextStyle: AppTypography.bodyMedium,
      ),
    );
  }
}
