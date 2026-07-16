import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
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
  LocationData? _currentLocation;

  bool get _isEditing => widget.memory != null;

  @override
  void initState() {
    super.initState();
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

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      setState(() {
        _currentLocation = LocationData(address: "Lat: ${position.latitude}, Lng: ${position.longitude}", lat: position.latitude, lng: position.longitude);
        _locationController.text = _currentLocation!.address;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No se pudo obtener GPS: $e")));
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

  @override
  Widget build(BuildContext context) {
    final generator = DynamicFieldFactory.getGenerator(_selectedCategory);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      // Aseguramos que no haya bottomNavigationBar aquí para evitar que el AppDock se superponga
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
              onChanged: (val) => setState(() {
                _selectedCategory = val!;
                _dynamicData.clear();
              }),
            ),
            TextFormField(
              controller: _restaurantController,
              decoration: const InputDecoration(labelText: '¿En qué restaurante?'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Ubicación'),
                    onChanged: (val) => setState(() => _currentLocation = LocationData(address: val, lat: null, lng: null)),
                  ),
                ),
                IconButton(icon: const Icon(Icons.my_location), onPressed: _getCurrentLocation),
              ],
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
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 50, color: Colors.grey), Text("Añadir foto (opcional)")]),
              ),
            ),

            if (generator != null) ...generator.buildFields(_dynamicData, (key, value) {
              setState(() => _dynamicData[key] = value);
            }, _otroSaborController),
            
            const SizedBox(height: 30),
            const Divider(),
            
            Text("Puntuación: ${_hasRated ? _rating.toStringAsFixed(1) : 'Pendiente'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Slider(value: _rating, min: 0, max: 10, divisions: 20, onChanged: (v) => setState(() { _rating = v; _hasRated = true; })),
            SwitchListTile(
              title: Text(_wouldReturnState == null ? "¿Volverías?" : "Volverías: ${_wouldReturnState! ? 'Sí' : 'No'}"),
              value: _wouldReturnState ?? false,
              onChanged: (v) => setState(() => _wouldReturnState = v),
            ),
            
            TextFormField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'Comentario general')),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isSaving ? null : _saveMemory,
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(_isEditing ? "Guardar Cambios" : "Guardar"),
            ),
            const SizedBox(height: 50), // Padding extra al final para scroll fluido
          ],
        ),
      ),
    );
  }

  void _saveMemory() async {
    if (_restaurantController.text.trim().isEmpty || _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Completa nombre y ubicación")));
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
        location: _currentLocation ?? LocationData(address: _locationController.text.trim()),
        wouldReturn: _wouldReturnState ?? false,
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