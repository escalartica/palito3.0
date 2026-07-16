import 'package:flutter/material.dart';
import '../../../../../../../core/factories/dynamic_field_factory.dart';

class EnsaladillaFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(Map<String, dynamic> data, Function(String, dynamic) onUpdate, TextEditingController otroController) {
    return [
      _section("🥔 La Patata"),
      _choice('estado_patata', ['Muy firme', 'Firme', 'Equilibrada', 'Cremosa', 'Puré'], data, onUpdate),
      _choice('corte_patata', ['Muy pequeño', 'Pequeño', 'Tradicional', 'Grande', 'Muy grande'], data, onUpdate),
      
      _section("🥄 La Mayonesa"),
      _choice('tipo_mayonesa', ['Casera', 'Casera espectacular', 'Industrial', 'No sé'], data, onUpdate),
      _choice('cantidad_mayo', ['Escasa', 'Justa', 'Muy cremosa', 'Excesiva'], data, onUpdate),
      _multi('sensacion_mayo', ['Sedosa', 'Ligera', 'Untuosa', 'Muy ácida', 'Dulzona', 'Pesada'], data, onUpdate),

      _section("🥚 El Huevo y 🐟 El Atún"),
      _choice('presencia_huevo', ['Mucho', 'Correcto', 'Poco', 'Inexistente'], data, onUpdate),
      _choice('integracion_huevo', ['Muy bien mezclado', 'En trozos', 'Solo decorativo'], data, onUpdate),
      _choice('calidad_atun', ['Excelente', 'Muy bueno', 'Correcto', 'Flojo', 'No llevaba'], data, onUpdate),

      _section("🫒 Extras"),
      _multi('extras', ['Aceitunas', 'Piparras', 'Anchoa', 'Ventresca', 'Gambas', 'Langostinos', 'Pulpo', 'Trufa', 'Huevas', 'Pepinillo', 'Pimiento'], data, onUpdate),

      _section("🥄 Primera Cucharada"),
      _choice('primer_bocado', ['Normalita', 'Muy buena', 'Ojo con esto', 'Necesito otra', 'De las mejores'], data, onUpdate),

      _section("⚖️ Equilibrio y Ajustes"),
      _choice('destaca_demasiado', ['Mayonesa', 'Patata', 'Huevo', 'Atún', 'Perfecta'], data, onUpdate),
      _multi('mejoras', ['Más mayo', 'Menos mayo', 'Más patata', 'Más atún', 'Más huevo', 'Menos sal'], data, onUpdate),

      _section("🏆 Premio Palito"),
      _dropdown('premio', ['Reina del vermut', 'Cucharada obligatoria', 'La de siempre', 'Sabor a verano', 'Una joya', 'Para recorrer kms', 'Nunca falla', 'Poca gloria'], data, onUpdate),

      _section("🎯 El último bocado"),
      _choice('ultimo_bocado', ['Lo dejé', 'Me dio igual', 'Me supo a poco', 'Rebañé el plato', 'Pedimos otra'], data, onUpdate),
    ];
  }

  // --- Widgets Auxiliares ---
  Widget _section(String title) => Padding(padding: const EdgeInsets.only(top: 25, bottom: 10), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)));
  
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