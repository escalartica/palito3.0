import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../core/services/storage_image_service.dart';
import '../../core/providers/dock_provider.dart';
import '../../core/data/categories.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/providers/memory_provider.dart';
import '../../core/models/memory_model.dart';
import '../../features/memory_form/widgets/smart_image.dart';
import '../../core/factories/dynamic_field_factory.dart';
import 'package:palito_3_0/core/providers/memory_map_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryFormPage extends ConsumerStatefulWidget {
  final Category? initialCategory;
  final MemoryModel? memory;

  const MemoryFormPage({super.key, this.initialCategory, this.memory});

  @override
  ConsumerState<MemoryFormPage> createState() => _MemoryFormPageState();
}

class _MemoryFormPageState extends ConsumerState<MemoryFormPage>
    with TickerProviderStateMixin {
  final _restaurantController = TextEditingController();
  final _locationController = TextEditingController();
  final _descController = TextEditingController();
  final _otroSaborController = TextEditingController();

  XFile? _tempMediaFile;
  Uint8List? _tempMediaBytes;
  String? _existingImagePath;

  bool _isSaving = false;
  bool _isGettingLocation = false;
  bool? _wouldReturnState;
  double _rating = 0.0;

  late String _selectedCategory;

  Map<String, dynamic> _dynamicData = {};

  LocationData? _currentLocation;

  bool get _isEditing => widget.memory != null;

  // ============================================================
  // ANIMACIONES
  // ============================================================

  late final AnimationController _pageAnimationController;
  late final AnimationController _photoAnimationController;
  late final AnimationController _gpsAnimationController;
  late final AnimationController _saveAnimationController;
  late final AnimationController _ratingAnimationController;

  late final Animation<double> _pageFadeAnimation;
  late final Animation<Offset> _pageSlideAnimation;

  @override
  void initState() {
    super.initState();

    _pageAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _photoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _gpsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _saveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _ratingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _pageFadeAnimation = CurvedAnimation(
      parent: _pageAnimationController,
      curve: Curves.easeOutCubic,
    );

    _pageSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _pageAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    Future.microtask(() {
      if (mounted) {
        ref.read(dockVisibleProvider.notifier).state = false;
      }
    });

    _selectedCategory =
        widget.memory?.category ??
        widget.initialCategory?.name ??
        gastronomicCategories.first.name;

    if (_isEditing) {
      final m = widget.memory!;

      _restaurantController.text = m.restaurantName;

      _currentLocation = m.location;

      _locationController.text = m.location.address;

      _descController.text =
          m.specificFields['description']?.toString() ??
          m.specificFields['nota']?.toString() ??
          '';

      _wouldReturnState = m.wouldReturn;

      _rating = m.rating;

      _dynamicData = Map<String, dynamic>.from(m.specificFields);

      _otroSaborController.text = _dynamicData['otro_sabor']?.toString() ?? '';

      if (m.imageUrls.isNotEmpty) {
        _existingImagePath = m.imageUrls.first;
      }

      debugPrint('✏️ EDITANDO MEMORIA: ${m.id}');

      debugPrint(
        '📍 Coordenadas originales: '
        '${m.location.lat}, ${m.location.lng}',
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _pageAnimationController.dispose();
    _photoAnimationController.dispose();
    _gpsAnimationController.dispose();
    _saveAnimationController.dispose();
    _ratingAnimationController.dispose();

    _restaurantController.dispose();
    _locationController.dispose();
    _descController.dispose();
    _otroSaborController.dispose();

    super.dispose();
  }

  // ============================================================
  // UBICACIÓN GPS
  // ============================================================

  Future<void> _getCurrentLocation() async {
    if (_isGettingLocation) {
      return;
    }

    setState(() {
      _isGettingLocation = true;
    });

    _gpsAnimationController.repeat();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Activa la ubicación del dispositivo."),
            ),
          );
        }

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Permiso de ubicación no concedido.")),
          );
        }

        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final double lat = position.latitude;
      final double lng = position.longitude;

      String gpsAddress =
          "GPS: ${lat.toStringAsFixed(6)}, "
          "${lng.toStringAsFixed(6)}";

      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          final parts = <String>[];

          if (place.street != null && place.street!.trim().isNotEmpty) {
            parts.add(place.street!.trim());
          }

          if (place.locality != null && place.locality!.trim().isNotEmpty) {
            parts.add(place.locality!.trim());
          }

          if (place.administrativeArea != null &&
              place.administrativeArea!.trim().isNotEmpty &&
              !parts.contains(place.administrativeArea!.trim())) {
            parts.add(place.administrativeArea!.trim());
          }

          if (parts.isNotEmpty) {
            gpsAddress = parts.join(', ');
          }
        }
      } catch (e) {
        debugPrint('⚠️ No se pudo resolver dirección GPS: $e');
      }

      if (!mounted) return;

      setState(() {
        _currentLocation = LocationData(
          address: gpsAddress,
          lat: lat,
          lng: lng,
        );

        _locationController.text = gpsAddress;
      });

      debugPrint(
        '📍 GPS OBTENIDO: '
        'address=$gpsAddress, '
        'lat=$lat, '
        'lng=$lng',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ubicación GPS obtenida correctamente.")),
      );
    } catch (e, stack) {
      debugPrint('❌ Error obteniendo ubicación GPS: $e');

      debugPrintStack(stackTrace: stack);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error obteniendo ubicación GPS: $e")),
        );
      }
    } finally {
      _gpsAnimationController.stop();
      _gpsAnimationController.reset();

      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // IMÁGENES
  // ============================================================

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFDFBF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Seleccionar fotografía",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _buildImageSourceTile(
                  icon: Icons.camera_alt_rounded,
                  title: "Hacer una foto",
                  onTap: () {
                    Navigator.pop(context);
                    _pickMedia(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                _buildImageSourceTile(
                  icon: Icons.photo_library_rounded,
                  title: "Elegir de la galería",
                  onTap: () {
                    Navigator.pop(context);
                    _pickMedia(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD400),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0F172A), width: 2),
        ),
        child: Icon(icon, color: const Color(0xFF0F172A)),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A),
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickMedia(ImageSource source) async {
    final picker = ImagePicker();

    final XFile? pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile != null && mounted) {
      final bytes = await pickedFile.readAsBytes();

      if (!mounted) return;

      setState(() {
        _tempMediaFile = pickedFile;
        _tempMediaBytes = bytes;

        _existingImagePath = null;
      });

      _photoAnimationController.forward(from: 0);
    }
  }

  // ============================================================
  // GEOCODIFICACIÓN
  // ============================================================

  Future<LocationData?> _resolveAddressToLocation(String address) async {
    final cleanAddress = address.trim();

    if (cleanAddress.isEmpty) {
      return null;
    }

    final gpsRegex = RegExp(
      r'GPS:\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
      caseSensitive: false,
    );

    final gpsMatch = gpsRegex.firstMatch(cleanAddress);

    if (gpsMatch != null) {
      final lat = double.tryParse(gpsMatch.group(1) ?? '');

      final lng = double.tryParse(gpsMatch.group(2) ?? '');

      if (lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        return LocationData(address: cleanAddress, lat: lat, lng: lng);
      }
    }

    final queries = <String>[cleanAddress];

    if (!cleanAddress.toLowerCase().contains('españa') &&
        !cleanAddress.toLowerCase().contains('spain')) {
      queries.add('$cleanAddress, España');
    }

    if (cleanAddress.toLowerCase() == 'medellín' ||
        cleanAddress.toLowerCase() == 'medellin') {
      queries.insert(0, 'Medellín, Badajoz, España');
    }

    for (final query in queries) {
      try {
        debugPrint('🔎 Intentando geocodificar: "$query"');

        final locations = await locationFromAddress(query);

        if (locations.isNotEmpty) {
          final location = locations.first;

          final lat = location.latitude;
          final lng = location.longitude;

          if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
            debugPrint(
              '✅ Coordenadas encontradas para "$query": '
              '$lat, $lng',
            );

            return LocationData(address: cleanAddress, lat: lat, lng: lng);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Fallo geocodificando "$query": $e');
      }
    }

    debugPrint(
      '❌ No se pudieron obtener coordenadas para: '
      '"$cleanAddress"',
    );

    return null;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final generator = DynamicFieldFactory.getGenerator(_selectedCategory);

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: Text(
          _isEditing ? "Editar Recuerdo" : "Nuevo Recuerdo",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            fontSize: 22,
          ),
        ),
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
        centerTitle: true,
        leading: _buildAnimatedIconButton(
          icon: Icons.arrow_back,
          onTap: () => context.pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _pageFadeAnimation,
        child: SlideTransition(
          position: _pageSlideAnimation,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  40,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildAnimatedSection(
                      index: 0,
                      child: _buildCategorySection(),
                    ),
                    const SizedBox(height: 20),

                    _buildAnimatedSection(
                      index: 1,
                      child: _buildRestaurantSection(),
                    ),
                    const SizedBox(height: 20),

                    _buildAnimatedSection(
                      index: 2,
                      child: _buildLocationSection(),
                    ),
                    const SizedBox(height: 24),

                    _buildAnimatedSection(
                      index: 3,
                      child: _buildPhotoSection(),
                    ),
                    const SizedBox(height: 8),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: generator != null
                          ? KeyedSubtree(
                              key: ValueKey(_selectedCategory),
                              child: Column(
                                children: generator.buildFields(_dynamicData, (
                                  key,
                                  value,
                                ) {
                                  setState(() {
                                    _dynamicData[key] = value;
                                  });
                                }, _otroSaborController),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 8),

                    _buildAnimatedSection(
                      index: 4,
                      child: _buildRatingSection(),
                    ),
                    const SizedBox(height: 20),

                    _buildAnimatedSection(
                      index: 5,
                      child: _buildReturnSection(),
                    ),
                    const SizedBox(height: 20),

                    _buildAnimatedSection(
                      index: 6,
                      child: _buildDescriptionSection(),
                    ),
                    const SizedBox(height: 32),

                    _buildAnimatedSection(index: 7, child: _buildSaveButton()),

                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECCIONES
  // ============================================================

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("Categoría"),
        const SizedBox(height: 8),
        _buildNeoContainer(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
              items: gastronomicCategories.map((cat) {
                return DropdownMenuItem(value: cat.name, child: Text(cat.name));
              }).toList(),
              onChanged: (val) {
                if (val == null || val == _selectedCategory) {
                  return;
                }

                setState(() {
                  _selectedCategory = val;
                  _dynamicData.clear();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("Restaurante / Lugar"),
        const SizedBox(height: 8),
        _buildNeoContainer(
          child: TextField(
            controller: _restaurantController,
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            decoration: _inputDecoration("Ej. Taberna La Bulería"),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("Ubicación"),
        const SizedBox(height: 8),
        _buildNeoContainer(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _locationController,
                  onChanged: (_) {
                    if (_currentLocation != null) {
                      final currentText = _locationController.text.trim();

                      final savedAddress = _currentLocation!.address.trim();

                      if (currentText != savedAddress) {
                        setState(() {
                          _currentLocation = null;
                        });

                        debugPrint(
                          '📍 Coordenadas GPS '
                          'invalidadas porque cambió '
                          'la dirección.',
                        );
                      }
                    }
                  },
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  decoration: _inputDecoration(
                    "Escribe una ciudad o dirección",
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildGpsButton(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGpsButton() {
    return GestureDetector(
      onTap: _isGettingLocation ? null : _getCurrentLocation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _isGettingLocation
              ? const Color(0xFFFFE77A)
              : const Color(0xFFFFD400),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF0F172A), width: 2),
          boxShadow: _isGettingLocation
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: RotationTransition(
          turns: _gpsAnimationController,
          child: Icon(
            _isGettingLocation ? Icons.sync_rounded : Icons.my_location_rounded,
            color: const Color(0xFF0F172A),
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    final hasImage =
        _tempMediaFile != null ||
        (_existingImagePath != null && _existingImagePath!.isNotEmpty);

    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.0).animate(
          CurvedAnimation(
            parent: _photoAnimationController,
            curve: Curves.easeOutBack,
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAEB),
            border: Border.all(color: const Color(0xFF0F172A), width: 2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF0F172A),
                blurRadius: 0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_tempMediaBytes != null)
                  Image.memory(_tempMediaBytes!, fit: BoxFit.cover)
                else if (_existingImagePath != null &&
                    _existingImagePath!.isNotEmpty)
                  SmartImage(imagePath: _existingImagePath, fit: BoxFit.cover)
                else
                  _buildEmptyPhotoState(),

                if (hasImage)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: _buildChangePhotoBadge(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPhotoState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD400),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0F172A), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF0F172A),
                  blurRadius: 0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 24,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Añadir foto del plato o lugar",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildChangePhotoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD400),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0F172A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0F172A),
            blurRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit, size: 14, color: Color(0xFF0F172A)),
          const SizedBox(width: 6),
          Text(
            "Cambiar foto",
            style: GoogleFonts.outfit(
              color: const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("Puntuación general"),
        const SizedBox(height: 8),
        _buildNeoContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFF0F172A),
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: const Color(0xFFFFD400),
                    overlayColor: const Color(
                      0xFFFFD400,
                    ).withValues(alpha: 0.2),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: _rating,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    onChanged: (v) {
                      setState(() {
                        _rating = v;
                      });

                      _ratingAnimationController.forward(from: 0);
                    },
                  ),
                ),
              ),
              ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _ratingAnimationController,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD400),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0F172A),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    _rating.toStringAsFixed(1),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReturnSection() {
    final isSelected = _wouldReturnState == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("¿Volverías a este lugar?"),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFFAEB) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0F172A), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF0F172A),
                blurRadius: 0,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              "¿Volverías?",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
                fontSize: 14,
              ),
            ),
            value: _wouldReturnState ?? false,
            activeThumbColor: const Color(0xFFFFD400),
            onChanged: (v) {
              setState(() {
                _wouldReturnState = v;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("Nota personal"),
        const SizedBox(height: 8),
        _buildNeoContainer(
          child: TextField(
            controller: _descController,
            maxLines: 3,
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            decoration: _inputDecoration(
              "Escribe tus impresiones...",
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A),
            blurRadius: _isSaving ? 2 : 0,
            offset: _isSaving ? const Offset(0, 2) : const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSaving
              ? const Color(0xFFFFE77A)
              : const Color(0xFFFFD400),
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF0F172A), width: 2.5),
          ),
        ),
        onPressed: _isSaving ? null : _saveMemory,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isSaving
              ? Row(
                  key: const ValueKey('saving'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotationTransition(
                      turns: _saveAnimationController,
                      child: const Icon(Icons.sync_rounded, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Guardando...",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                )
              : Text(
                  _isEditing ? "Guardar Cambios" : "Guardar Recuerdo",
                  key: const ValueKey('idle'),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
        ),
      ),
    );
  }

  // ============================================================
  // COMPONENTES UI
  // ============================================================

  Widget _buildAnimatedSection({required int index, required Widget child}) {
    final delay = Duration(milliseconds: 50 * index);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildNeoContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0F172A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0F172A),
            blurRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAnimatedIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0F172A), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF0F172A), size: 16),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint, {
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: Colors.grey.shade400,
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
      border: InputBorder.none,
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF0F172A),
      ),
    );
  }

  // ============================================================
  // GUARDAR
  // ============================================================

  Future<void> _saveMemory() async {
    if (_restaurantController.text.trim().isEmpty) {
      _showError("Nombre de restaurante");
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      _showError("Ubicación");
      return;
    }

    if (_rating <= 0.0) {
      _showError("Puntuación");
      return;
    }

    if (_wouldReturnState == null) {
      _showError("¿Volverías?");
      return;
    }

    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    _saveAnimationController.repeat();

    try {
      // ========================================================
      // 0. ID (se genera antes para poder usarlo como carpeta de Storage)
      // ========================================================

      final memoryId = widget.memory?.id ?? const Uuid().v4();

      // ========================================================
      // 1. GUARDAR IMAGEN (Firebase Storage — visible en ambos móviles)
      // ========================================================

      List<String> finalImagePaths = List<String>.from(
        widget.memory?.imageUrls ?? <String>[],
      );

      if (_tempMediaBytes != null) {
        final downloadUrl = await StorageImageService.uploadMemoryImage(
          memoryId: memoryId,
          bytes: _tempMediaBytes!,
        );

        finalImagePaths = [downloadUrl];
      } else if (_existingImagePath != null && _existingImagePath!.isNotEmpty) {
        finalImagePaths = [_existingImagePath!];
      }

      // ========================================================
      // 2. RESOLVER UBICACIÓN
      // ========================================================

      final String addressText = _locationController.text.trim();

      LocationData? resolvedLocation;

      if (_currentLocation != null &&
          _currentLocation!.lat != null &&
          _currentLocation!.lng != null) {
        final currentLat = _currentLocation!.lat!;
        final currentLng = _currentLocation!.lng!;

        if (_currentLocation!.address.trim().toLowerCase() ==
            addressText.toLowerCase()) {
          resolvedLocation = LocationData(
            address: addressText,
            lat: currentLat,
            lng: currentLng,
          );

          debugPrint(
            '📍 Usando coordenadas GPS actuales: '
            '$currentLat, $currentLng',
          );
        }
      }

      if (resolvedLocation == null &&
          _isEditing &&
          widget.memory != null &&
          widget.memory!.location.lat != null &&
          widget.memory!.location.lng != null &&
          widget.memory!.location.address.trim().toLowerCase() ==
              addressText.toLowerCase()) {
        resolvedLocation = LocationData(
          address: addressText,
          lat: widget.memory!.location.lat,
          lng: widget.memory!.location.lng,
        );

        debugPrint(
          '📍 Conservando coordenadas anteriores: '
          '${resolvedLocation.lat}, '
          '${resolvedLocation.lng}',
        );
      }

      resolvedLocation ??= await _resolveAddressToLocation(addressText);

      if (resolvedLocation == null ||
          resolvedLocation.lat == null ||
          resolvedLocation.lng == null) {
        debugPrint(
          '❌ No se pudo obtener coordenadas '
          'para la ubicación "$addressText".',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "No se pudo localizar esta dirección. "
                "Usa el botón GPS o escribe una ciudad/dirección válida.",
              ),
            ),
          );
        }

        return;
      }

      final double lat = resolvedLocation.lat!;

      final double lng = resolvedLocation.lng!;

      debugPrint(
        '📍 UBICACIÓN FINAL VALIDADA: '
        'address=$addressText, '
        'lat=$lat, '
        'lng=$lng',
      );

      // ========================================================
      // 3. LOCATIONDATA FINAL
      // ========================================================

      final finalLocation = LocationData(
        address: addressText,
        lat: lat,
        lng: lng,
      );

      // ========================================================
      // 4. DATOS DINÁMICOS
      // ========================================================

      final Map<String, dynamic> finalDynamicData = Map<String, dynamic>.from(
        _dynamicData,
      );

      if (_descController.text.trim().isNotEmpty) {
        finalDynamicData['description'] = _descController.text.trim();
      } else {
        finalDynamicData.remove('description');
      }

      if (_otroSaborController.text.trim().isNotEmpty) {
        finalDynamicData['otro_sabor'] = _otroSaborController.text.trim();
      }

      // ========================================================
      // 6. MODELO FINAL
      // ========================================================

      final newMemory = MemoryModel(
        id: memoryId,
        title: _restaurantController.text.trim(),
        restaurantName: _restaurantController.text.trim(),
        location: finalLocation,
        wouldReturn: _wouldReturnState ?? false,
        rating: _rating,
        imageUrls: finalImagePaths,
        videoUrl: widget.memory?.videoUrl,
        date: widget.memory?.date ?? DateTime.now(),
        category: _selectedCategory,
        specificFields: finalDynamicData,
      );

      // ========================================================
      // 7. DATOS FIRESTORE
      // ========================================================

      final Map<String, dynamic> firestoreMemoryData =
          Map<String, dynamic>.from(newMemory.toJson());

      firestoreMemoryData['timestamp'] = FieldValue.serverTimestamp();

      firestoreMemoryData['location'] = {
        'address': addressText,
        'lat': lat,
        'lng': lng,
      };

      firestoreMemoryData['id'] = memoryId;

      debugPrint(
        '💾 FIRESTORE MEMORY DATA: '
        '$firestoreMemoryData',
      );

      // ========================================================
      // 8. GUARDAR EN PROVIDER LOCAL
      // ========================================================

      if (_isEditing) {
        ref.read(memoryProvider.notifier).updateMemory(newMemory);
      } else {
        ref.read(memoryProvider.notifier).addMemory(newMemory);
      }

      // ========================================================
      // 9. GUARDAR EN FIRESTORE
      // ========================================================

      final memoryMapService = ref.read(memoryMapServiceProvider);

      await memoryMapService.saveMemory(
        memoryId: memoryId,
        memoryData: firestoreMemoryData,
      );

      // ========================================================
      // 10. SINCRONIZAR COLLECTION LOCATIONS
      // ========================================================

      await memoryMapService.saveLocation(
        locationId: memoryId,
        locationData: {
          'memoryId': memoryId,
          'title': newMemory.title,
          'restaurantName': newMemory.restaurantName,
          'address': addressText,
          'lat': lat,
          'lng': lng,
          'category': _selectedCategory,
          'rating': _rating,
          'wouldReturn': _wouldReturnState ?? false,
        },
      );

      debugPrint('✅ RECUERDO GUARDADO COMPLETAMENTE');

      debugPrint(
        '🗺️ COORDENADAS DISPONIBLES PARA EL MAPA: '
        '$lat, $lng',
      );
    } catch (e, stack) {
      debugPrint('❌ Error guardando recuerdo: $e');

      debugPrintStack(stackTrace: stack);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error guardando el recuerdo: $e")),
        );
      }

      return;
    } finally {
      _saveAnimationController.stop();
      _saveAnimationController.reset();

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }

    if (mounted) {
      context.pop();
    }
  }

  // ============================================================
  // ERRORES
  // ============================================================

  void _showError(String field) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text("Por favor, completa: $field"),
      ),
    );
  }
}
