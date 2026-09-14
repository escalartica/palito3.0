import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../core/providers/dock_provider.dart';
import '../../core/data/categories.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/models/memory_model.dart';
import '../memory_form/factories/dynamic_field_factory.dart';
import '../../features/memory_form/widgets/category_section.dart';
import '../../features/memory_form/widgets/location_section.dart';
import '../../features/memory_form/widgets/photo_section.dart';
import '../../features/memory_form/widgets/rating_section.dart';
import '../../features/memory_form/widgets/dialog_helpers.dart';
import '../../features/memory_form/widgets/form_field_containers.dart';
import '../../features/memory_form/controllers/memory_save_controller.dart';

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

  // Claves para poder hacer scroll automático hasta el campo que falla
  // la validación al guardar — en un formulario largo, el aviso por
  // SnackBar solo no bastaba para que se supiera dónde estaba.
  final _restaurantSectionKey = GlobalKey();
  final _locationSectionKey = GlobalKey();
  final _ratingSectionKey = GlobalKey();
  final _wouldReturnSectionKey = GlobalKey();

  XFile? _tempMediaFile;
  Uint8List? _tempMediaBytes;
  String? _existingImagePath;

  bool _isSaving = false;
  bool _isGettingLocation = false;
  bool? _wouldReturnState;
  double _rating = 0.0;

  // Distingue "el usuario ha movido el slider" de "sigue en el valor
  // inicial sin tocar" — ambos casos pueden valer 0.0, pero solo el
  // primero es una puntuación de 0 deliberada.
  bool _hasInteractedWithRating = false;

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
      // Al editar, el valor ya viene de un recuerdo guardado (no es un
      // slider recién inicializado), así que cuenta como "ya decidido".
      _hasInteractedWithRating = true;

      _dynamicData = Map<String, dynamic>.from(m.specificFields);

      _otroSaborController.text = _dynamicData['otro_sabor']?.toString() ?? '';

      if (m.imageUrls.isNotEmpty) {
        _existingImagePath = m.imageUrls.first;
      }

      _log('✏️ EDITANDO MEMORIA: ${m.id}');

      _log(
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
        _log('⚠️ No se pudo resolver dirección GPS: $e');
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

      _log(
        '📍 GPS OBTENIDO: '
        'address=$gpsAddress, '
        'lat=$lat, '
        'lng=$lng',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ubicación GPS obtenida correctamente.")),
      );
    } catch (e, stack) {
      _log('❌ Error obteniendo ubicación GPS: $e');

      _logStack(stackTrace: stack);

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

  // Invalida las coordenadas GPS actuales si el usuario edita a mano el
  // texto de la dirección después de haberlas obtenido (ya no describen
  // el mismo lugar).
  void _handleLocationTextChanged(String _) {
    if (_currentLocation != null) {
      final currentText = _locationController.text.trim();

      final savedAddress = _currentLocation!.address.trim();

      if (currentText != savedAddress) {
        setState(() {
          _currentLocation = null;
        });

        _log(
          '📍 Coordenadas GPS '
          'invalidadas porque cambió '
          'la dirección.',
        );
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
                ImageSourceTile(
                  icon: Icons.camera_alt_rounded,
                  title: "Hacer una foto",
                  onTap: () {
                    Navigator.pop(context);
                    _pickMedia(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                ImageSourceTile(
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

  Future<void> _pickMedia(ImageSource source) async {
    final picker = ImagePicker();

    // No `final`: se asigna dentro del try y el análisis de asignación
    // definitiva de Dart es más frágil con variables finales ahí.
    XFile? pickedFile;

    try {
      pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        // Limita la resolución de subida: una foto de cámara moderna (10+
        // MP) no aporta nada extra en ninguna pantalla de la app, y el
        // preset "unsigned" de Cloudinary no tiene límite de tamaño propio
        // configurado — cuanto más grande el original, más rápido se
        // agota la cuota gratuita mensual.
        maxWidth: 1600,
      );
    } on PlatformException catch (e) {
      // `pickImage` lanza PlatformException cuando el usuario deniega el
      // acceso a la cámara o a Fotos. Sin capturarla, el selector se cerraba
      // y no pasaba nada: ni foto, ni mensaje, ni pista.
      if (!mounted) return;
      _showMessage(
        e.code.contains('denied')
            ? 'Palito no tiene permiso para usar '
                  '${source == ImageSource.camera ? 'la cámara' : 'tus fotos'}. '
                  'Puedes dárselo desde Ajustes.'
            : 'No se pudo abrir '
                  '${source == ImageSource.camera ? 'la cámara' : 'la galería'}.',
      );
      return;
    } catch (e, st) {
      _log('Error eligiendo foto: $e');
      _logStack(stackTrace: st);
      if (!mounted) return;
      _showMessage('No se pudo elegir la foto.');
      return;
    }

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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final generator = DynamicFieldFactory.getGenerator(_selectedCategory);

    return PopScope(
      // Sin esto, el botón atrás y el gesto de deslizar descartaban el
      // formulario entero sin preguntar: restaurante, ubicación, puntuación,
      // todos los chips y —lo peor— la foto ya hecha, que solo vivía en
      // memoria. En un restaurante, esa foto ya no se puede repetir.
      canPop: !_hasUnsavedChanges && !_isSaving,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (_isSaving) return;
        final bool discard = await _confirmDiscard();
        if (discard && mounted) context.pop();
      },
      child: Scaffold(
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
            tooltip: 'Volver',
            // Mientras se guarda, salir destruía el widget con la subida en
            // curso y el guardado se perdía a medio camino.
            onTap: _handleBackTap,
          ),
        ),
        body: FadeTransition(
          opacity: _pageFadeAnimation,
          child: SlideTransition(
            position: _pageSlideAnimation,
            child: CustomScrollView(
              // Arrastrar la lista cierra el teclado: en un formulario de ocho
              // secciones había que cerrarlo a mano entre campo y campo.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        child: CategorySection(
                          selectedCategory: _selectedCategory,
                          onCategoryChanged: (val) async {
                            if (val == _selectedCategory) return;

                            // Cambiar de categoría borra todos los chips ya
                            // rellenados. Antes ocurría sin avisar: un toque
                            // por error en el desplegable y se perdían seis
                            // grupos de respuestas.
                            if (_dynamicData.isNotEmpty ||
                                _otroSaborController.text.trim().isNotEmpty) {
                              final bool? ok = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext d) => AlertDialog(
                                  title: const Text('¿Cambiar de categoría?'),
                                  content: const Text(
                                    'Se borrarán las respuestas que ya has '
                                    'marcado para esta categoría.',
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, true),
                                      child: const Text('Cambiar'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true || !mounted) return;
                            }

                            setState(() {
                              _selectedCategory = val;
                              _dynamicData.clear();
                              // `_dynamicData.clear()` no tocaba este campo, así
                              // que el "otro sabor" escrito en Croquetas se
                              // colaba dentro de un recuerdo de otra categoría.
                              _otroSaborController.clear();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildAnimatedSection(
                        index: 1,
                        child: KeyedSubtree(
                          key: _restaurantSectionKey,
                          child: _buildRestaurantSection(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildAnimatedSection(
                        index: 2,
                        child: LocationSection(
                          key: _locationSectionKey,
                          controller: _locationController,
                          isGettingLocation: _isGettingLocation,
                          gpsAnimationController: _gpsAnimationController,
                          onGpsTap: _getCurrentLocation,
                          onAddressChanged: _handleLocationTextChanged,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildAnimatedSection(
                        index: 3,
                        child: PhotoSection(
                          onTap: _showImageSourceDialog,
                          photoAnimationController: _photoAnimationController,
                          tempMediaFile: _tempMediaFile,
                          tempMediaBytes: _tempMediaBytes,
                          existingImagePath: _existingImagePath,
                        ),
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
                                  children: generator.buildFields(
                                    _dynamicData,
                                    (key, value) {
                                      setState(() {
                                        _dynamicData[key] = value;
                                      });
                                    },
                                    _otroSaborController,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 8),

                      _buildAnimatedSection(
                        index: 4,
                        child: RatingSection(
                          key: _ratingSectionKey,
                          rating: _rating,
                          ratingAnimationController: _ratingAnimationController,
                          onChanged: (v) {
                            setState(() {
                              _rating = v;
                              _hasInteractedWithRating = true;
                            });

                            _ratingAnimationController.forward(from: 0);
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildAnimatedSection(
                        index: 5,
                        child: KeyedSubtree(
                          key: _wouldReturnSectionKey,
                          child: _buildReturnSection(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildAnimatedSection(
                        index: 6,
                        child: _buildDescriptionSection(),
                      ),
                      const SizedBox(height: 32),

                      _buildAnimatedSection(
                        index: 7,
                        child: _buildSaveButton(),
                      ),

                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECCIONES
  // ============================================================

  Widget _buildRestaurantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel("Restaurante / Lugar"),
        const SizedBox(height: 8),
        NeoContainer(
          child: TextField(
            controller: _restaurantController,
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            decoration: memoryFormInputDecoration("Ej. Taberna La Bulería"),
          ),
        ),
      ],
    );
  }

  // Antes era un Switch binario sobre un estado de 3 valores (sin
  // responder / sí / no): "sin responder" y "no" se veían exactamente
  // igual (el switch apagado), así que no había forma de saber si ya
  // habías contestado "No" o si simplemente no lo habías tocado. Con dos
  // botones explícitos, cada respuesta tiene su propio estado visual.
  Widget _buildReturnSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel("¿Volverías a este lugar?"),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildReturnOption(
                label: "Sí",
                icon: Icons.check_circle_rounded,
                isSelected: _wouldReturnState == true,
                selectedColor: const Color(0xFFFFD400),
                onTap: () => setState(() => _wouldReturnState = true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildReturnOption(
                label: "No",
                icon: Icons.cancel_rounded,
                isSelected: _wouldReturnState == false,
                selectedColor: const Color(0xFFFFCDBD),
                onTap: () => setState(() => _wouldReturnState = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReturnOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF0F172A),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0F172A)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: const Color(0xFF0F172A),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel("Nota personal"),
        const SizedBox(height: 8),
        NeoContainer(
          child: TextField(
            controller: _descController,
            maxLines: 3,
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            decoration: memoryFormInputDecoration(
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
          // Sin esto, al deshabilitar el botón (onPressed: null mientras
          // se guarda) Material aplicaba su color de "disabled" por
          // defecto en vez del amarillo que se le pasaba arriba — el
          // botón se veía completamente oscuro y el texto "Guardando..."
          // ilegible sobre ese fondo.
          disabledBackgroundColor: const Color(0xFFFFE77A),
          disabledForegroundColor: const Color(0xFF0F172A),
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

  Widget _buildAnimatedIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final Widget button = Padding(
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

    if (tooltip == null) {
      return button;
    }

    return Tooltip(message: tooltip, child: button);
  }

  // ============================================================
  // GUARDAR
  // ============================================================

  Future<void> _saveMemory() async {
    if (_restaurantController.text.trim().isEmpty) {
      _showError("Nombre de restaurante", key: _restaurantSectionKey);
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      _showError("Ubicación", key: _locationSectionKey);
      return;
    }

    if (_rating <= 0.0) {
      if (!_hasInteractedWithRating) {
        // El slider sigue en su valor inicial: probablemente se olvidó
        // de puntuar, no quiere dar un 0 a propósito.
        _showError("Puntuación", key: _ratingSectionKey);
        return;
      }

      // Sí ha movido el slider hasta 0: puede ser intencional (una
      // experiencia realmente mala), así que se confirma en vez de
      // bloquear o guardar sin preguntar.
      final bool confirmedZero = await _confirmZeroRating();
      if (!confirmedZero) return;
    }

    if (_wouldReturnState == null) {
      _showError("¿Volverías?", key: _wouldReturnSectionKey);
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
      final MemorySaveResult result = await MemorySaveController(ref).save(
        existingMemory: widget.memory,
        restaurantName: _restaurantController.text.trim(),
        addressText: _locationController.text.trim(),
        currentGpsLocation: _currentLocation,
        wouldReturn: _wouldReturnState ?? false,
        rating: _rating,
        tempMediaBytes: _tempMediaBytes,
        existingImagePath: _existingImagePath,
        category: _selectedCategory,
        dynamicData: _dynamicData,
        description: _descController.text.trim(),
        otroSabor: _otroSaborController.text.trim(),
      );

      if ((result.couldNotGeocode || result.couldNotUploadPhoto) && mounted) {
        final List<String> warnings = [
          if (result.couldNotUploadPhoto)
            "no se pudo subir la foto (revisa tu conexión y vuelve a "
                "intentarlo editando el recuerdo)",
          if (result.couldNotGeocode)
            "no se pudo localizar la dirección en el mapa (puedes "
                "corregirla luego con el botón GPS)",
        ];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Recuerdo guardado, pero ${warnings.join(' y ')}."),
          ),
        );
      }
    } catch (e, stack) {
      _log('❌ Error guardando recuerdo: $e');

      _logStack(stackTrace: stack);

      if (mounted) {
        // El detalle técnico ($e) ya queda en el log de arriba; al
        // usuario le sirve más un mensaje que pueda entender y que le
        // diga qué hacer. Un permission-denied de firestore.rules (p.
        // ej. tras reinstalar la app) no se arregla reintentando, así
        // que se distingue de un fallo de red genérico.
        final bool isPermissionDenied =
            e is FirebaseException && e.code == 'permission-denied';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPermissionDenied
                  ? "Este dispositivo no tiene acceso todavía. No es un "
                        "problema de conexión — avisa para añadirlo a la "
                        "lista autorizada."
                  : "No se pudo guardar el recuerdo. Comprueba tu conexión "
                        "e inténtalo de nuevo.",
            ),
          ),
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
  // DESCARTAR
  // ============================================================

  /// ¿Hay algo que se perdería al salir?
  bool get _hasUnsavedChanges {
    if (_isEditing) return false;
    return _tempMediaBytes != null ||
        _restaurantController.text.trim().isNotEmpty ||
        _locationController.text.trim().isNotEmpty ||
        _descController.text.trim().isNotEmpty ||
        _dynamicData.isNotEmpty ||
        _rating > 0;
  }

  /// Manejador del botón atrás. Síncrono a propósito: `_buildAnimatedIconButton`
  /// recibe un `VoidCallback`, y un closure `async` tiene tipo
  /// `Future<void> Function()`, que no es asignable.
  void _handleBackTap() {
    if (_isSaving) return;

    if (!_hasUnsavedChanges) {
      context.pop();
      return;
    }

    unawaited(
      _confirmDiscard().then((bool discard) {
        if (discard && mounted) context.pop();
      }),
    );
  }

  Future<bool> _confirmDiscard() async {
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('¿Descartar este recuerdo?'),
        content: const Text(
          'Se perderá lo que has escrito y la foto que hayas hecho.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    return discard == true;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ============================================================
  // ERRORES
  // ============================================================

  void _showError(String field, {GlobalKey? key}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text("Por favor, completa: $field"),
      ),
    );

    // Con 8-10 bloques de campos, el aviso solo por SnackBar obligaba a
    // buscar el campo a mano — ahora, si sabemos dónde está, hacemos
    // scroll automático hasta él.
    final BuildContext? fieldContext = key?.currentContext;

    if (fieldContext != null) {
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
  }

  Future<bool> _confirmZeroRating() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.55),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF0F172A), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF0F172A),
                blurRadius: 0,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6D6),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F172A), width: 2),
                ),
                child: const Icon(
                  Icons.star_border_rounded,
                  color: Color(0xFF0F172A),
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Guardar con puntuación 0?',
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Has dejado el slider en 0. Confirma que es la '
                'puntuación que quieres darle, no que se te ha '
                'olvidado moverlo.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: DialogButton(
                      label: 'Volver a puntuar',
                      backgroundColor: Colors.white,
                      onTap: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DialogButton(
                      label: 'Guardar con 0',
                      backgroundColor: const Color(0xFFFFD400),
                      onTap: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return confirmed ?? false;
  }
}

// ===========================================================================
// LOGS
// ===========================================================================
//
// `debugPrint` NO se desactiva en una build de release: sigue escribiendo al
// log del sistema (Console.app en iOS, logcat en Android), donde lo puede leer
// cualquiera con el dispositivo delante o un informe de diagnóstico. Este
// archivo estaba volcando ahí identificadores de usuario, de grupo y datos de
// ubicación. Con este envoltorio, en release no se escribe nada.
void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

void _logStack({StackTrace? stackTrace}) {
  if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
}
