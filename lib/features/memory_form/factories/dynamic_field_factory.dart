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