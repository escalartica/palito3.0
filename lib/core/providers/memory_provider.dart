import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_data.dart';
import '../models/memory_model.dart';

class MemoryNotifier extends StateNotifier<List<MemoryModel>> {
  MemoryNotifier() : super(mockMemories); 

  // Método para añadir un recuerdo recibiendo el modelo completo
  // Este método recibe el MemoryModel que contiene los campos comunes
  // y el mapa 'specificFields' con los datos dinámicos (croquetas, tortilla, etc.)
  void addMemory(MemoryModel newMemory) {
    state = [...state, newMemory];
  }

  // Método para eliminar un recuerdo por su ID
  void removeMemory(String id) {
    state = state.where((memory) => memory.id != id).toList();
  }

  // Método para actualizar un recuerdo existente recibiendo el modelo completo
  // El modelo actualizado incluye el mapa 'specificFields' modificado
  void updateMemory(MemoryModel updatedMemory) {
    state = state.map((m) => m.id == updatedMemory.id ? updatedMemory : m).toList();
  }
}

final memoryProvider = StateNotifierProvider<MemoryNotifier, List<MemoryModel>>((ref) {
  return MemoryNotifier();
});

// Provider para gestionar la categoría seleccionada en el filtro
final selectedCategoryProvider = StateProvider<String>((ref) => "Todos");