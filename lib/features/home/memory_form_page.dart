import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../core/utils/image_saver.dart';
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

const MemoryFormPage({
super.key,
this.initialCategory,
this.memory,
});

@override
ConsumerState<MemoryFormPage> createState() =>
_MemoryFormPageState();
}

class _MemoryFormPageState
extends ConsumerState<MemoryFormPage> {
final _restaurantController = TextEditingController();
final _locationController = TextEditingController();
final _descController = TextEditingController();
final _otroSaborController = TextEditingController();

File? _tempMediaFile;
String? _existingImagePath;

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


Future.microtask(() {
  if (mounted) {
    ref.read(dockVisibleProvider.notifier).state = false;
  }
});

_selectedCategory = widget.memory?.category ??
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

  _dynamicData =
      Map<String, dynamic>.from(m.specificFields);

  _otroSaborController.text =
      _dynamicData['otro_sabor']?.toString() ?? '';

  if (m.imageUrls.isNotEmpty) {
    _existingImagePath = m.imageUrls.first;
  }

  debugPrint(
    '✏️ EDITANDO MEMORIA: ${m.id}',
  );

  debugPrint(
    '📍 Coordenadas originales: '
    '${m.location.lat}, ${m.location.lng}',
  );
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

// ============================================================
// UBICACIÓN GPS
// ============================================================

Future<void> _getCurrentLocation() async {
try {
final serviceEnabled =
await Geolocator.isLocationServiceEnabled();


  if (!serviceEnabled) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Activa la ubicación del dispositivo.",
          ),
        ),
      );
    }

    return;
  }

  LocationPermission permission =
      await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission =
        await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Permiso de ubicación no concedido.",
          ),
        ),
      );
    }

    return;
  }

  final Position position =
      await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
    ),
  );

  final double lat = position.latitude;
  final double lng = position.longitude;

  String gpsAddress =
      "GPS: ${lat.toStringAsFixed(6)}, "
      "${lng.toStringAsFixed(6)}";

  // Intentamos obtener una dirección legible.
  try {
    final placemarks =
        await placemarkFromCoordinates(
      lat,
      lng,
    );

    if (placemarks.isNotEmpty) {
      final place = placemarks.first;

      final parts = <String>[];

      if (place.street != null &&
          place.street!.trim().isNotEmpty) {
        parts.add(place.street!.trim());
      }

      if (place.locality != null &&
          place.locality!.trim().isNotEmpty) {
        parts.add(place.locality!.trim());
      }

      if (place.administrativeArea != null &&
          place.administrativeArea!.trim().isNotEmpty &&
          !parts.contains(
            place.administrativeArea!.trim(),
          )) {
        parts.add(
          place.administrativeArea!.trim(),
        );
      }

      if (parts.isNotEmpty) {
        gpsAddress = parts.join(', ');
      }
    }
  } catch (e) {
    debugPrint(
      '⚠️ No se pudo resolver dirección GPS: $e',
    );
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
    const SnackBar(
      content: Text(
        "Ubicación GPS obtenida correctamente.",
      ),
    ),
  );
} catch (e, stack) {
  debugPrint(
    '❌ Error obteniendo ubicación GPS: $e',
  );

  debugPrintStack(
    stackTrace: stack,
  );

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Error obteniendo ubicación GPS: $e",
        ),
      ),
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
borderRadius: BorderRadius.vertical(
top: Radius.circular(24),
),
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
ListTile(
leading: Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: const Color(0xFFFFD400),
shape: BoxShape.circle,
border: Border.all(
color: const Color(0xFF0F172A),
width: 2,
),
),
child: const Icon(
Icons.camera_alt_rounded,
color: Color(0xFF0F172A),
),
),
title: Text(
"Hacer una foto",
style: GoogleFonts.inter(
fontWeight: FontWeight.bold,
color: const Color(0xFF0F172A),
),
),
onTap: () {
Navigator.pop(context);
_pickMedia(ImageSource.camera);
},
),
const SizedBox(height: 8),
ListTile(
leading: Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: const Color(0xFFFFD400),
shape: BoxShape.circle,
border: Border.all(
color: const Color(0xFF0F172A),
width: 2,
),
),
child: const Icon(
Icons.photo_library_rounded,
color: Color(0xFF0F172A),
),
),
title: Text(
"Elegir de la galería",
style: GoogleFonts.inter(
fontWeight: FontWeight.bold,
color: const Color(0xFF0F172A),
),
),
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

Future<void> _pickMedia(
ImageSource source,
) async {
final picker = ImagePicker();


final XFile? pickedFile =
    await picker.pickImage(
  source: source,
  imageQuality: 80,
);

if (pickedFile != null && mounted) {
  setState(() {
    _tempMediaFile =
        File(pickedFile.path);

    _existingImagePath = null;
  });
}


}

// ============================================================
// GEOCODIFICACIÓN
// ============================================================

Future<LocationData?> _resolveAddressToLocation(
String address,
) async {
final cleanAddress = address.trim();


if (cleanAddress.isEmpty) {
  return null;
}

// ----------------------------------------------------------
// 1. Si el texto es GPS, intentamos extraer las coordenadas.
// ----------------------------------------------------------

final gpsRegex = RegExp(
  r'GPS:\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
  caseSensitive: false,
);

final gpsMatch = gpsRegex.firstMatch(
  cleanAddress,
);

if (gpsMatch != null) {
  final lat = double.tryParse(
    gpsMatch.group(1) ?? '',
  );

  final lng = double.tryParse(
    gpsMatch.group(2) ?? '',
  );

  if (lat != null &&
      lng != null &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180) {
    return LocationData(
      address: cleanAddress,
      lat: lat,
      lng: lng,
    );
  }
}

// ----------------------------------------------------------
// 2. Primera búsqueda exacta.
// ----------------------------------------------------------

final queries = <String>[
  cleanAddress,
];

// ----------------------------------------------------------
// 3. Segunda búsqueda añadiendo España.
// ----------------------------------------------------------

if (!cleanAddress.toLowerCase().contains('españa') &&
    !cleanAddress.toLowerCase().contains('spain')) {
  queries.add(
    '$cleanAddress, España',
  );
}

// ----------------------------------------------------------
// 4. Caso especial Medellín.
// ----------------------------------------------------------

if (cleanAddress.toLowerCase() == 'medellín' ||
    cleanAddress.toLowerCase() == 'medellin') {
  queries.insert(
    0,
    'Medellín, Badajoz, España',
  );
}

for (final query in queries) {
  try {
    debugPrint(
      '🔎 Intentando geocodificar: "$query"',
    );

    final locations =
        await locationFromAddress(query);

    if (locations.isNotEmpty) {
      final location = locations.first;

      final lat = location.latitude;
      final lng = location.longitude;

      if (lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        debugPrint(
          '✅ Coordenadas encontradas para "$query": '
          '$lat, $lng',
        );

        return LocationData(
          address: cleanAddress,
          lat: lat,
          lng: lng,
        );
      }
    }
  } catch (e) {
    debugPrint(
      '⚠️ Fallo geocodificando "$query": $e',
    );
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
final generator =
DynamicFieldFactory.getGenerator(
_selectedCategory,
);

return Scaffold(
  backgroundColor: const Color(0xFFFDFBF7),
  appBar: AppBar(
    title: Text(
      _isEditing
          ? "Editar Recuerdo"
          : "Nuevo Recuerdo",
      style: GoogleFonts.outfit(
        fontWeight: FontWeight.w900,
        color: const Color(0xFF0F172A),
        fontSize: 22,
      ),
    ),
    backgroundColor:
        const Color(0xFFFDFBF7),
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      onPressed: () => context.pop(),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF0F172A),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back,
          color: Color(0xFF0F172A),
          size: 16,
        ),
      ),
    ),
  ),
  body: CustomScrollView(
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
            _buildSectionLabel(
              "Categoría",
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF0F172A),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child:
                  DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor:
                      Colors.white,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        const Color(0xFF0F172A),
                  ),
                  items:
                      gastronomicCategories
                          .map(
                    (cat) =>
                        DropdownMenuItem(
                      value: cat.name,
                      child:
                          Text(cat.name),
                    ),
                  ).toList(),
                  onChanged: (val) {
                    if (val == null) {
                      return;
                    }

                    setState(() {
                      _selectedCategory =
                          val;
                      _dynamicData.clear();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionLabel(
              "Restaurante / Lugar",
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color:
                      const Color(0xFF0F172A),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color:
                        Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller:
                    _restaurantController,
                style: GoogleFonts.inter(
                  color:
                      const Color(0xFF0F172A),
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 14,
                ),
                decoration:
                    InputDecoration(
                  hintText:
                      "Ej. Taberna La Bulería",
                  hintStyle:
                      GoogleFonts.inter(
                    color:
                        Colors.grey.shade400,
                    fontWeight:
                        FontWeight.w400,
                    fontSize: 14,
                  ),
                  border:
                      InputBorder.none,
                  contentPadding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionLabel(
              "Ubicación",
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color:
                      const Color(0xFF0F172A),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color:
                        Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          _locationController,
                      onChanged: (_) {
                        if (_currentLocation !=
                            null) {
                          final currentText =
                              _locationController
                                  .text
                                  .trim();

                          final savedAddress =
                              _currentLocation!
                                  .address
                                  .trim();

                          if (currentText !=
                              savedAddress) {
                            setState(() {
                              _currentLocation =
                                  null;
                            });

                            debugPrint(
                              '📍 Coordenadas GPS '
                              'invalidadas porque cambió '
                              'la dirección.',
                            );
                          }
                        }
                      },
                      style:
                          GoogleFonts.inter(
                        color:
                            const Color(
                                0xFF0F172A),
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 14,
                      ),
                      decoration:
                          InputDecoration(
                        hintText:
                            "Escribe una ciudad o dirección",
                        hintStyle:
                            GoogleFonts.inter(
                          color: Colors
                              .grey.shade400,
                          fontWeight:
                              FontWeight.w400,
                          fontSize: 14,
                        ),
                        border:
                            InputBorder.none,
                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      right: 8.0,
                    ),
                    child: InkWell(
                      onTap:
                          _getCurrentLocation,
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                      child: Container(
                        padding:
                            const EdgeInsets
                                .all(8),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                                  0xFFFFD400),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                          border: Border.all(
                            color:
                                const Color(
                                    0xFF0F172A),
                            width: 2,
                          ),
                        ),
                        child:
                            const Icon(
                          Icons
                              .my_location_rounded,
                          color:
                              Color(0xFF0F172A),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            InkWell(
              onTap:
                  _showImageSourceDialog,
              borderRadius:
                  BorderRadius.circular(16),
              child: Container(
                height: 180,
                width: double.infinity,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xFFFFFAEB),
                  border: Border.all(
                    color:
                        const Color(
                            0xFF0F172A),
                    width: 2,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color:
                          Color(0xFF0F172A),
                      blurRadius: 0,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_tempMediaFile !=
                          null)
                        Image.file(
                          _tempMediaFile!,
                          fit: BoxFit.cover,
                        )
                      else if (_existingImagePath !=
                              null &&
                          _existingImagePath!
                              .isNotEmpty)
                        SmartImage(
                          imagePath:
                              _existingImagePath,
                          fit: BoxFit.cover,
                        )
                      else
                        Column(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets
                                      .all(12),
                              decoration:
                                  BoxDecoration(
                                color:
                                    const Color(
                                        0xFFFFD400),
                                shape:
                                    BoxShape
                                        .circle,
                                border:
                                    Border.all(
                                  color:
                                      const Color(
                                          0xFF0F172A),
                                  width: 2,
                                ),
                                boxShadow:
                                    const [
                                  BoxShadow(
                                    color:
                                        Color(
                                            0xFF0F172A),
                                    blurRadius:
                                        0,
                                    offset:
                                        Offset(
                                            0,
                                            2),
                                  ),
                                ],
                              ),
                              child:
                                  const Icon(
                                Icons
                                    .camera_alt_rounded,
                                size: 24,
                                color:
                                    Color(
                                        0xFF0F172A),
                              ),
                            ),
                            const SizedBox(
                                height: 10),
                            Text(
                              "Añadir foto del plato o lugar",
                              style:
                                  GoogleFonts
                                      .outfit(
                                fontWeight:
                                    FontWeight
                                        .bold,
                                fontSize: 15,
                                color:
                                    const Color(
                                        0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      if (_tempMediaFile !=
                              null ||
                          (_existingImagePath !=
                                  null &&
                              _existingImagePath!
                                  .isNotEmpty))
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                      0xFFFFD400),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                              border:
                                  Border.all(
                                color:
                                    const Color(
                                        0xFF0F172A),
                                width: 2,
                              ),
                              boxShadow:
                                  const [
                                BoxShadow(
                                  color:
                                      Color(
                                          0xFF0F172A),
                                  blurRadius:
                                      0,
                                  offset:
                                      Offset(
                                          0,
                                          2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize:
                                  MainAxisSize
                                      .min,
                              children: [
                                const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color:
                                      Color(
                                          0xFF0F172A),
                                ),
                                const SizedBox(
                                    width: 6),
                                Text(
                                  "Cambiar foto",
                                  style:
                                      GoogleFonts
                                          .outfit(
                                    color:
                                        const Color(
                                            0xFF0F172A),
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            if (generator != null)
              ...generator.buildFields(
                _dynamicData,
                (key, value) {
                  setState(() {
                    _dynamicData[key] =
                        value;
                  });
                },
                _otroSaborController,
              ),

            const SizedBox(height: 8),

            _buildSectionLabel(
              "Puntuación general",
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color:
                      const Color(0xFF0F172A),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color:
                        Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data:
                          SliderThemeData(
                        activeTrackColor:
                            const Color(
                                0xFF0F172A),
                        inactiveTrackColor:
                            Colors.grey
                                .shade300,
                        thumbColor:
                            const Color(
                                0xFFFFD400),
                        overlayColor:
                            const Color(
                                    0xFFFFD400)
                                .withValues(
                          alpha: 0.2,
                        ),
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
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                              0xFFFFD400),
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                      border:
                          Border.all(
                        color:
                            const Color(
                                0xFF0F172A),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      _rating
                          .toStringAsFixed(
                        1,
                      ),
                      style:
                          GoogleFonts.outfit(
                        fontWeight:
                            FontWeight.w900,
                        color:
                            const Color(
                                0xFF0F172A),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionLabel(
              "¿Volverías a este lugar?",
            ),
            const SizedBox(height: 8),
            Container(
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color:
                      const Color(
                          0xFF0F172A),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color:
                        Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child:
                  SwitchListTile(
                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 16,
                ),
                title: Text(
                  "¿Volverías?",
                  style:
                      GoogleFonts.inter(
                    fontWeight:
                        FontWeight.bold,
                    color:
                        const Color(
                            0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
                value:
                    _wouldReturnState ??
                        false,
                activeThumbColor:
                    const Color(
                        0xFFFFD400),
                onChanged: (v) {
                  setState(() {
                    _wouldReturnState =
                        v;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            _buildSectionLabel(
              "Nota personal",
            ),
            const SizedBox(height: 8),
            Container(
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color:
                      const Color(
                          0xFF0F172A),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color:
                        Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller:
                    _descController,
                maxLines: 3,
                style:
                    GoogleFonts.inter(
                  color:
                      const Color(
                          0xFF0F172A),
                  fontWeight:
                      FontWeight.w500,
                  fontSize: 14,
                ),
                decoration:
                    InputDecoration(
                  hintText:
                      "Escribe tus impresiones...",
                  hintStyle:
                      GoogleFonts.inter(
                    color:
                        Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  border:
                      InputBorder.none,
                  contentPadding:
                      const EdgeInsets
                          .all(14),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              height: 56,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
                boxShadow: const [
                  BoxShadow(
                    color:
                        Color(0xFF0F172A),
                    blurRadius: 0,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                          0xFFFFD400),
                  foregroundColor:
                      const Color(
                          0xFF0F172A),
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                    side:
                        const BorderSide(
                      color:
                          Color(
                              0xFF0F172A),
                      width: 2.5,
                    ),
                  ),
                ),
                onPressed: _isSaving
                    ? null
                    : _saveMemory,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color:
                              Color(0xFF0F172A),
                        ),
                      )
                    : Text(
                        _isEditing
                            ? "Guardar Cambios"
                            : "Guardar Recuerdo",
                        style:
                            GoogleFonts.outfit(
                          fontWeight:
                              FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    ],
  ),
);

}

// ============================================================
// UI
// ============================================================

Widget _buildSectionLabel(
String title,
) {
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
if (_restaurantController.text
.trim()
.isEmpty) {
_showError(
"Nombre de restaurante",
);
return;
}

if (_locationController.text
    .trim()
    .isEmpty) {
  _showError(
    "Ubicación",
  );
  return;
}

if (_rating <= 0.0) {
  _showError(
    "Puntuación",
  );
  return;
}

if (_wouldReturnState == null) {
  _showError(
    "¿Volverías?",
  );
  return;
}

if (_isSaving) {
  return;
}

setState(() {
  _isSaving = true;
});

try {
  // ========================================================
  // 1. GUARDAR IMAGEN
  // ========================================================

  List<String> finalImagePaths =
      List<String>.from(
    widget.memory?.imageUrls ?? <String>[],
  );

  if (_tempMediaFile != null) {
    final permanentFileName =
        await ImageSaver.saveImagePermanently(
      _tempMediaFile!.path,
    );

    finalImagePaths = [
      permanentFileName,
    ];
  } else if (_existingImagePath != null &&
      _existingImagePath!.isNotEmpty) {
    finalImagePaths = [
      _existingImagePath!,
    ];
  }

  // ========================================================
  // 2. RESOLVER UBICACIÓN
  // ========================================================

  final String addressText =
      _locationController.text.trim();

  LocationData? resolvedLocation;

  // --------------------------------------------------------
  // PRIORIDAD 1:
  // Coordenadas GPS obtenidas durante esta sesión.
  // --------------------------------------------------------

  if (_currentLocation != null &&
      _currentLocation!.lat != null &&
      _currentLocation!.lng != null) {
    final currentLat =
        _currentLocation!.lat!;
    final currentLng =
        _currentLocation!.lng!;

    // Si el texto sigue siendo el mismo,
    // conservamos directamente las coordenadas.
    if (_currentLocation!.address
            .trim()
            .toLowerCase() ==
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

  // --------------------------------------------------------
  // PRIORIDAD 2:
  // Coordenadas existentes del recuerdo en edición.
  // --------------------------------------------------------

  if (resolvedLocation == null &&
      _isEditing &&
      widget.memory != null &&
      widget.memory!.location.lat != null &&
      widget.memory!.location.lng != null &&
      widget.memory!.location.address
              .trim()
              .toLowerCase() ==
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

  // --------------------------------------------------------
  // PRIORIDAD 3:
  // Geocodificar la dirección.
  // --------------------------------------------------------

  resolvedLocation ??=
    await _resolveAddressToLocation(
  addressText,
);

  // --------------------------------------------------------
  // VALIDACIÓN FINAL:
  // El mapa necesita coordenadas.
  // --------------------------------------------------------

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

  final double lat =
      resolvedLocation.lat!;

  final double lng =
      resolvedLocation.lng!;

  debugPrint(
    '📍 UBICACIÓN FINAL VALIDADA: '
    'address=$addressText, '
    'lat=$lat, '
    'lng=$lng',
  );

  // ========================================================
  // 3. LOCATIONDATA FINAL
  // ========================================================

  final finalLocation =
      LocationData(
    address: addressText,
    lat: lat,
    lng: lng,
  );

  // ========================================================
  // 4. DATOS DINÁMICOS
  // ========================================================

  final Map<String, dynamic>
      finalDynamicData =
      Map<String, dynamic>.from(
    _dynamicData,
  );

  if (_descController.text
      .trim()
      .isNotEmpty) {
    finalDynamicData[
            'description'] =
        _descController.text.trim();
  } else {
    finalDynamicData.remove(
      'description',
    );
  }

  if (_otroSaborController.text
      .trim()
      .isNotEmpty) {
    finalDynamicData[
            'otro_sabor'] =
        _otroSaborController.text
            .trim();
  }

  // ========================================================
  // 5. ID
  // ========================================================

  final memoryId =
      widget.memory?.id ??
          const Uuid().v4();

  // ========================================================
  // 6. MODELO FINAL
  // ========================================================

  final newMemory =
      MemoryModel(
    id: memoryId,
    title:
        _restaurantController.text
            .trim(),
    restaurantName:
        _restaurantController.text
            .trim(),
    location:
        finalLocation,
    wouldReturn:
        _wouldReturnState ?? false,
    rating:
        _rating,
    imageUrls:
        finalImagePaths,
    videoUrl:
        widget.memory?.videoUrl,
    date:
        widget.memory?.date ??
            DateTime.now(),
    category:
        _selectedCategory,
    specificFields:
        finalDynamicData,
  );

  // ========================================================
  // 7. DATOS FIRESTORE
  // ========================================================

  final Map<String, dynamic>
      firestoreMemoryData =
      Map<String, dynamic>.from(
    newMemory.toJson(),
  );

  // Importante:
  // El servicio de Firestore ordena por timestamp.
  // Guardamos una fecha real además del date del modelo.
  firestoreMemoryData['timestamp'] =
      FieldValue.serverTimestamp();

  // Nos aseguramos de que location tenga
  // explícitamente las coordenadas.
  firestoreMemoryData['location'] = {
    'address': addressText,
    'lat': lat,
    'lng': lng,
  };

  firestoreMemoryData['id'] =
      memoryId;

  debugPrint(
    '💾 FIRESTORE MEMORY DATA: '
    '$firestoreMemoryData',
  );

  // ========================================================
  // 8. GUARDAR EN PROVIDER LOCAL
  // ========================================================

  if (_isEditing) {
    ref
        .read(
          memoryProvider.notifier,
        )
        .updateMemory(
          newMemory,
        );
  } else {
    ref
        .read(
          memoryProvider.notifier,
        )
        .addMemory(
          newMemory,
        );
  }

  // ========================================================
  // 9. GUARDAR EN FIRESTORE
  // ========================================================

  final memoryMapService =
      ref.read(
    memoryMapServiceProvider,
  );

  await memoryMapService.saveMemory(
    memoryId: memoryId,
    memoryData:
        firestoreMemoryData,
  );

  // ========================================================
  // 10. SINCRONIZAR COLLECTION LOCATIONS
  // ========================================================

  await memoryMapService.saveLocation(
    locationId:
        memoryId,
    locationData: {
      'memoryId':
          memoryId,
      'title':
          newMemory.title,
      'restaurantName':
          newMemory.restaurantName,
      'address':
          addressText,
      'lat':
          lat,
      'lng':
          lng,
      'category':
          _selectedCategory,
      'rating':
          _rating,
      'wouldReturn':
          _wouldReturnState ??
              false,
    },
  );

  debugPrint(
    '✅ RECUERDO GUARDADO COMPLETAMENTE',
  );

  debugPrint(
    '🗺️ COORDENADAS DISPONIBLES PARA EL MAPA: '
    '$lat, $lng',
  );
} catch (e, stack) {
  debugPrint(
    '❌ Error guardando recuerdo: $e',
  );

  debugPrintStack(
    stackTrace: stack,
  );

  if (mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          "Error guardando el recuerdo: $e",
        ),
      ),
    );
  }

  return;
} finally {
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

void _showError(
String field,
) {
ScaffoldMessenger.of(context)
.showSnackBar(
SnackBar(
content: Text(
"Por favor, completa: $field",
),
),
);
}
}
