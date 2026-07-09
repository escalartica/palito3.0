import '../models/memory_model.dart';

final List<MemoryModel> mockMemories = [
  MemoryModel(
    id: '1',
    title: 'Sushi en Tokio',
    description: 'La mejor experiencia gastronómica de mi vida.',
    date: DateTime.now(),
  ),
  MemoryModel(
    id: '2',
    title: 'Pizza en Nápoles',
    description: 'Auténtica receta tradicional, increíble masa.',
    date: DateTime.now().subtract(const Duration(days: 1)),
  ),
];