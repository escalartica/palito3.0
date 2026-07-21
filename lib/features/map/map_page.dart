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

class _MapPageState extends ConsumerState<MapPage> {
  String? _selectedCategory;
  final MapController _mapController = MapController();
  
  LatLng _currentCenter = const LatLng(39.47, -6.37);
  double _currentZoom = 7.0;

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
      _precomputeMissingCoordinates();
    });
  }

  // Normaliza cadenas eliminando tildes, mayúsculas, espacios extra y barras para comparar con total flexibilidad
  String _normalize(String text) {
    return text.toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), ''); // Elimina barras, espacios y caracteres especiales para asegurar coincidencia
  }

  bool _matchesCategory(MemoryModel memory, String? filter) {
    if (filter == null || filter == 'Todas') return true;
    
    final memoryCat = _normalize(memory.category);
    final filterCat = _normalize(filter);

    if (memoryCat == filterCat) return true;

    // Coincidencias parciales robustas para categorías compuestas o plurales/singulares
    if (filterCat.contains('postre') && (memoryCat.contains('postre') || memoryCat.contains('helado'))) return true;
    if (filterCat.contains('decoracion') && (memoryCat.contains('decoracion') || memoryCat.contains('espacio'))) return true;
    if (filterCat.contains('menu') && memoryCat.contains('menu')) return true;
    if (filterCat.contains('plato') && memoryCat.contains('plato')) return true;

    return false;
  }

  Future<void> _precomputeMissingCoordinates() async {
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
    } finally {
      _isResolvingCoordinates = false;
    }
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
      _mapController.move(LatLng(position.latitude, position.longitude), 14.0);
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
    return const Color(0xFF37474F);
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
                color: Colors.black12,
                blurRadius: 20,
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
              initialCenter: _currentCenter,
              initialZoom: _currentZoom,
              onPositionChanged: (position, hasGesture) {
                _currentCenter = position.center;
                _currentZoom = position.zoom;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.palito.app',
              ),
              Consumer(
                builder: (context, ref, _) {
                  final allMemories = ref.watch(memoryProvider);
                  final filteredMemories = allMemories.where((m) => _matchesCategory(m, _selectedCategory)).toList();

                  return MarkerLayer(
                    markers: filteredMemories.map((memory) {
                      final cachedCoord = _geocodedCache[memory.location.address];
                      final lat = memory.location.lat ?? cachedCoord?.latitude;
                      final lng = memory.location.lng ?? cachedCoord?.longitude;

                      if (lat == null || lng == null) return null;

                      final categoryColor = _getCategoryColor(memory.category);
                      final wouldReturn = memory.wouldReturn;

                      return Marker(
                        width: 60,
                        height: 32,
                        point: LatLng(lat, lng),
                        child: GestureDetector(
                          onTap: () => _onMarkerTapped(memory),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: categoryColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  wouldReturn ? Icons.check_rounded : Icons.close_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).whereType<Marker>().toList(),
                  );
                },
              ),
            ],
          ),
          
          // Barra superior de categorías
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            right: 12,
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
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2)),
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
                          },
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFFFFD400),
                          checkmarkColor: const Color(0xFF0F172A),
                          elevation: 2,
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

          // Indicador inferior izquierdo de sitios en vista
          Positioned(
            bottom: 30,
            left: 20,
            child: Consumer(
              builder: (context, ref, _) {
                final allMemories = ref.watch(memoryProvider);
                final count = allMemories.where((m) => _matchesCategory(m, _selectedCategory)).length;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place_rounded, size: 16, color: Color(0xFFFF4D29)),
                      const SizedBox(width: 6),
                      Text(
                        "$count ${count == 1 ? 'sitio' : 'sitios'} en vista",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Botón de geolocalización actual
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 4,
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }
}