import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:path_provider/path_provider.dart';
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
  String? _existingImagePath; // Para cargar la imagen al editar
  bool _isSaving = false;
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
      _locationController.text = m.location.address ?? '';
      _descController.text = m.specificFields['description'] ?? '';
      _wouldReturnState = m.wouldReturn;
      _rating = m.rating;
      _dynamicData = Map<String, dynamic>.from(m.specificFields);
      _otroSaborController.text = _dynamicData['otro_sabor'] ?? '';
      
      // Cargamos la ruta de la imagen existente si existe
      if (m.imageUrls.isNotEmpty) {
        _existingImagePath = m.imageUrls.first;
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

  Future<String> _saveImagePermanently(File tempFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = "${const Uuid().v4()}.jpg";
    final savedImage = await tempFile.copy('${appDir.path}/$fileName');
    return savedImage.path;
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LocationData(address: "GPS: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}", lat: position.latitude, lng: position.longitude);
        _locationController.text = "${position.latitude}, ${position.longitude}";
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error obteniendo ubicación GPS")));
    }
  }

  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    final XFile? pickedFile = isVideo 
        ? await picker.pickVideo(source: source, maxDuration: const Duration(seconds: 15))
        : await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null && mounted) {
      setState(() { 
        _tempMediaFile = File(pickedFile.path);
        _existingImagePath = null; // Al elegir nueva, quitamos la anterior
      });
    }
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
                const Text("Ubicación", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Escribe una ciudad o dirección', border: OutlineInputBorder()))),
                    IconButton(icon: const Icon(Icons.my_location), onPressed: _getCurrentLocation),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _pickMedia(ImageSource.gallery, false),
                  child: Container(
                    height: 200, width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 2), borderRadius: BorderRadius.circular(12)),
                    // Lógica para mostrar imagen editada o nueva
                    child: _tempMediaFile != null 
                        ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_tempMediaFile!, fit: BoxFit.cover))
                        : (_existingImagePath != null 
                            ? ClipRRect(borderRadius: BorderRadius.circular(10), child: SmartImage(imagePath: _existingImagePath))
                            : const Icon(Icons.add_a_photo, size: 50)),
                  ),
                ),
                if (generator != null) ...generator.buildFields(_dynamicData, (key, value) {
                  setState(() => _dynamicData[key] = value);
                }, _otroSaborController),
                const SizedBox(height: 20),
                const Text("Puntuación", style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(value: _rating, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() { _rating = v; })),
                SwitchListTile(title: const Text("¿Volverías?"), value: _wouldReturnState ?? false, onChanged: (v) => setState(() => _wouldReturnState = v)),
                TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'Nota personal', border: OutlineInputBorder())),
                const SizedBox(height: 32),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFD400), foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                  onPressed: _isSaving ? null : _saveMemory,
                  child: Text(_isEditing ? "Guardar Cambios" : "Guardar Recuerdo"),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _saveMemory() async {
    if (_restaurantController.text.trim().isEmpty) { _showError("Nombre de restaurante"); return; }
    if (_locationController.text.trim().isEmpty) { _showError("Ubicación"); return; }
    if (_rating == 0.0) { _showError("Puntuación"); return; }
    if (_wouldReturnState == null) { _showError("¿Volverías?"); return; }

    setState(() => _isSaving = true);
    
    List<String> finalImagePaths = widget.memory?.imageUrls ?? [];
    if (_tempMediaFile != null) {
      final permanentPath = await _saveImagePermanently(_tempMediaFile!);
      finalImagePaths = [permanentPath];
    } else if (_existingImagePath != null) {
      finalImagePaths = [_existingImagePath!];
    }

    LocationData? finalLocation = _currentLocation;
    if (finalLocation == null && _locationController.text.isNotEmpty) {
      try {
        List<Location> locations = await locationFromAddress(_locationController.text);
        if (locations.isNotEmpty) {
          finalLocation = LocationData(address: _locationController.text, lat: locations.first.latitude, lng: locations.first.longitude);
        }
      } catch (e) {
        finalLocation = LocationData(address: _locationController.text);
      }
    }

    final newMemory = MemoryModel(
      id: widget.memory?.id ?? const Uuid().v4(),
      title: _restaurantController.text,
      restaurantName: _restaurantController.text,
      location: finalLocation ?? LocationData(address: _locationController.text),
      wouldReturn: _wouldReturnState ?? false,
      rating: _rating,
      imageUrls: finalImagePaths,
      date: DateTime.now(),
      category: _selectedCategory,
      specificFields: _dynamicData,
    );
    
    _isEditing ? ref.read(memoryProvider.notifier).updateMemory(newMemory) : ref.read(memoryProvider.notifier).addMemory(newMemory);
    if (mounted) context.pop();
  }

  void _showError(String field) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Por favor, completa: $field")));
  }
}