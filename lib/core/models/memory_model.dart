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
  final String title;
  final String restaurantName;
  final LocationData location;
  final bool wouldReturn;
  final double rating;
  final List<String> imageUrls;
  final String? videoUrl;
  final DateTime date;
  final String category;
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

  // Getter de conveniencia para obtener la ubicación limpia
  String get displayAddress {
    if (location.address.toLowerCase() == restaurantName.toLowerCase()) {
      return "Ubicación no especificada";
    }
    return location.address;
  }

  bool get isRecent {
    final difference = DateTime.now().difference(date);
    return difference.inMinutes < 5;
  }

  // Fábrica para reconstruir el objeto desde un Map (datos guardados)
  factory MemoryModel.fromMap(Map<String, dynamic> map) {
    return MemoryModel(
      id: map['id'] as String,
      title: map['title'] as String,
      restaurantName: map['restaurantName'] as String,
      location: LocationData.fromMap(map['location'] as Map<String, dynamic>),
      wouldReturn: map['wouldReturn'] as bool,
      rating: (map['rating'] as num).toDouble(),
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      videoUrl: map['videoUrl'] as String?,
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String,
      specificFields: Map<String, dynamic>.from(map['specificFields'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'restaurantName': restaurantName,
      'location': location.toMap(),
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