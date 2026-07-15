import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/data/categories.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/providers/memory_provider.dart';
import '../../core/models/memory_model.dart';
import '../../core/theme/components/app_dock.dart';
import '../../features/memory_form/widgets/smart_image.dart';
import '../../features/memory_form/widgets/media_selector_widget.dart';

class MemoryFormPage extends ConsumerStatefulWidget {
  final Category? initialCategory;
  final MemoryModel? memory;

  const MemoryFormPage({super.key, this.initialCategory, this.memory});

  @override
  ConsumerState<MemoryFormPage> createState() => _MemoryFormPageState();
}

class _MemoryFormPageState extends ConsumerState<MemoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantController = TextEditingController();
  final _locationController = TextEditingController();
  final _descController = TextEditingController();
  final _otroSaborController = TextEditingController();
  
  File? _tempMediaFile;
  bool _isVideo = false;
  bool _isSaving = false;
  
  bool _hasRated = false;
  bool? _wouldReturnState; 
  double _rating = 0.0; 
  
  late String _selectedCategory;
  Map<String, dynamic> _dynamicData = {};

  bool get _isEditing => widget.memory != null;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.memory?.category ?? widget.initialCategory?.name ?? gastronomicCategories.first.name;
    if (_isEditing) {
      final m = widget.memory!;
      _restaurantController.text = m.restaurantName;
      _locationController.text = m.location;
      _descController.text = m.specificFields['description'] ?? '';
      _wouldReturnState = m.wouldReturn;
      _rating = m.rating;
      _hasRated = true;
      _dynamicData = Map<String, dynamic>.from(m.specificFields);
      _otroSaborController.text = _dynamicData['otro_sabor'] ?? '';
    }
  }

  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    try {
      final XFile? pickedFile = isVideo 
          ? await picker.pickVideo(source: source, maxDuration: const Duration(seconds: 15))
          : await picker.pickImage(source: source, imageQuality: 80);
          
      if (pickedFile != null && mounted) {
        setState(() {
          _tempMediaFile = File(pickedFile.path);
          _isVideo = isVideo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al capturar medio: $e")));
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Hacer foto'), onTap: () { _pickMedia(ImageSource.camera, false); context.pop(); }),
            ListTile(leading: const Icon(Icons.videocam), title: const Text('Grabar vídeo'), onTap: () { _pickMedia(ImageSource.camera, true); context.pop(); }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Elegir de galería'), onTap: () { _pickMedia(ImageSource.gallery, false); context.pop(); }),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiChipGroup(String key, String label, List<String> options) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: options.map((option) {
              final List selectedItems = _dynamicData[key] is List ? List.from(_dynamicData[key]) : [];
              return FilterChip(
                label: Text(option),
                selected: selectedItems.contains(option),
                onSelected: (selected) {
                  setState(() {
                    if (selected) selectedItems.add(option);
                    else selectedItems.remove(option);
                    _dynamicData[key] = selectedItems;
                  });
                },
              );
            }).toList(),
          ),
          if (key == 'sabor' && (_dynamicData['sabor']?.contains('Otro') ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextFormField(
                controller: _otroSaborController,
                decoration: const InputDecoration(labelText: 'Especifica el sabor', border: OutlineInputBorder()),
                onChanged: (v) => _dynamicData['otro_sabor'] = v,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDynamicFields() {
    if (_selectedCategory == "Croquetas") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMultiChipGroup('sabor', '¿Qué ingredientes llevan?', ['Jamón', 'Cocido', 'Boletus', 'Cecina', 'Bacalao', 'Rabo de toro', 'Gamba', 'Queso', 'Pollo', 'Espinacas', 'Otro']),
          _buildMultiChipGroup('sensacion', '¿Qué sensaciones te dejaron?', ['😐 Meh', '🙂 Buenas', '🤤 Muy buenas', '🥹 Emocionantes', '🙏 Religiosas']),
          _buildMultiChipGroup('bechamel', 'La bechamel era...', ['Demasiado líquida', 'Muy cremosa', 'Equilibrada', 'Densa', 'Cemento armado']),
          _buildMultiChipGroup('rebozado', 'Prueba Chicote (Rebozado):', ['Muy fino', 'Crujiente perfecto', 'Sonido metálico', 'Desintegración', 'Aceitoso', 'Hormigón armado']),
          _buildMultiChipGroup('creatividad', 'Creatividad en la presentación:', ['Clásica', 'Original', 'Innovadora', 'Sorprendente', 'Decepcionante']),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(title: Text(_isEditing ? "Editar Recuerdo" : "Nuevo Recuerdo")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: "Categoría"),
              items: gastronomicCategories.map((cat) => DropdownMenuItem(value: cat.name, child: Text(cat.name))).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            TextFormField(
              controller: _restaurantController,
              decoration: const InputDecoration(labelText: '¿En qué restaurante?'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Ubicación'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _showMediaOptions,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                child: _tempMediaFile != null 
                    ? (_isVideo 
                        ? const Center(child: Icon(Icons.videocam, size: 60, color: Colors.blue))
                        : ClipRRect(borderRadius: BorderRadius.circular(12), child: SmartImage(imagePath: _tempMediaFile!.path)))
                    : (widget.memory?.imageUrls.isNotEmpty ?? false)
                        ? ClipRRect(borderRadius: BorderRadius.circular(12), child: SmartImage(imagePath: widget.memory!.imageUrls.first))
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 50, color: Colors.grey), Text("Añadir foto (opcional)")]),
              ),
            ),
            const SizedBox(height: 16),
            Text("Puntuación: ${_hasRated ? _rating.toStringAsFixed(1) : 'Pendiente'}", style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(value: _rating, min: 0, max: 10, divisions: 20, onChanged: (v) => setState(() { _rating = v; _hasRated = true; })),
            SwitchListTile(
              title: Text(_wouldReturnState == null ? "¿Volverías? (Selecciona)" : "Volverías: ${_wouldReturnState! ? 'Sí' : 'No'}"),
              value: _wouldReturnState ?? false,
              onChanged: (v) => setState(() => _wouldReturnState = v),
            ),
            _buildDynamicFields(),
            const SizedBox(height: 20),
            TextFormField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'Comentario general')),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isSaving ? null : _saveMemory,
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(_isEditing ? "Guardar Cambios" : "Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  void _saveMemory() async {
    // 1. Validar nombre restaurante
    if (_restaurantController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Falta el nombre del restaurante")));
      return;
    }
    // 2. Validar ubicación
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Falta la ubicación")));
      return;
    }
    // 3. Validar Puntuación
    if (!_hasRated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor, asigna una puntuación")));
      return;
    }
    // 4. Validar Volverías
    if (_wouldReturnState == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Indica si volverías al restaurante")));
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final updatedFields = Map<String, dynamic>.from(_dynamicData);
      updatedFields['description'] = _descController.text.trim();
      
      final newMemory = MemoryModel(
        id: widget.memory?.id ?? const Uuid().v4(),
        title: _restaurantController.text.trim(),
        restaurantName: _restaurantController.text.trim(),
        location: _locationController.text.trim(),
        wouldReturn: _wouldReturnState!,
        rating: _rating,
        imageUrls: _tempMediaFile != null && !_isVideo ? [_tempMediaFile!.path] : (widget.memory?.imageUrls ?? []),
        videoUrl: _tempMediaFile != null && _isVideo ? _tempMediaFile!.path : widget.memory?.videoUrl,
        date: widget.memory?.date ?? DateTime.now(),
        category: _selectedCategory,
        specificFields: updatedFields,
      );
      
      if (_isEditing) {
        ref.read(memoryProvider.notifier).updateMemory(newMemory);
      } else {
        ref.read(memoryProvider.notifier).addMemory(newMemory);
      }
      
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
      }
    }
  }

  @override
  void dispose() {
    _restaurantController.dispose();
    _locationController.dispose();
    _descController.dispose();
    _otroSaborController.dispose();
    super.dispose();
  }
}