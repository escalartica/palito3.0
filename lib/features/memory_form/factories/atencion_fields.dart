import 'package:flutter/material.dart';
import '../../../../../../../core/factories/dynamic_field_factory.dart';

class AtencionFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(Map<String, dynamic> data, Function(String, dynamic) onUpdate, TextEditingController otroController) {
    return [
      _section("👤 El Factor Humano"),
      _text('nombre_staff', '¿Quién hizo especial la experiencia?', onUpdate),
      _slider('nota_atencion', 'Nota de la atención (0-10)', 0, 10, data, onUpdate),
      
      _section("⏱ Ritmo y Disponibilidad"),
      _choice('espera', ['Inmediato', 'Muy rápido', 'Correcto', 'Lento', 'Desesperante'], data, onUpdate),
      _choice('disponibilidad', ['Siempre', 'Casi siempre', 'Normal', 'Difícil', 'Imposible'], data, onUpdate),
      
      _section("🧠 Conocimiento y Recomendaciones"),
      _choice('conocimiento', ['No supo responder', 'Dudó', 'Correcto', 'Sabía todo', 'Parecía el chef'], data, onUpdate),
      _choice('recomendaciones', ['No pregunté', 'No supieron', 'Correctas', 'Muy buenas', 'Increíbles'], data, onUpdate),
      
      _section("❤️ El Toque Personal"),
      _choice('despedida', [
        'Ni nos miraron', 
        'Un "hasta luego"', 
        'Nos dieron las gracias', 
        'Nos despidieron por nuestro nombre', 
        'Salimos con una sonrisa'
      ], data, onUpdate),
      
      _section("🎭 Casting del Equipo"),
      _text('personaje_staff', 'Si el equipo fuera un personaje, ¿quién sería?', onUpdate),
      _text('frase_recordada', '¿Alguna frase que merezca ser recordada?', onUpdate),
      
      _section("🌟 Premios Palito"),
      _dropdown('premio_servicio', ['Servicio 5 estrellas', 'Mejor sonrisa', 'Como en casa', 'Enciclopedia gastronómica', 'Equipo inolvidable'], data, onUpdate),
    ];
  }

  // --- Widgets con el estilo Palito ---
  Widget _section(String title) => Padding(padding: const EdgeInsets.only(top: 30, bottom: 15), child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent)));
  Widget _text(String key, String label, Function(String, dynamic) onUpdate) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(decoration: InputDecoration(labelText: label, border: OutlineInputBorder()), onChanged: (v) => onUpdate(key, v)));
  Widget _choice(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => Wrap(spacing: 8, runSpacing: 8, children: opts.map((o) => ChoiceChip(label: Text(o), selected: data[key] == o, onSelected: (s) => onUpdate(key, s ? o : null))).toList());
  Widget _slider(String key, String label, double min, double max, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), Slider(value: (data[key] ?? 0).toDouble(), min: min, max: max, divisions: 10, label: "${data[key]}", onChanged: (v) => onUpdate(key, v))]);
  Widget _dropdown(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => DropdownButtonFormField(value: data[key], isExpanded: true, items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(), onChanged: (v) => onUpdate(key, v));
}