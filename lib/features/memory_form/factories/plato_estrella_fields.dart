import 'package:flutter/material.dart';
import '../../../../../../../core/factories/dynamic_field_factory.dart';

class PlatoEstrellaFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(Map<String, dynamic> data, Function(String, dynamic) onUpdate, TextEditingController otroController) {
    return [
      _section("📋 Datos del Plato"),
      _text('nombre_plato', 'Nombre del plato', onUpdate),
      _choice('tipo_plato', ['Carne', 'Pescado', 'Pasta', 'Arroz', 'Verduras', 'Cuchara', 'Brasa', 'Marisco', 'Internacional'], data, onUpdate),
      
      _section("🧑‍🍳 Técnica y Equilibrio"),
      _multi('tecnica', ['Brasa perfecta', 'Baja temperatura', 'Frito impecable', 'Crujiente', 'Ahumado', 'Confitado', 'Fermentado'], data, onUpdate),
      _choice('coccion', ['Crudo', 'Poco hecho', 'Al punto', 'Muy hecho', 'Perfecto'], data, onUpdate),
      _choice('equilibrio', ['Perfecto', 'Muy salado', 'Muy dulce', 'Muy ácido', 'Falta intensidad'], data, onUpdate),

      _section("💥 Impacto Sensorial"),
      _choice('primer_bocado', ['Correcto', 'Interesante', 'Muy bueno', 'Sonreí', 'Acertamos'], data, onUpdate),
      _multi('emocion', ['Reconfortado', 'Sorprendido', 'Feliz', 'Nostálgico', 'Impresionado', 'Divertido'], data, onUpdate),
      
      _section("🏆 Premio Palito y Decisión"),
      _dropdown('premio', ['Obra maestra', 'Vale el viaje', 'Amor a primer bocado', 'Motivo para volver', 'Joya escondida', 'El mejor del año'], data, onUpdate),
      _choice('momento_especial', ['Antes de probar', 'Primer bocado', 'Mitad', 'Último bocado', 'Al día siguiente'], data, onUpdate),
      _choice('harias_por_volver', ['Lo pediré otra vez', 'Cambiaría mi ruta', 'Haría un viaje solo', 'Lo echaré de menos', 'Ya planificando'], data, onUpdate),
    ];
  }

  // Widgets auxiliares (reutilizando tu lógica de diseño)
  Widget _section(String title) => Padding(padding: const EdgeInsets.only(top: 25, bottom: 10), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)));
  
  Widget _text(String key, String label, Function(String, dynamic) onUpdate) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextFormField(decoration: InputDecoration(labelText: label), onChanged: (v) => onUpdate(key, v)));
  
  Widget _choice(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => 
    Wrap(spacing: 8, children: opts.map((o) => ChoiceChip(label: Text(o), selected: data[key] == o, onSelected: (s) => onUpdate(key, s ? o : null))).toList());

  Widget _multi(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) =>
    Wrap(spacing: 8, children: opts.map((o) {
      final list = (data[key] as List?) ?? [];
      return FilterChip(label: Text(o), selected: list.contains(o), onSelected: (s) {
        final l = List.from(list);
        s ? l.add(o) : l.remove(o);
        onUpdate(key, l);
      });
    }).toList());

  Widget _dropdown(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) =>
    DropdownButtonFormField(value: data[key], isExpanded: true, items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(), onChanged: (v) => onUpdate(key, v));
}