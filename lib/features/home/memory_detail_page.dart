import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/dock_provider.dart';
import 'memory_form_page.dart';
import '../memory_form/widgets/smart_image.dart'; 

class MemoryDetailPage extends ConsumerStatefulWidget {
  final MemoryModel memory;

  const MemoryDetailPage({super.key, required this.memory});

  @override
  ConsumerState<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends ConsumerState<MemoryDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dockVisibleProvider.notifier).state = false);
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoryProvider);
    final currentMemory = memories.firstWhere(
      (m) => m.id == widget.memory.id,
      orElse: () => widget.memory,
    );

    final firstImageUrl = currentMemory.imageUrls.isNotEmpty ? currentMemory.imageUrls.first : null;
    final description = currentMemory.specificFields['description'] ?? currentMemory.specificFields['nota'] ?? '';
    final bool showRestaurantSubtitle = currentMemory.title.toLowerCase() != currentMemory.restaurantName.toLowerCase();

    // Filtramos campos específicos y limpiamos corchetes o formatos feos
    final Map<String, dynamic> extraFields = Map.from(currentMemory.specificFields)
      ..remove('description')
      ..remove('nota')
      ..remove('otro_sabor');
    
    final String? otroSabor = currentMemory.specificFields['otro_sabor'];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F0),
      body: CustomScrollView(
        slivers: [
          // Cabecera expansible con gradiente inmersivo
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: const Color(0xFFFFFDF5),
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                    tooltip: 'Editar recuerdo',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MemoryFormPage(memory: currentMemory),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  firstImageUrl != null && firstImageUrl.isNotEmpty
                      ? SmartImage(imagePath: firstImageUrl, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.restaurant_rounded, size: 70, color: Colors.grey),
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenedor principal con efecto tarjeta flotante
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFDF5),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categoría y Puntuación en formato insignia elegante
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            currentMemory.category.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: Colors.white, 
                              fontWeight: FontWeight.w700, 
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.amber.shade300, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                currentMemory.rating.toStringAsFixed(1),
                                style: GoogleFonts.outfit(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Título principal del recuerdo
                    Text(
                      currentMemory.title,
                      style: GoogleFonts.outfit(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.8,
                        height: 1.15,
                      ),
                    ),
                    
                    // Restaurante
                    if (showRestaurantSubtitle || currentMemory.restaurantName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFFFF4D29)),
                          const SizedBox(width: 8),
                          Text(
                            currentMemory.restaurantName, 
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Tarjeta de Detalles Específicos (si existen)
                    if (extraFields.isNotEmpty || otroSabor != null && otroSabor.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F1E8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune_rounded, size: 16, color: Colors.blueGrey),
                                const SizedBox(width: 6),
                                Text(
                                  "DETALLES DE LA EXPERIENCIA",
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey.shade700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ...extraFields.entries.map((entry) {
                              final cleanedValue = _cleanValue(entry.value);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatKey(entry.key),
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                                    ),
                                    Text(
                                      cleanedValue,
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (otroSabor != null && otroSabor.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Sabor adicional", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                                    Text(_cleanValue(otroSabor), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Opinión / Nota personal
                    Text(
                      "Tu opinión", 
                      style: GoogleFonts.outfit(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        description.isNotEmpty ? description : "Sin descripción personal añadida en este recuerdo.",
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: description.isNotEmpty ? Colors.grey.shade800 : Colors.grey.shade400,
                          height: 1.6,
                          fontStyle: description.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // Badge de recomendación (¿Volverías?) estilizado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: currentMemory.wouldReturn ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: currentMemory.wouldReturn ? const Color(0xFFA5D6A7) : const Color(0xFFFFCC80),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            currentMemory.wouldReturn ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                            size: 20,
                            color: currentMemory.wouldReturn ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            currentMemory.wouldReturn ? "¡Sí volvería a este lugar sin duda!" : "No tengo claro si volvería",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, 
                              fontSize: 14,
                              color: currentMemory.wouldReturn ? const Color(0xFF1B5E20) : const Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    const Divider(color: Color(0xFFE2E8F0), thickness: 1),
                    const SizedBox(height: 20),

                    // Ubicación detallada
                    Text(
                      "Ubicación", 
                      style: GoogleFonts.outfit(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFFFECE6),
                            child: Icon(Icons.location_on_rounded, size: 20, color: Color(0xFFFF4D29)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              currentMemory.location.address, 
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    if (key.isEmpty) return '';
    final formatted = key.replaceAll('_', ' ');
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  String _cleanValue(dynamic value) {
    if (value == null) return '';
    String text = value.toString();
    text = text.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", '');
    return text.trim();
  }
}