import '../models/memory_model.dart';

final List<MemoryModel> mockMemories = [
  MemoryModel(
    id: '1',
    title: 'Sushi en Tokio',
    restaurantName: 'Sushi Dai',
    location: LocationData(address: 'Tokio, Japón'), // Envuelto en LocationData
    wouldReturn: true,
    rating: 10.0,
    imageUrls: [],
    date: DateTime.now(),
    category: 'General',
    specificFields: {'description': 'La mejor experiencia gastronómica de mi vida.'},
  ),
  MemoryModel(
    id: '2',
    title: 'Pizza en Nápoles',
    restaurantName: 'L\'Antica Pizzeria da Michele',
    location: LocationData(address: 'Nápoles, Italia'), // Envuelto en LocationData
    wouldReturn: true,
    rating: 9.5,
    imageUrls: [],
    date: DateTime.now().subtract(const Duration(days: 1)),
    category: 'General',
    specificFields: {'description': 'Auténtica receta tradicional, increíble masa.'},
  ),
];