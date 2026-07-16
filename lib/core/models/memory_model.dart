class LocationData {
  final String address;
  final double? lat;
  final double? lng;

  LocationData({required this.address, this.lat, this.lng});

  Map<String, dynamic> toMap() => {
        'address': address,
        'lat': lat,
        'lng': lng,
      };

  factory LocationData.fromMap(Map<String, dynamic> map) => LocationData(
        address: map['address'] ?? '',
        lat: map['lat'] as double?,
        lng: map['lng'] as double?,
      );
}

class MemoryModel {
  final String id;
  // Campos comunes obligatorios
  final String title;
  final String restaurantName;
  final LocationData location; // Ahora es un objeto que contiene dirección y coordenadas
  final bool wouldReturn; // ¿Volverías?
  final double rating; // Puntuación 0.0 a 10.0
  final List<String> imageUrls; // Soporte para múltiples fotos
  final String? videoUrl; // Campo añadido para el video corto de cata
  final DateTime date;
  final String category;

  // Campo para campos dinámicos específicos de cada categoría
  final Map<String, dynamic> specificFields;

  MemoryModel({
    required this.id,
    required this.title,
    required this.restaurantName,
    required this.location,
    required this.wouldReturn,
    required this.rating,
    required this.imageUrls,
    this.videoUrl,
    required this.date,
    this.category = "General",
    this.specificFields = const {},
  });

  bool get isRecent {
    final difference = DateTime.now().difference(date);
    return difference.inMinutes < 5;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'restaurantName': restaurantName,
      'location': location.toMap(), // Guardamos como un mapa
      'wouldReturn': wouldReturn,
      'rating': rating,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'date': date.toIso8601String(),
      'category': category,
      'specificFields': specificFields,
    };
  }

  MemoryModel copyWith({
    String? id,
    String? title,
    String? restaurantName,
    LocationData? location,
    bool? wouldReturn,
    double? rating,
    List<String>? imageUrls,
    String? videoUrl,
    DateTime? date,
    String? category,
    Map<String, dynamic>? specificFields,
  }) {
    return MemoryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      restaurantName: restaurantName ?? this.restaurantName,
      location: location ?? this.location,
      wouldReturn: wouldReturn ?? this.wouldReturn,
      rating: rating ?? this.rating,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      date: date ?? this.date,
      category: category ?? this.category,
      specificFields: specificFields ?? this.specificFields,
    );
  }
}