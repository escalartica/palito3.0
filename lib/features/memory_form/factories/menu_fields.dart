import 'package:flutter/material.dart';
import '../../../../../../../core/factories/dynamic_field_factory.dart';

class MenuFields implements DynamicFieldGenerator {
  @override
  List<Widget> buildFields(Map<String, dynamic> data, Function(String, dynamic) onUpdate, TextEditingController otroController) {
    return [
      _section("📋 Datos del Menú"),
      _text('nombre_menu', 'Nombre del Menú', onUpdate),
      _text('precio_menu', 'Precio por persona', onUpdate),
      _choice('tipo_menu', ['Menú del día', 'Degustación', 'Ejecutivo', 'Fin de semana', 'Festival'], data, onUpdate),
      
      _section("🎢 La Evolución del Viaje"),
      _choice('ritmo', ['Demasiado rápido', 'Algo acelerado', 'Perfecto', 'Se hizo largo', 'Eterno'], data, onUpdate),
      _choice('evolucion', ['Empezó fuerte, terminó flojo', 'Fue creciendo', 'Siempre arriba', 'Altibajos', 'El postre salvó todo'], data, onUpdate),
      
      _section("⚖️ Equilibrio y Coherencia"),
      _choice('coherencia', ['Sí, totalmente', 'Bastante', 'Platos sin relación'], data, onUpdate),
      _multi('demasiado_de', ['Carne', 'Pescado', 'Harinas', 'Fritos', 'Dulces', 'Equilibrado'], data, onUpdate),
      
      _section("🎭 Personalidad y Recuerdo"),
      _choice('personalidad', ['Tradicional', 'Creativo', 'Técnico', 'Divertido', 'Elegante', 'Atrevido'], data, onUpdate),
      _choice('momento_estrella', ['Aperitivo', 'Primer plato', 'Principal', 'Postre', 'Café'], data, onUpdate),
      
      _section("🧠 El Detector Palito"),
      _choice('pan_detector', ['Ninguno', 'Una vez', 'Dos veces', 'Perdí la cuenta'], data, onUpdate),
      _choice('pelea_plato', ['Pelea por el último bocado', 'Compartimos todo', 'Intercambio de platos', 'Nadie compartió'], data, onUpdate),
      
      _section("🎬 ¿Qué película vimos?"),
      _dropdown('pelicula', ['Ganaría un Oscar', 'Cine independiente', 'Un clásico', 'Mucho tráiler, poca peli', 'Éxito inesperado'], data, onUpdate),
      
      _section("😊 El Salida del Restaurante"),
      _choice('estado_final', ['Con ganas de volver', 'Pensando en un plato', 'Feliz y satisfecho', 'Con una buena historia', 'Solo siesta', 'Esperaba más'], data, onUpdate),
    ];
  }

  // --- Widgets reutilizables con estilo profesional ---
  Widget _section(String title) => Padding(padding: const EdgeInsets.only(top: 25, bottom: 10), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)));
  Widget _text(String key, String label, Function(String, dynamic) onUpdate) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextFormField(decoration: InputDecoration(labelText: label), onChanged: (v) => onUpdate(key, v)));
  Widget _choice(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => Wrap(spacing: 8, children: opts.map((o) => ChoiceChip(label: Text(o), selected: data[key] == o, onSelected: (s) => onUpdate(key, s ? o : null))).toList());
  Widget _multi(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => Wrap(spacing: 8, children: opts.map((o) { final list = (data[key] as List?) ?? []; return FilterChip(label: Text(o), selected: list.contains(o), onSelected: (s) { final l = List.from(list); s ? l.add(o) : l.remove(o); onUpdate(key, l); }); }).toList());
  Widget _dropdown(String key, List<String> opts, Map<String, dynamic> data, Function(String, dynamic) onUpdate) => DropdownButtonFormField(value: data[key], isExpanded: true, items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(), onChanged: (v) => onUpdate(key, v));
}