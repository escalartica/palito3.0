import 'package:flutter/material.dart';
import '../../features/memory_form/factories/croquetas_fields.dart';
import '../../features/memory_form/factories/tortilla_fields.dart';
import '../../features/memory_form/factories/ensaladilla_fields.dart';
import '../../features/memory_form/factories/plato_estrella_fields.dart';
import '../../features/memory_form/factories/menu_fields.dart';
import '../../features/memory_form/factories/postre_fields.dart';
import '../../features/memory_form/factories/ambiente_fields.dart';
import '../../features/memory_form/factories/atencion_fields.dart';

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
      case "Croquetas": return CroquetasFields();
      case "Tortilla": return TortillaFields();
      case "Ensaladilla": return EnsaladillaFields();
      case "Plato Estrella": return PlatoEstrellaFields();
      case "Menú": return MenuFields();
      case "Postres / Helados": return PostreFields();
      case "Decoración / Espacio": return AmbienteFields();
      case "Atención": return AtencionFields();
      
      default: 
        debugPrint("Fábrica: No se encontró generador para la categoría '$key'");
        return null;
    }
  }
}