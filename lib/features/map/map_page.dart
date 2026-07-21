import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/providers/memory_provider.dart';
import '../../../../../core/models/memory_model.dart';

class MapPage extends ConsumerStatefulWidget {
  final String? initialCategory;

  const MapPage({super.key, this.initialCategory});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> with TickerProviderStateMixin {
  String? _selectedCategory;
  final MapController _mapController = MapController();
  
  // Centro por defecto de la Península Ibérica
  final LatLng _peninsulaCenter = const LatLng(40.4168, -3.7038);
  final double _peninsulaZoom = 6.2;

  final Map<String, LatLng> _geocodedCache = {};
  bool _isResolvingCoordinates = false;

  final List<String> _filterCategories = [
    'Todas', 
    'Croquetas', 
    'Ensaladilla', 
    'Tortilla', 
    'Menú', 
    'Plato estrella', 
    'Postre/Helados', 
    'Decoración/Espacio', 
    'Atención'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndFitMap();
    });
  }

  String _normalize(String text) {
    return text.toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), ''); 
  }

  bool _matchesCategory(MemoryModel memory, String? filter) {
    if (filter == null || filter == 'Todas') return true;
    
    final memoryCat = _normalize(memory.category);
    final filterCat = _normalize(filter);

    if (memoryCat == filterCat) return true;

    if (filterCat.contains('postre') && (memoryCat.contains('postre') || memoryCat.contains('helado'))) return true;
    if (filterCat.contains('decoracion') && (memoryCat.contains('decoracion') || memoryCat.contains('espacio'))) return true;
    if (filterCat.contains('menu') && memoryCat.contains('menu')) return true;
    if (filterCat.contains('plato') && memoryCat.contains('plato')) return true;

    return false;
  }

  Future<void> _initializeAndFitMap() async {
    if (_isResolvingCoordinates) return;
    _isResolvingCoordinates = true;

    try {
      final memories = ref.read(memoryProvider);
      bool updated = false;

      for (var memory in memories) {
        if ((memory.location.lat == null || memory.location.lng == null) && 
            memory.location.address.isNotEmpty) {
          final addressKey = memory.location.address;
          if (_geocodedCache.containsKey(addressKey)) continue;

          try {
            List<Location> locations = await locationFromAddress(addressKey);
            if (locations.isNotEmpty) {
              _geocodedCache[addressKey] = LatLng(locations.first.latitude, locations.first.longitude);
              updated = true;
            }
          } catch (_) {}
        }
      }

      if (updated && mounted) {
        setState(() {});
      }

      _fitMapToFilteredMemories(animated: false);
    } finally {
      _isResolvingCoordinates = false;
    }
  }

  void _fitMapToFilteredMemories({bool animated = true}) {
    final memories = ref.read(memoryProvider);
    final filteredMemories = memories.where((m) => _matchesCategory(m, _selectedCategory)).toList();

    List<LatLng> points = [];
    for (var memory in filteredMemories) {
      final cachedCoord = _geocodedCache[memory.location.address];
      final lat = memory.location.lat ?? cachedCoord?.latitude;
      final lng = memory.location.lng ?? cachedCoord?.longitude;
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }

    if (points.isEmpty) return;

    try {
      if (points.length == 1) {
        _animatedMove(points.first, 13.5, animated);
      } else {
        final bounds = LatLngBounds.fromPoints(points);
        
        final cameraFit = CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(60, 140, 60, 100),
          minZoom: 5.0,
          maxZoom: 15.0,
        );

        if (animated) {
          _animatedFitCamera(cameraFit);
        } else {
          _mapController.fitCamera(cameraFit);
        }
      }
    } catch (_) {}
  }

  void _animatedMove(LatLng destLocation, double destZoom, bool animated) {
    if (!animated) {
      _mapController.move(destLocation, destZoom);
      return;
    }

    final camera = _mapController.camera;
    final latTween = Tween<double>(begin: camera.center.latitude, end: destLocation.latitude);
    final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);
    final lngTween = Tween<double>(begin: camera.center.longitude, end: destLocation.longitude);

    final controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    final animation = CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.forward().whenComplete(() => controller.dispose());
  }

  void _animatedFitCamera(CameraFit cameraFit) {
    try {
      // Ajuste seguro de cámara mediante el método nativo para evitar errores de tipo o API obsoleta
      _mapController.fitCamera(cameraFit);
    } catch (_) {}
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    try {
      Position position = await Geolocator.getCurrentPosition();
      _animatedMove(LatLng(position.latitude, position.longitude), 14.5, true);
    } catch (_) {}
  }

  Future<String> _resolveLocationName(double lat, double lng, String currentAddress) async {
    if (currentAddress.isNotEmpty && 
        !currentAddress.startsWith("GPS:") && 
        !currentAddress.startsWith("Lat:") &&
        currentAddress.length > 3) {
      return currentAddress;
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String locality = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? '';
        String subLocality = place.subLocality ?? '';
        
        if (locality.isNotEmpty) {
          return subLocality.isNotEmpty && subLocality != locality 
              ? "$subLocality, $locality" 
              : locality;
        }
      }
    } catch (_) {}

    return currentAddress.isNotEmpty ? currentAddress : "Ubicación GPS (${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)})";
  }

  Color _getCategoryColor(String category) {
    final cat = _normalize(category);
    if (cat.contains('croqueta')) return const Color(0xFFE65100);
    if (cat.contains('ensaladilla')) return const Color(0xFF00838F);
    if (cat.contains('tortilla')) return const Color(0xFFF57F17);
    if (cat.contains('menu')) return const Color(0xFF6A1B9A);
    if (cat.contains('plato')) return const Color(0xFFC2185B);
    if (cat.contains('postre') || cat.contains('helado')) return const Color(0xFF00695C);
    if (cat.contains('decoracion') || cat.contains('espacio')) return const Color(0xFF283593);
    if (cat.contains('atencion')) return const Color(0xFFD84315);
    return const Color(0xFF1E293B);
  }

  void _onMarkerTapped(MemoryModel memory) {
    _showMemoryBottomSheet(memory);
  }

  void _showMemoryBottomSheet(MemoryModel memory) {
    final categoryColor = _getCategoryColor(memory.category);
    final cachedCoord = _geocodedCache[memory.location.address];
    final double? lat = memory.location.lat ?? cachedCoord?.latitude;
    final double? lng = memory.location.lng ?? cachedCoord?.longitude;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 25,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      memory.title,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      "${memory.rating.toStringAsFixed(1)} ★",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: categoryColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: (lat != null && lng != null)
                        ? FutureBuilder<String>(
                            future: _resolveLocationName(lat, lng, memory.location.address),
                            builder: (context, snapshot) {
                              final text = snapshot.data ?? memory.location.address;
                              return Text(
                                text,
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          )
                        : Text(
                            memory.location.address.isNotEmpty ? memory.location.address : "Ubicación no disponible",
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(memory.category),
                    backgroundColor: categoryColor.withValues(alpha: 0.15),
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: categoryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide.none,
                  ),
                  Chip(
                    label: Text(memory.wouldReturn ? "¡Volvería!" : "No volvería"),
                    backgroundColor: (memory.wouldReturn ? Colors.green : Colors.red).withValues(alpha: 0.12),
                    labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, 
                      fontSize: 13, 
                      color: memory.wouldReturn ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide.none,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD400),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/memory-detail', extra: memory);
                  },
                  child: Text(
                    "Ver Experiencia Completa",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _peninsulaCenter,
              initialZoom: _peninsulaZoom,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.palito.app',
                maxZoom: 19,
                retinaMode: true,
              ),
              Consumer(
                builder: (context, ref, _) {
                  final allMemories = ref.watch(memoryProvider);
                  final filteredMemories = allMemories.where((m) => _matchesCategory(m, _selectedCategory)).toList();

                  final Map<String, List<MemoryModel>> groupedMemories = {};
                  for (var memory in filteredMemories) {
                    final cachedCoord = _geocodedCache[memory.location.address];
                    final lat = memory.location.lat ?? cachedCoord?.latitude;
                    final lng = memory.location.lng ?? cachedCoord?.longitude;

                    if (lat == null || lng == null) continue;

                    final key = "${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}";
                    groupedMemories.putIfAbsent(key, () => []).add(memory);
                  }

                  List<Marker> markers = [];
                  
                  groupedMemories.forEach((key, memories) {
                    final parts = key.split('_');
                    final baseLat = double.parse(parts[0]);
                    final baseLng = double.parse(parts[1]);

                    if (memories.length == 1) {
                      final memory = memories.first;
                      markers.add(_buildMarker(memory, LatLng(baseLat, baseLng)));
                    } else {
                      for (int i = 0; i < memories.length; i++) {
                        final memory = memories[i];
                        final angle = i * (2 * pi / memories.length);
                        const double offsetFactor = 0.00015; 
                        final lat = baseLat + (offsetFactor * cos(angle));
                        final lng = baseLng + (offsetFactor * sin(angle));

                        markers.add(_buildMarker(memory, LatLng(lat, lng)));
                      }
                    }
                  });

                  return MarkerLayer(markers: markers);
                },
              ),
            ],
          ),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 12, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/'),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filterCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = _filterCategories[index];
                          final isSelected = (_selectedCategory ?? 'Todas') == cat;
                          return FilterChip(
                            label: Text(cat, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = cat == 'Todas' ? null : cat;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _fitMapToFilteredMemories(animated: true);
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: const Color(0xFFFFD400),
                            checkmarkColor: const Color(0xFF0F172A),
                            elevation: 3,
                            shadowColor: Colors.black26,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 30,
            left: 20,
            child: Consumer(
              builder: (context, ref, _) {
                final allMemories = ref.watch(memoryProvider);
                final count = allMemories.where((m) => _matchesCategory(m, _selectedCategory)).length;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place_rounded, size: 18, color: Color(0xFFFF4D29)),
                      const SizedBox(width: 8),
                      Text(
                        "$count ${count == 1 ? 'sitio' : 'sitios'} en vista",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location_rounded, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildMarker(MemoryModel memory, LatLng point) {
    final categoryColor = _getCategoryColor(memory.category);
    final wouldReturn = memory.wouldReturn;

    return Marker(
      width: 68,
      height: 36,
      point: point,
      child: GestureDetector(
        onTap: () => _onMarkerTapped(memory),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: categoryColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${memory.rating.toStringAsFixed(1)}★",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                wouldReturn ? Icons.check_rounded : Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}