import 'package:flutter/material.dart';

class FormQuestion {
  final Widget widget;
  FormQuestion({required this.widget});
}

class CategoryFormFactory {
  static List<FormQuestion> getFields(String category, Map<String, dynamic> data, Function(String, dynamic) onUpdate) {
    if (category == "Croquetas") {
      return [
        FormQuestion(widget: _buildSelector(data, onUpdate, 'sabor', '¿Qué sabor eran?', ['Jamón', 'Cocido', 'Boletus', 'Cecina', 'Bacalao', 'Rabo de toro', 'Gamba', 'Queso', 'Pollo', 'Espinacas', 'Otro'])),
        FormQuestion(widget: _buildSelector(data, onUpdate, 'sensacion', '¿Qué sensación te dejaron?', ['😐 Meh', '🙂 Buenas', '🤤 Muy buenas', '🥹 Emocionantes', '🙏 Religiosas'])),
        FormQuestion(widget: _buildSelector(data, onUpdate, 'bechamel', 'La bechamel era...', ['Demasiado líquida', 'Muy cremosa', 'Equilibrada', 'Densa', 'Cemento armado'])),
        FormQuestion(widget: _buildSelector(data, onUpdate, 'rebozado', 'El rebozado...', ['Muy fino', 'Crujiente perfecto', 'Muy grueso', 'Aceitoso', 'Se desprendía'])),
        FormQuestion(widget: TextField(decoration: const InputDecoration(labelText: '¿Cuál fue el primer pensamiento?'), onChanged: (v) => onUpdate('primer_pensamiento', v))),
        FormQuestion(widget: _buildSelector(data, onUpdate, 'cantidad', '¿Cuántas os habríais comido?', ['Una fue suficiente', 'Una ración', 'Dos raciones', 'Hasta cerrar la cocina'])),
        FormQuestion(widget: _buildSelector(data, onUpdate, 'volveria', '¿Las volverías a pedir?', ['SIEMPRE', 'DEPENDE', 'NO'])),
      ];
    }
    return [];
  }

  static Widget _buildSelector(Map<String, dynamic> data, Function(String, dynamic) onUpdate, String key, String label, List<String> options) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      value: data[key],
      items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => onUpdate(key, v),
    );
  }
}