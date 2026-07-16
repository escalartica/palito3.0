import 'package:flutter/material.dart';
import '../../../core/factories/dynamic_field_factory.dart';

class PostreFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(Map<String, dynamic> data, Function(String, dynamic) onUpdate, TextEditingController otroController) {
    return [
      _section("🍰 Identidad del Dulce"),
      _text('nombre_postre', 'Nombre del Postre o Helado', onUpdate),
      _text('precio', 'Precio (€)', onUpdate),
      
      _section("🍦 Anatomía Sensorial"),
      _multi('perfil_sabor', ['Muy dulce', 'Equilibrado', 'Ácido', 'Amargo', 'Salado', 'Intenso', 'Refrescante', 'Cremoso'], data, onUpdate),
      _multi('textura', ['Muy cremosa', 'Aireada', 'Crujiente', 'Esponjosa', 'Fundente', 'Perfecta'], data, onUpdate),
      _choice('temperatura', ['Muy caliente', 'Tibio', 'Ambiente', 'Frío', 'Muy frío', 'Contraste F/C'], data, onUpdate),
      
      _section("🔍 Análisis Técnico"),
      _slider('intensidad', 'Intensidad principal', 0, 10, data, onUpdate),
      _choice('tamano', ['Muy pequeño', 'Correcto', 'Grande', 'Para compartir'], data, onUpdate),
      
      _section("✨ La Experiencia"),
      _choice('mejor_parte', ['Sabor', 'Textura', 'Temperatura', 'Presentación', 'Contraste', 'Creatividad'], data, onUpdate),
      _dropdown('emocion', ['Amor', 'Vicio', 'Sorpresa', 'Confort', 'Nostalgia', 'Increíble', 'Decepción'], data, onUpdate),
      
      _section("🏆 Premio Palito"),
      _dropdown('premio', ['Más refrescante', 'Más goloso', 'Mejor tarta de queso', 'Mejor helado', 'Mejor contraste', 'Obra maestra', 'Para volver mañana'], data, onUpdate),
      
      _section("🍽️ El Cierre"),
      _choice('ultima_cucharada', ['Quería otro', 'Perfecto, terminó a tiempo', 'Se hizo pesado', 'Me sobró', 'Me lo quitaron'], data, onUpdate),
      _text('recuerdo', '¿Qué recordarás dentro de un año?', onUpdate),
    ];
  }

  // Widgets auxiliares
  Widget _section(String title) => Padding(padding: const EdgeInsets.only(top: 25, bottom: 10), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pinkAccent)));
  Widget _text(String key, String label, Function(String, dynamic) onUpdate) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextFormField(decoration: InputDecoration(labelText: label), onChanged: (v) => onUpdate(key, v)));
  Widget _choice(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => Wrap(spacing: 8, children: opts.map((o) => ChoiceChip(label: Text(o), selected: data[key] == o, onSelected: (s) => onUpdate(key, s ? o : null))).toList());
  Widget _multi(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => Wrap(spacing: 8, children: opts.map((o) { final list = (data[key] as List?) ?? []; return FilterChip(label: Text(o), selected: list.contains(o), onSelected: (s) { final l = List.from(list); s ? l.add(o) : l.remove(o); onUpdate(key, l); }); }).toList());
  Widget _dropdown(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => DropdownButtonFormField(value: data[key], isExpanded: true, items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(), onChanged: (v) => onUpdate(key, v));
  Widget _slider(String key, String label, double min, double max, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Slider(value: (data[key] ?? 0).toDouble(), min: min, max: max, divisions: 10, onChanged: (v) => onUpdate(key, v))]);
}