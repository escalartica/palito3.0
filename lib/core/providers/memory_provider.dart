import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_data.dart';
import '../models/memory_model.dart';
import '../data/storage_service.dart';

class MemoryNotifier extends StateNotifier<List<MemoryModel>> {
  MemoryNotifier() : super([]) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final savedMemories = await StorageService.loadMemories();
    debugPrint("DEBUG: Memorias cargadas del storage: ${savedMemories.length}");
    
    // Si savedMemories viene vacía, carga mockMemories
    state = savedMemories.isNotEmpty ? savedMemories : mockMemories;
  }

  void addMemory(MemoryModel newMemory) {
    state = [...state, newMemory];
    StorageService.saveMemories(state);
  }

  void removeMemory(String id) {
    state = state.where((memory) => memory.id != id).toList();
    StorageService.saveMemories(state);
  }

  void updateMemory(MemoryModel updatedMemory) {
    state = state.map((m) => m.id == updatedMemory.id ? updatedMemory : m).toList();
    StorageService.saveMemories(state);
  }
}

final memoryProvider = StateNotifierProvider<MemoryNotifier, List<MemoryModel>>((ref) {
  return MemoryNotifier();
});

final selectedCategoryProvider = StateProvider<String>((ref) => "Todos");