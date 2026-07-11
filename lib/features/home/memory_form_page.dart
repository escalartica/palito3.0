import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/data/categories.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/theme/tokens/app_typography.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/providers/memory_provider.dart';
import '../../core/models/memory_model.dart';

class MemoryFormPage extends ConsumerStatefulWidget {
  final Category? initialCategory;
  final MemoryModel? memory;

  const MemoryFormPage({super.key, this.initialCategory, this.memory});

  @override
  ConsumerState<MemoryFormPage> createState() => _MemoryFormPageState();
}

class _MemoryFormPageState extends ConsumerState<MemoryFormPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _restaurantController = TextEditingController();
  final _imageUrlController = TextEditingController();
  
  late String _selectedCategory;
  bool get _isEditing => widget.memory != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.memory!.title;
      _descController.text = widget.memory!.description;
      _restaurantController.text = widget.memory!.restaurantName;
      _imageUrlController.text = widget.memory!.imageUrl ?? '';
      _selectedCategory = widget.memory!.category;
    } else {
      _selectedCategory = widget.initialCategory?.name ?? "General";
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _restaurantController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: Text(_isEditing ? "Editar Recuerdo" : "Nuevo Recuerdo", style: AppTypography.headlineMedium),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '¿Qué hemos comido?'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _restaurantController,
              decoration: const InputDecoration(labelText: '¿Dónde?'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'URL de la imagen (opcional)',
                hintText: 'Pega aquí el enlace a tu foto',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Campo de descripción optimizado con diseño de caja
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: '¿Qué nos ha parecido?',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2C3E50), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              title: Text("Categoría: $_selectedCategory"),
              leading: const Icon(Icons.category_rounded),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2C3E50)),
                onPressed: () {
                  if (_isEditing) {
                    ref.read(memoryProvider.notifier).updateMemory(
                          id: widget.memory!.id,
                          title: _titleController.text,
                          description: _descController.text,
                          restaurantName: _restaurantController.text,
                          imageUrl: _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
                          category: _selectedCategory,
                        );
                  } else {
                    ref.read(memoryProvider.notifier).addMemory(
                          title: _titleController.text,
                          description: _descController.text,
                          restaurantName: _restaurantController.text,
                          imageUrl: _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
                          category: _selectedCategory,
                        );
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_isEditing ? "¡Recuerdo actualizado! 🍴✨" : "¡Recuerdo guardado con éxito! 🍴✨")),
                  );
                  
                  context.pop();
                },
                child: Text(_isEditing ? "Guardar Cambios" : "Guardar Recuerdo"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}