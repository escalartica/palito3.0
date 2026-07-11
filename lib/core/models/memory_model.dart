class MemoryModel {
  final String id;
  final String title;
  final String description;
  final String restaurantName;
  final String? imageUrl;
  final DateTime date;
  final String category;

  MemoryModel({
    required this.id,
    required this.title,
    required this.description,
    required this.restaurantName,
    this.imageUrl,
    required this.date,
    this.category = "General",
  });

  /// Determina si el recuerdo fue creado en los últimos 5 minutos.
  /// Esto nos sirve para el efecto de "Diario Vivo".
  bool get isRecent {
    final difference = DateTime.now().difference(date);
    return difference.inMinutes < 5;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'restaurantName': restaurantName,
      'imageUrl': imageUrl,
      'date': date.toIso8601String(),
      'category': category,
    };
  }

  // Corregido: añadido restaurantName aquí también
  MemoryModel copyWith({
    String? id,
    String? title,
    String? description,
    String? restaurantName,
    String? imageUrl,
    DateTime? date,
    String? category,
  }) {
    return MemoryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      restaurantName: restaurantName ?? this.restaurantName,
      imageUrl: imageUrl ?? this.imageUrl,
      date: date ?? this.date,
      category: category ?? this.category,
    );
  }
}