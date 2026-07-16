import 'package:flutter/material.dart';
import '../../../core/factories/dynamic_field_factory.dart';

class TortillaFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(Map<String, dynamic> data, Function(String, dynamic) onUpdate, TextEditingController otroController) {
    return [
      _buildSectionTitle("🍳 Ingredientes"),
      _buildMultiChipGroup('ingredientes', ['Patata', 'Huevo', 'Cebolla', 'Trufa', 'Pimientos', 'Verduras', 'Jamón', 'Bacalao'], data, onUpdate),
      
      _buildSectionTitle("🌊 ¿Cómo estaba el interior?"),
      _buildChoiceGroup('interior', ['Muy cuajada', 'Cuajada', 'Equilibrada', 'Melosa', 'Muy líquida'], data, onUpdate),
      
      _buildSectionTitle("🥔 Corte de la patata"),
      _buildChoiceGroup('corte_patata', ['Muy fina', 'Fina', 'Dados', 'Gruesa', 'Irregular'], data, onUpdate),

      _buildSectionTitle("🧈 ¿Qué pasó al cortarla?"),
      _buildChoiceGroup('al_cortar', ['No salió nada', 'Muy poca crema', 'Salió ligeramente', 'Se desparramó', 'Fue pornografía gastronómica'], data, onUpdate),

      _buildSectionTitle("😍 Sensaciones"),
      _buildMultiChipGroup('sensaciones', ['Reconfortante', 'Sorprendente', 'Elegante', 'Casera', 'Valiente', 'Tradicional', 'Inolvidable', 'Decepcionante'], data, onUpdate),

      _buildSectionTitle("🎭 Personalidad: Esta tortilla es..."),
      _buildDropdownField('personalidad', [
        'La que haría tu abuela', 'Un bar de toda la vida', 'Una tortilla con ego', 
        'Una estrella Michelin disfrazada', 'Una tortilla que no entendí', 
        'Una que pediría otra vez sin mirar la carta', 'La tortilla del domingo', 'Para discutir media hora'
      ], data, onUpdate),

      _buildSectionTitle("🎯 Premio Palito"),
      _buildDropdownField('premio', [
        'La tortilla del barrio', 'Reina absoluta', 'Para cruzar la ciudad', 
        'Refugio emocional', 'Infravalorada', 'Siempre cumple', 'Más bonita que rica', 'Mucho ruido'
      ], data, onUpdate),

      _buildSectionTitle("💬 El titular"),
      _buildTextField('titular', 'Describe esta tortilla en una frase...', data, onUpdate),
    ];
  }

  // --- Helpers con Estilo Palito ---

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent)),
  );

  Widget _buildChoiceGroup(String key, List<String> options, Map<String, dynamic> data, Function(String, dynamic) onUpdate) {
    return Wrap(spacing: 8, children: options.map((o) => ChoiceChip(
      label: Text(o),
      selected: data[key] == o,
      onSelected: (s) => onUpdate(key, s ? o : null),
    )).toList());
  }

  Widget _buildMultiChipGroup(String key, List<String> options, Map<String, dynamic> data, Function(String, dynamic) onUpdate) {
    return Wrap(spacing: 8, children: options.map((o) {
      final list = (data[key] as List?) ?? [];
      return FilterChip(
        label: Text(o),
        selected: list.contains(o),
        onSelected: (s) {
          final l = List.from(list);
          s ? l.add(o) : l.remove(o);
          onUpdate(key, l);
        },
      );
    }).toList());
  }

  // Sustituye el método _buildDropdownField actual por este:
Widget _buildDropdownField(String key, List<String> options, Map<String, dynamic> data, Function(String, dynamic) onUpdate) {
  return DropdownButtonFormField<String>(
    initialValue: data[key],
    isExpanded: true, // <--- ESTO SOLUCIONA EL ERROR: Permite que el menú ocupe el ancho disponible
    items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
    onChanged: (v) => onUpdate(key, v),
    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
  );
}

  Widget _buildTextField(String key, String hint, Map<String, dynamic> data, Function(String, dynamic) onUpdate) {
    return TextFormField(
      initialValue: data[key],
      decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
      onChanged: (v) => onUpdate(key, v),
    );
  }
}