import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/utils/image_saver.dart'; 
import '../../core/providers/dock_provider.dart'; 
import '../../core/data/categories.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/providers/memory_provider.dart';
import '../../core/models/memory_model.dart';
import '../../features/memory_form/widgets/smart_image.dart';
import '../../core/factories/dynamic_field_factory.dart';

class MemoryFormPage extends ConsumerStatefulWidget {
  final Category? initialCategory;
  final MemoryModel? memory;

  const MemoryFormPage({super.key, this.initialCategory, this.memory});

  @override
  ConsumerState<MemoryFormPage> createState() => _MemoryFormPageState();
}

class _MemoryFormPageState extends ConsumerState<MemoryFormPage> {
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
  LocationData? _currentLocation;

  bool get _isEditing => widget.memory != null;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dockVisibleProvider.notifier).state = false);
    _selectedCategory = widget.memory?.category ?? widget.initialCategory?.name ?? gastronomicCategories.first.name;
    if (_isEditing) {
      final m = widget.memory!;
      _restaurantController.text = m.restaurantName;
      _currentLocation = m.location;
      _locationController.text = m.location.address;
      _descController.text = m.specificFields['description'] ?? '';
      _wouldReturnState = m.wouldReturn;
      _rating = m.rating;
      _hasRated = true;
      _dynamicData = Map<String, dynamic>.from(m.specificFields);
      _otroSaborController.text = _dynamicData['otro_sabor'] ?? '';
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

  // Métodos de lógica (mantenidos igual para integridad)
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LocationData(address: "Ubicación actual guardada", lat: position.latitude, lng: position.longitude);
        _locationController.text = "Ubicación detectada";
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error GPS")));
    }
  }

  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    final XFile? pickedFile = isVideo 
        ? await picker.pickVideo(source: source, maxDuration: const Duration(seconds: 15))
        : await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null && mounted) setState(() { _tempMediaFile = File(pickedFile.path); _isVideo = isVideo; });
  }

  @override
  Widget build(BuildContext context) {
    final generator = DynamicFieldFactory.getGenerator(_selectedCategory);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(_isEditing ? "Editar" : "Nuevo Recuerdo", style: const TextStyle(fontWeight: FontWeight.w900)),
            backgroundColor: const Color(0xFFFFFDF5),
            foregroundColor: const Color(0xFF1A1A1A),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: "Categoría", border: OutlineInputBorder()),
                  items: gastronomicCategories.map((cat) => DropdownMenuItem(value: cat.name, child: Text(cat.name))).toList(),
                  onChanged: (val) => setState(() { _selectedCategory = val!; _dynamicData.clear(); }),
                ),
                const SizedBox(height: 16),
                TextField(controller: _restaurantController, decoration: const InputDecoration(labelText: 'Restaurante', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _pickMedia(ImageSource.gallery, false),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 2), borderRadius: BorderRadius.circular(12)),
                    child: _tempMediaFile != null 
                        ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_tempMediaFile!, fit: BoxFit.cover))
                        : const Icon(Icons.add_a_photo, size: 50),
                  ),
                ),
                if (generator != null) ...generator.buildFields(_dynamicData, (key, value) {
                  setState(() => _dynamicData[key] = value);
                }, _otroSaborController),
                const SizedBox(height: 20),
                Slider(value: _rating, min: 0, max: 10, divisions: 10, label: _rating.toString(), onChanged: (v) => setState(() { _rating = v; _hasRated = true; })),
                SwitchListTile(title: const Text("¿Volverías?"), value: _wouldReturnState ?? false, onChanged: (v) => setState(() => _wouldReturnState = v)),
                TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'Nota personal', border: OutlineInputBorder())),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD400), foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                  onPressed: _isSaving ? null : _saveMemory,
                  child: Text(_isEditing ? "Guardar Cambios" : "Guardar Recuerdo", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _saveMemory() async {
    setState(() => _isSaving = true);
    try {
      final newMemory = MemoryModel(
        id: widget.memory?.id ?? const Uuid().v4(),
        title: _restaurantController.text,
        restaurantName: _restaurantController.text,
        location: _currentLocation ?? LocationData(address: _locationController.text),
        wouldReturn: _wouldReturnState ?? false,
        rating: _rating,
        imageUrls: _tempMediaFile != null ? [_tempMediaFile!.path] : widget.memory?.imageUrls ?? [],
        date: DateTime.now(),
        category: _selectedCategory,
        specificFields: _dynamicData,
      );
      
      _isEditing ? ref.read(memoryProvider.notifier).updateMemory(newMemory) : ref.read(memoryProvider.notifier).addMemory(newMemory);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}