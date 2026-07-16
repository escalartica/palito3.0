import 'package:flutter/material.dart';
import '../../../core/factories/dynamic_field_factory.dart';

class CroquetasFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(
    Map<String, dynamic> data, 
    Function(String, dynamic) onUpdate,
    TextEditingController otroController,
  ) {
    return [
      _buildMultiChipGroup('sabor', '¿Qué ingredientes llevan?', 
          ['Jamón', 'Cocido', 'Boletus', 'Cecina', 'Bacalao', 'Rabo de toro', 'Gamba', 'Queso', 'Pollo', 'Espinacas', 'Otro'], data, onUpdate, otroController),
      _buildMultiChipGroup('sensacion', '¿Qué sensaciones te dejaron?', 
          ['😐 Meh', '🙂 Buenas', '🤤 Muy buenas', '🥹 Emocionantes', '🙏 Religiosas'], data, onUpdate, null),
      _buildMultiChipGroup('bechamel', 'La bechamel era...', 
          ['Demasiado líquida', 'Muy cremosa', 'Equilibrada', 'Densa', 'Cemento armado'], data, onUpdate, null),
      _buildMultiChipGroup('rebozado', 'Prueba Chicote (Rebozado):', 
          ['Muy fino', 'Crujiente perfecto', 'Sonido metálico', 'Desintegración', 'Aceitoso', 'Hormigón armado'], data, onUpdate, null),
      _buildMultiChipGroup('creatividad', 'Creatividad en la presentación:', 
          ['Clásica', 'Original', 'Innovadora', 'Sorprendente', 'Decepcionante'], data, onUpdate, null),
    ];
  }

  Widget _buildMultiChipGroup(
    String key, 
    String label, 
    List<String> options, 
    Map<String, dynamic> data, 
    Function(String, dynamic) onUpdate,
    TextEditingController? otroController,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: options.map((option) {
              final List selectedItems = data[key] is List ? List.from(data[key]) : [];
              return FilterChip(
                label: Text(option),
                selected: selectedItems.contains(option),
                onSelected: (selected) {
                  final newList = List.from(selectedItems);
                  if (selected) {
                    newList.add(option);
                  } else {
                    newList.remove(option);
                  }
                  onUpdate(key, newList);
                },
              );
            }).toList(),
          ),
          if (key == 'sabor' && (data['sabor']?.contains('Otro') ?? false) && otroController != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextFormField(
                controller: otroController,
                decoration: const InputDecoration(labelText: 'Especifica el sabor', border: OutlineInputBorder()),
                onChanged: (v) => onUpdate('otro_sabor', v),
              ),
            ),
        ],
      ),
    );
  }
}