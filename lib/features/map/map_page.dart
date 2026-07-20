import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/providers/memory_provider.dart';

class MapPage extends ConsumerStatefulWidget {
  final String? initialCategory;

  const MapPage({super.key, this.initialCategory});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  String? _selectedCategory;

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(39.47, -6.37),
              initialZoom: 6.0,
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
                  final filteredMemories = (_selectedCategory == null || _selectedCategory == 'Todas')
                      ? allMemories
                      : allMemories.where((m) => m.category == _selectedCategory).toList();

                  return MarkerLayer(
                    markers: filteredMemories
                        .where((m) => m.location.lat != null && m.location.lng != null)
                        .map((memory) {
                      // Lógica de colores según el estado "volverías"
                      final color = memory.wouldReturn ? Colors.green : Colors.redAccent;
                      
                      return Marker(
                        width: 60,
                        height: 60,
                        alignment: Alignment.topCenter,
                        point: LatLng(memory.location.lat!, memory.location.lng!),
                        child: Column(
                          children: [
                            // Etiqueta con la puntuación
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: color, width: 1),
                              ),
                              child: Text(
                                memory.rating.toStringAsFixed(0),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                              ),
                            ),
                            // Icono del pin
                            Icon(Icons.pin_drop_rounded, color: color, size: 30),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
          
          Positioned(
            top: 55,
            left: 10,
            right: 10,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/'),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back, color: Color(0xFFE91E63)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filterCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _filterCategories[index];
                        final isSelected = (_selectedCategory ?? 'Todas') == cat;
                        return FilterChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = cat == 'Todas' ? null : cat;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFFE91E63).withOpacity(0.2),
                          checkmarkColor: const Color(0xFFE91E63),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}