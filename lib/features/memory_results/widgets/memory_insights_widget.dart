import 'package:flutter/material.dart';

class MemoryInsightsWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  const MemoryInsightsWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Joyas de la Experiencia",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),

        // Fila de datos creativos
        _insightTile(
          Icons.movie_filter,
          "Película",
          data['pelicula'] ?? "Sin definir",
        ),
        _insightTile(
          Icons.music_note,
          "Banda Sonora",
          data['banda_sonora'] ?? "Sin definir",
        ),
        _insightTile(
          Icons.person,
          "Personalidad",
          data['personalidad'] ?? "Sin definir",
        ),

        const SizedBox(height: 15),
        const Text(
          "Comentario General",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Text(
            data['comentario_general'] ?? "Sin comentarios adicionales.",
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _insightTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigoAccent, size: 20),
          const SizedBox(width: 10),
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}
