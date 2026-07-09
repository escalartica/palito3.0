class MemoryModel {
  final String id;
  final String title;
  final String description;
  final String? imageUrl; // Opcional, por si quieres poner fotos luego
  final DateTime date;

  MemoryModel({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.date,
  });
}