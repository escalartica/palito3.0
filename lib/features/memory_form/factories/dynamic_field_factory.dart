import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'croquetas_fields.dart';
import 'tortilla_fields.dart';
import 'ensaladilla_fields.dart';
import 'plato_estrella_fields.dart';
import 'menu_fields.dart';
import 'postre_fields.dart';
import 'ambiente_fields.dart';
import 'atencion_fields.dart';

abstract class DynamicFieldGenerator {
  List<Widget> buildFields(
    Map<String, dynamic> data,
    Function(String, dynamic) onUpdate,
    TextEditingController otroController,
  );
}

class DynamicFieldFactory {
  static DynamicFieldGenerator? getGenerator(String categoryName) {
    final key = categoryName.trim();

    switch (key) {
      case "Croquetas":
        return CroquetasFields();
      case "Tortilla":
        return TortillaFields();
      case "Ensaladilla":
        return EnsaladillaFields();
      case "Plato Estrella":
        return PlatoEstrellaFields();
      case "Menú":
        return MenuFields();
      case "Postres / Helados":
        return PostreFields();
      case "Decoración / Espacio":
        return AmbienteFields();
      case "Atención":
        return AtencionFields();

      default:
        _log("Fábrica: No se encontró generador para la categoría '$key'");
        return null;
    }
  }
}

// ===========================================================================
// LOGS
// ===========================================================================
//
// `debugPrint` NO se desactiva en una build de release: sigue escribiendo al
// log del sistema (Console.app en iOS, logcat en Android), donde lo puede leer
// cualquiera con el dispositivo delante o un informe de diagnóstico. Este
// archivo estaba volcando ahí identificadores de usuario, de grupo y datos de
// ubicación. Con este envoltorio, en release no se escribe nada.
void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

void _logStack({StackTrace? stackTrace}) {
  if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
}
