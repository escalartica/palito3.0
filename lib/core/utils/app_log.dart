import 'package:flutter/foundation.dart';

/// ===========================================================================
/// APP LOG
/// ===========================================================================
///
/// `debugPrint` NO desaparece en una build de release: sigue escribiendo al
/// log del sistema (Console.app en iOS, logcat en Android), donde lo puede
/// leer cualquiera con el dispositivo delante o un informe de diagnóstico.
/// La app estaba imprimiendo ahí uids, direcciones de correo, coordenadas y
/// —lo más grave— ids de grupo, que son la credencial de acceso a un diario
/// compartido.
///
/// Regla de la casa: en release no se escribe nada, y ningún mensaje lleva
/// datos personales aunque estemos en debug. Si hace falta identificar a
/// alguien mientras se depura, usa [redact], que deja solo un prefijo corto
/// —suficiente para correlacionar dos líneas del mismo log, inútil para
/// identificar a nadie fuera de él.
/// ===========================================================================

abstract final class AppLog {
  /// Información de flujo normal.
  static void i(String message) {
    if (kDebugMode) debugPrint('ℹ️  $message');
  }

  /// Algo ha ido mal pero la app sigue funcionando.
  static void w(String message) {
    if (kDebugMode) debugPrint('⚠️  $message');
  }

  /// Error. [error] y [stackTrace] solo se imprimen en debug; en release el
  /// canal correcto es Crashlytics, no el log del sistema.
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint('❌ $message${error == null ? '' : ' — $error'}');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }

  /// Recorta un identificador para poder correlacionar líneas sin exponerlo.
  /// `redact('kJ3nDk29fLpQx1')` → `kJ3n…`
  static String redact(String? value) {
    if (value == null || value.isEmpty) return '(vacío)';
    if (value.length <= 4) return '…';
    return '${value.substring(0, 4)}…';
  }
}
