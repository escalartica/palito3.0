import 'package:flutter/material.dart';
import '../../../core/factories/dynamic_field_factory.dart';

class AmbienteFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(Map<String, dynamic> data, Function(String, dynamic) onUpdate, TextEditingController otroController) {
    return [
      _section("🏠 El ADN del Lugar"),
      _choice('estilo', ['Tradicional', 'Moderno', 'Minimalista', 'Industrial', 'Rústico', 'Elegante', 'Vintage', 'Mediterráneo'], data, onUpdate),
      _slider('nota_espacio', 'Nota del espacio (0-10)', 0, 10, data, onUpdate),
      
      _section("💡 Clima Sensorial"),
      _choice('luz', ['Muy oscura', 'Tenue', 'Cálida', 'Natural', 'Perfecta'], data, onUpdate),
      _slider('ruido', 'Nivel de ruido (Silencio -> Caos)', 0, 10, data, onUpdate),
      _choice('olor', ['No recuerdo', 'Cocina', 'Agradable', 'Intenso', 'Aroma característico'], data, onUpdate),
      
      _section("🎭 La Psicología del Restaurante"),
      _text('pelicula', 'Si fuera una película, ¿cuál sería?', onUpdate),
      _text('banda_sonora', '¿Qué banda sonora tendría?', onUpdate),
      _text('personalidad', 'Si fuera una persona, ¿quién sería?', onUpdate),
      
      _section("⏳ El Poder de Permanencia"),
      _choice('tiempo_espera', [
        'Me levanté al terminar', 
        'Un café y nos vamos', 
        'Una copa más', 
        'Se nos hizo de noche sin darnos cuenta', 
        'Podría vivir aquí'
      ], data, onUpdate),
      
      _section("🧼 Higiene y Detalles"),
      _choice('limpieza', ['Excelente', 'Muy buena', 'Correcta', 'Mejorable', 'Mala'], data, onUpdate),
      _choice('banos', ['No entré', 'Muy cuidados', 'Correctos', 'Mejorables', 'Muy sucios'], data, onUpdate),
      _slider('detalle', '¿Cuánta atención al detalle hay?', 0, 10, data, onUpdate),
    ];
  }

  // --- Widgets con estilo profesional ---
  Widget _section(String title) => Padding(padding: const EdgeInsets.only(top: 30, bottom: 15), child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigoAccent)));
  Widget _text(String key, String label, Function(String, dynamic) onUpdate) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(decoration: InputDecoration(labelText: label, border: OutlineInputBorder()), onChanged: (v) => onUpdate(key, v)));
  Widget _choice(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => Wrap(spacing: 8, runSpacing: 8, children: opts.map((o) => ChoiceChip(label: Text(o), selected: data[key] == o, onSelected: (s) => onUpdate(key, s ? o : null))).toList());
  Widget _slider(String key, String label, double min, double max, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), Slider(value: (data[key] ?? 0).toDouble(), min: min, max: max, divisions: 10, label: "${data[key]}", onChanged: (v) => onUpdate(key, v))]);
}