import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
// `show kDebugMode`: foundation exporta una clase `Category` (anotación de
// dartdoc) que choca con la `Category` de core/data/categories.dart.
import 'package:flutter/foundation.dart' show kDebugMode;
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
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/theme/tokens/app_animation.dart';

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
  final _dishController = TextEditingController();

  /// Para poder llevar al usuario hasta el campo que le falta
  /// aunque esté fuera de pantalla. Ver [_showError].
  final ScrollController _formScroll = ScrollController();

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

  /// Ya has confirmado que el 0 es a propósito. Se olvida en cuanto tocas el
  /// deslizador otra vez, porque entonces la puntuación vuelve a estar en
  /// duda.

  late String _selectedCategory;

  Map<String, dynamic> _dynamicData = {};

  LocationData? _currentLocation;

  bool get _isEditing => widget.memory != null;

  /// Cómo estaba el formulario al abrirlo. Ver [_hasUnsavedChanges].
  String _initialSignature = '';

  /// Todo lo que el usuario puede cambiar, en una sola cadena.
  ///
  /// Las claves de `_dynamicData` se ordenan a propósito: un `Map` de Dart
  /// conserva el orden de inserción, así que marcar dos chips en distinto
  /// orden daría dos cadenas distintas para el mismo contenido y el
  /// formulario se creería sucio sin serlo.
  String _currentSignature() {
    final List<String> dyn = _dynamicData.entries
        .map((MapEntry<String, dynamic> e) => '${e.key}=${e.value}')
        .toList()
      ..sort();
    return <String>[
      _selectedCategory,
      _restaurantController.text.trim(),
      _locationController.text.trim(),
      _descController.text.trim(),
      _otroSaborController.text.trim(),
      _dishController.text.trim(),
      _rating.toString(),
      _wouldReturnState.toString(),
      (_tempMediaBytes?.length ?? 0).toString(),
      dyn.join('&'),
    ].join('|');
  }

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
      duration: AppAnimation.slow,
    );

    _photoAnimationController = AnimationController(
      vsync: this,
      duration: AppAnimation.slow,
    );

    _gpsAnimationController = AnimationController(
      vsync: this,
      duration: AppAnimation.spinner,
    );

    _saveAnimationController = AnimationController(
      vsync: this,
      duration: AppAnimation.spinner,
    );

    _ratingAnimationController = AnimationController(
      vsync: this,
      duration: AppAnimation.slow,
    );

    _pageFadeAnimation = CurvedAnimation(
      parent: _pageAnimationController,
      curve: AppAnimation.enter,
    );

    _pageSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _pageAnimationController,
            curve: AppAnimation.enter,
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

      // Los recuerdos de antes tienen `title` == `restaurantName`, porque el
      // controlador copiaba uno en otro. En esos, el campo del plato sale
      // vacío en vez de repetir el nombre del bar.
      _dishController.text = m.title.trim() == m.restaurantName.trim()
          ? ''
          : m.title;

      if (m.imageUrls.isNotEmpty) {
        _existingImagePath = m.imageUrls.first;
      }

      _log('✏️ EDITANDO MEMORIA: ${m.id}');

      _log(
        '📍 Coordenadas originales: '
        '${m.location.lat}, ${m.location.lng}',
      );
    }

    // Huella de cómo llega el formulario, para poder saber después si el
    // usuario ha tocado algo. Se toma AQUÍ, justo tras rellenar: antes
    // estaría vacía y después ya tendría los cambios dentro.
    _initialSignature = _currentSignature();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageAnimationController.forward();
      }
    });
  }

  // ── "Reducir movimiento" ──
  //
  // Esta pantalla montaba su coreografía de entrada pasara lo que pasara.
  // Quien lleva activada esa opción del sistema —a menudo por vértigo o por
  // migraña— seguía viendo entrar los bloques uno detrás de otro.
  //
  // Va aquí y no en `initState` porque el `MediaQuery` todavía no existe en
  // ese momento; y se resuelve poniendo el controlador directamente en su
  // valor final, que es la pantalla ya montada, sin recorrido.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageAnimationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    // EL DOCK VUELVE.
    //
    // Al entrar se apaga (ver initState) para que la barra de pestañas no
    // tape el formulario. No volvía a encenderse nunca: al salir, quien
    // estaba en Inicio se quedaba sin barra hasta que hacía scroll hacia
    // arriba. Y en un diario vacío casi no hay nada que desplazar, así que
    // el usuario quedaba encerrado en Inicio, sin acceso a Mapa, Zona Gamer
    // ni Perfil. El comentario de main.dart ya describía este fallo.
    //
    // Va en `dispose` y no en el botón de atrás porque de aquí se sale por
    // cuatro sitios: la flecha, el gesto de deslizar, guardar, y el botón
    // del sistema. `dispose` es el único punto por el que pasan los cuatro.
    ref.read(dockVisibleProvider.notifier).state = true;

    _pageAnimationController.dispose();
    _photoAnimationController.dispose();
    _gpsAnimationController.dispose();
    _saveAnimationController.dispose();
    _ratingAnimationController.dispose();

    _restaurantController.dispose();
    _locationController.dispose();
    _descController.dispose();
    _otroSaborController.dispose();
    _dishController.dispose();
    _formScroll.dispose();

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

    // El giro del icono de GPS solo si el sistema no pide reducir el
    // movimiento; el estado de "buscando" lo comunica igual el texto.
    if (mounted && !MediaQuery.disableAnimationsOf(context)) {
      _gpsAnimationController.repeat();
    }

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
      // `mounted` ANTES de tocar el controlador, no después.
      //
      // `AnimationController.stop()` hace `_ticker!.stop()`. Si la pantalla
      // ya se cerró, `dispose()` dejó ese ticker en null: en debug salta un
      // assert, pero en una build de la App Store es un
      // "Null check operator used on a null value" — un cierre inesperado.
      //
      // El camino es de lo más normal: abres "Nuevo recuerdo", pulsas el
      // botón de ubicación y te vuelves atrás sin haber escrito nada (como
      // no hay cambios, la app te deja salir sin preguntar). En un local con
      // mala cobertura el GPS tarda varios segundos, y cuando por fin
      // responde, esto se ejecuta sobre un controlador ya liberado.
      if (mounted) {
        _gpsAnimationController.stop();
        _gpsAnimationController.reset();
      }

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
      // Por encima del dock (ver gamer_page.dart).
      useRootNavigator: true,
      backgroundColor: AppColors.background,
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
                    color: AppColors.textPrimary,
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
        // `context.mounted`, no `mounted`: el `context` que se usa aquí es el
        // parámetro de `build`, no el `State.context`. Comprobar el del State
        // no garantiza que ESTE siga siendo válido después del `await`, que
        // es justo lo que avisaba el analizador.
        if (discard && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _isEditing ? "Editar recuerdo" : "Nuevo recuerdo",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontSize: 22,
            ),
          ),
          backgroundColor: AppColors.background,
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
              controller: _formScroll,
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
                              // `context.mounted`, no `mounted`: aquí
                              // `context` es el parámetro de build(), no
                              // el del State.
                              if (ok != true || !context.mounted) return;
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

                      // Detrás del sitio y antes de la ubicación: primero
                      // dónde, luego qué. Es el orden en que se cuenta.
                      _buildAnimatedSection(
                        index: 1,
                        child: _buildDishSection(),
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
                        duration: AppAnimation.slow,
                        switchInCurve: AppAnimation.enter,
                        switchOutCurve: AppAnimation.exit,
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
                          hasInteracted: _hasInteractedWithRating,
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
                      // El botón de guardar ya no vive aquí: está fijo en
                      // la parte de abajo de la pantalla (ver
                      // `bottomNavigationBar`). Este hueco es el que ocupa,
                      // para que la última sección del formulario no quede
                      // debajo de él.
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ─────────────────────────────────────────────────────────────────
        // BARRA DE GUARDADO FIJA
        // ─────────────────────────────────────────────────────────────────
        //
        // El botón estaba al final de un formulario de ocho secciones: para
        // guardar había que recorrerlo entero hacia abajo, aunque solo
        // hubieras cambiado el nombre del sitio. Y al editar un recuerdo ya
        // existente era peor todavía — el usuario no tenía forma de saber, a
        // media pantalla, si sus cambios se estaban guardando solos o no.
        //
        // Ahora está siempre a la vista, sobre un fondo opaco con una línea
        // de separación para que no parezca que flota sobre el contenido.
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: BorderSide(color: Color(0x1A0F172A), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                12,
                AppSpacing.lg,
                12,
              ),
              child: _buildSaveButton(),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECCIONES
  // ============================================================

  /// ¿Qué comiste?
  ///
  /// El modelo siempre ha tenido `title` separado de `restaurantName`, y la
  /// ficha de detalle tiene una tarjeta "LUGAR" entera escrita y
  /// condicionada a que los dos sean distintos. No se pintaba nunca: el
  /// formulario solo preguntaba el sitio y el controlador copiaba ese texto
  /// a los dos campos. Por eso en el detalle salía "casa Esteban" como
  /// titular y otra vez "casa Esteban" justo debajo, como si fuera un fallo
  /// de dibujado.
  ///
  /// Con este campo la app pasa de ser una lista de nombres de bares a ser
  /// lo que dice ser: un diario de lo que comes. Es opcional a propósito —
  /// a veces lo que recuerdas es el sitio, no el plato— y cuando se deja en
  /// blanco todo sigue funcionando exactamente igual que antes.
  Widget _buildDishSection() {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionLabel("¿Qué probaste?"),
          const SizedBox(height: 8),
          NeoContainer(
            child: TextField(
              controller: _dishController,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              decoration: memoryFormInputDecoration(
                "Ej. croquetas de rabo de toro — opcional",
              ),
            ),
          ),
        ],
      ),
    );
  }

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
              color: AppColors.textPrimary,
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
                selectedColor: AppColors.primary,
                onTap: () => setState(() => _wouldReturnState = true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildReturnOption(
                label: "No",
                icon: Icons.cancel_rounded,
                isSelected: _wouldReturnState == false,
                selectedColor: AppColors.tintAccent,
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: AppAnimation.fast,
        curve: AppAnimation.enter,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.textPrimary,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: AppColors.textPrimary,
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.textPrimary,
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
              color: AppColors.textPrimary,
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
      duration: AppAnimation.standard,
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary,
            blurRadius: _isSaving ? 2 : 0,
            offset: _isSaving ? const Offset(0, 2) : const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          // Opaco (Color.lerp, no alpha): este botón puede quedar sobre
          // superficies distintas y una `withValues(alpha:)` dejaría
          // traslucir lo que hay detrás en vez de verse como un amarillo
          // apagado y sólido.
          backgroundColor: _isSaving
              ? Color.lerp(AppColors.primary, Colors.white, 0.45)
              : AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          // Sin esto, al deshabilitar el botón (onPressed: null mientras
          // se guarda) Material aplicaba su color de "disabled" por
          // defecto en vez del amarillo que se le pasaba arriba — el
          // botón se veía completamente oscuro y el texto "Guardando..."
          // ilegible sobre ese fondo.
          disabledBackgroundColor: Color.lerp(
            AppColors.primary,
            Colors.white,
            0.45,
          ),
          disabledForegroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: AppColors.textPrimary, width: 2.5),
          ),
        ),
        onPressed: _isSaving ? null : _saveMemory,
        child: AnimatedSwitcher(
          duration: AppAnimation.standard,
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
                  _isEditing ? "Guardar cambios" : "Guardar recuerdo",
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
      duration: AppAnimation.stagger(index, base: AppAnimation.slow),
      curve: AppAnimation.enter,
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
              border: Border.all(color: AppColors.textPrimary, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 16),
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
      _showError("Restaurante / Lugar", key: _restaurantSectionKey);
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      _showError("Ubicación", key: _locationSectionKey);
      return;
    }

    // El slider sigue en su valor inicial: probablemente se olvidó de
    // puntuar, no quiere dar un 0 a propósito. Esto sí es un error de campo
    // obligatorio y va con los demás.
    if (_rating <= 0.0 && !_hasInteractedWithRating) {
      _showError("Puntuación general", key: _ratingSectionKey);
      return;
    }

    if (_wouldReturnState == null) {
      _showError("¿Volverías a este lugar?", key: _wouldReturnSectionKey);
      return;
    }

    if (_isSaving) {
      return;
    }

    // ── Por qué ya no se pregunta nada sobre el 0 ──────────────────────
    //
    // Aquí había un diálogo: "has dejado la nota en 0, ¿seguro?". Era el
    // fallo nº2 que reportaron los usuarios de la App Store, y arreglar el
    // orden de las validaciones solo quitó el síntoma.
    //
    // La causa es que preguntaba a la persona equivocada. Arriba ya hay una
    // comprobación que distingue los dos casos:
    //
    //   • Deslizador sin tocar → "te falta la puntuación", como cualquier
    //     otro campo obligatorio, y te lleva hasta él.
    //   • Deslizador arrastrado hasta el 0 → eso es una decisión.
    //
    // Es decir: el diálogo solo le salía a quien había puesto un 0 **a
    // propósito**, para preguntarle si de verdad quería lo que acababa de
    // hacer. A veces se come uno algo horrible y quiere dejarlo escrito.
    // Ahora se guarda y ya está.

    setState(() {
      _isSaving = true;
    });

    if (!MediaQuery.disableAnimationsOf(context)) {
      _saveAnimationController.repeat();
    }

    try {
      final MemorySaveResult result = await MemorySaveController(ref).save(
        existingMemory: widget.memory,
        restaurantName: _restaurantController.text.trim(),
        dishName: _dishController.text.trim(),
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
                  // Ver home_page.dart: no hay ninguna "lista autorizada".
                  ? "Ya no tienes acceso a este diario. Puede que te hayan "
                        "quitado de él. Cambia de diario desde Inicio."
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
  /// ¿Hay algo escrito que se perdería al salir?
  ///
  /// Antes esto empezaba con `if (_isEditing) return false;`, así que
  /// **editar un recuerdo no protegía nada**: cambiabas la nota, escribías la
  /// opinión, hacías una foto nueva, deslizabas para volver, y se perdía todo
  /// sin un solo aviso. Crear sí preguntaba. La foto, que es lo que más
  /// cuesta recuperar, era justo lo que más se perdía.
  ///
  /// Ahora se compara con la huella tomada al abrir, así que funciona igual
  /// en los dos casos: al crear, la huella de partida es la de un formulario
  /// vacío; al editar, la del recuerdo guardado. Y como es una comparación y
  /// no una lista de "hay algo escrito", deshacer un cambio a mano vuelve a
  /// dejar el formulario limpio y no pregunta de más.
  bool get _hasUnsavedChanges => _currentSignature() != _initialSignature;

  /// Manejador del botón atrás. Síncrono a propósito: `_buildAnimatedIconButton`
  /// recibe un `VoidCallback`, y un closure `async` tiene tipo
  /// `Future<void> Function()`, que no es asignable.
  void _handleBackTap() {
    if (_isSaving) return;

    if (!_hasUnsavedChanges) {
      context.pop();
      return;
    }

    // async/await en vez de `.then`: dentro de un callback de `then` el
    // analizador no reconoce la guarda `mounted` del State y avisa de
    // use_build_context_synchronously.
    unawaited(_confirmDiscardAndPop());
  }

  Future<void> _confirmDiscardAndPop() async {
    final bool discard = await _confirmDiscard();
    if (!mounted) return;
    if (discard) context.pop();
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
        // El texto nombra el rótulo EXACTO que se ve en pantalla. Decía
        // "Por favor, completa: Nombre de restaurante" cuando el campo se
        // llama "Restaurante / Lugar": dos nombres para lo mismo obligan a
        // deducir cuál es. Y "Por favor, completa:" con dos puntos es una
        // cadena de programador, no una frase.
        content: Text('Para guardar, rellena «$field»'),
      ),
    );

    // Con 8-10 bloques de campos, el aviso solo por SnackBar obligaba a
    // buscar el campo a mano — ahora, si sabemos dónde está, hacemos
    // scroll automático hasta él.
    final BuildContext? fieldContext = key?.currentContext;

    if (fieldContext == null) {
      // El campo está tan arriba que ni siquiera se ha construido: el
      // formulario es un `CustomScrollView` y lo que queda fuera de
      // pantalla no existe todavía, así que `ensureVisible` no tiene a
      // dónde ir. Pasaba justo en el caso peor —pulsar "Guardar" desde
      // abajo del todo con el nombre del sitio sin rellenar— y el usuario
      // se quedaba leyendo un aviso sobre un campo que no veía.
      //
      // Los campos obligatorios están todos en la mitad de arriba y la
      // validación corta en el PRIMERO que falta, así que subir del todo
      // siempre deja a la vista el que se pide.
      if (_formScroll.hasClients) {
        _formScroll.animateTo(
          0,
          duration: AppAnimation.slow,
          curve: AppAnimation.enter,
        );
      }
      return;
    }

    {
      Scrollable.ensureVisible(
        fieldContext,
        duration: AppAnimation.slow,
        curve: AppAnimation.enter,
        alignment: 0.1,
      );
    }
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
