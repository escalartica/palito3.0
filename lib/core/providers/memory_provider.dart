import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_data.dart';
import '../models/memory_model.dart';

class MemoryNotifier extends StateNotifier<List<MemoryModel>> {
  MemoryNotifier() : super(mockMemories); 

  // Método para añadir un recuerdo
  void addMemory({
    required String title, 
    required String description, 
    required String restaurantName, 
    String? imageUrl,
    String category = "General",
  }) {
    final newMemory = MemoryModel(
      id: DateTime.now().toString(),
      title: title,
      description: description,
      restaurantName: restaurantName,
      imageUrl: imageUrl,
      date: DateTime.now(),
      category: category,
    );
    
    state = [...state, newMemory];
  }

  // Método para eliminar un recuerdo por su ID
  void removeMemory(String id) {
    state = state.where((memory) => memory.id != id).toList();
  }

  // Método para actualizar un recuerdo existente
  void updateMemory({
    required String id,
    required String title,
    required String description,
    required String restaurantName,
    String? imageUrl,
    required String category,
  }) {
    state = state.map((m) => m.id == id ? MemoryModel(
      id: id,
      title: title,
      description: description,
      restaurantName: restaurantName,
      imageUrl: imageUrl,
      date: m.date, // Preservamos la fecha de creación original
      category: category,
    ) : m).toList();
  }
}

final memoryProvider = StateNotifierProvider<MemoryNotifier, List<MemoryModel>>((ref) {
  return MemoryNotifier();
});

// Provider para gestionar la categoría seleccionada en el filtro
final selectedCategoryProvider = StateProvider<String>((ref) => "Todos");