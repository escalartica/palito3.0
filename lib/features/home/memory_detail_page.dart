import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/dock_provider.dart';
import 'memory_form_page.dart';
import '../../core/theme/components/smart_image.dart';
import 'widgets/animated_card.dart';
import 'widgets/circle_button.dart';
import 'widgets/hero_header.dart';
import 'widgets/icon_box.dart';
import 'widgets/location_section.dart';
import 'widgets/rating_card.dart';
import 'widgets/section_title.dart';
import 'widgets/variedades_card.dart';

class MemoryDetailPage extends ConsumerStatefulWidget {
  final MemoryModel memory;

  const MemoryDetailPage({super.key, required this.memory});

  @override
  ConsumerState<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends ConsumerState<MemoryDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (mounted) {
        ref.read(dockVisibleProvider.notifier).state = false;
      }
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoryProvider);

    final currentMemory = memories.firstWhere(
      (m) => m.id == widget.memory.id,
      orElse: () => widget.memory,
    );

    final firstImageUrl = currentMemory.imageUrls.isNotEmpty
        ? currentMemory.imageUrls.first
        : null;

    final description =
        currentMemory.specificFields['description'] ??
        currentMemory.specificFields['nota'] ??
        '';

    final bool showRestaurantSubtitle =
        currentMemory.title.toLowerCase() !=
        currentMemory.restaurantName.toLowerCase();

    final Map<String, dynamic> extraFields =
        Map<String, dynamic>.from(currentMemory.specificFields)
          ..remove('description')
          ..remove('nota')
          ..remove('otro_sabor')
          ..remove('es_surtido')
          ..remove('variedades');

    final String? otroSabor = currentMemory.specificFields['otro_sabor']
        ?.toString();

    // Croquetas variadas: cada sabor del surtido con su propia valoración
    // (ver CroquetasFields / _VariedadesBuilder), en vez del volcado
    // genérico de specificFields que quedaría como un Map.toString() feo.
    final List<Map<String, dynamic>> variedades =
        currentMemory.specificFields['variedades'] is List
        ? List<Map<String, dynamic>>.from(
            (currentMemory.specificFields['variedades'] as List).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          )
        : const <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      floatingActionButton: _buildFloatingEditButton(context, currentMemory),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          HeroHeader(
            memory: currentMemory,
            firstImageUrl: firstImageUrl,
            onBack: () => Navigator.pop(context),
            onEdit: () => _openEditPage(context, currentMemory),
            onImageTap: firstImageUrl != null
                ? () => _openFullScreenImage(context, firstImageUrl)
                : null,
          ),

          SliverToBoxAdapter(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: _buildMainContent(
                    context,
                    currentMemory,
                    description.toString(),
                    showRestaurantSubtitle,
                    extraFields,
                    otroSabor,
                    variedades,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENIDO PRINCIPAL
  // ============================================================

  Widget _buildMainContent(
    BuildContext context,
    MemoryModel memory,
    String description,
    bool showRestaurantSubtitle,
    Map<String, dynamic> extraFields,
    String? otroSabor,
    List<Map<String, dynamic>> variedades,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDragHandle(),

          const SizedBox(height: 20),

          _buildTopSummary(memory),

          const SizedBox(height: 24),

          if (showRestaurantSubtitle && memory.restaurantName.isNotEmpty)
            _buildRestaurantCard(memory),

          if (showRestaurantSubtitle && memory.restaurantName.isNotEmpty)
            const SizedBox(height: 20),

          RatingCard(memory: memory),

          const SizedBox(height: 20),

          if (variedades.isNotEmpty) VariedadesCard(variedades: variedades),

          if (variedades.isNotEmpty) const SizedBox(height: 20),

          if (extraFields.isNotEmpty ||
              (otroSabor != null && otroSabor.isNotEmpty))
            _buildExperienceDetails(extraFields, otroSabor),

          if (extraFields.isNotEmpty ||
              (otroSabor != null && otroSabor.isNotEmpty))
            const SizedBox(height: 24),

          _buildOpinionSection(description),

          const SizedBox(height: 24),

          _buildRecommendationCard(memory),

          const SizedBox(height: 28),

          _buildSectionDivider(),

          const SizedBox(height: 24),

          LocationSection(memory: memory),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildTopSummary(MemoryModel memory) {
    return Row(
      children: [
        Expanded(child: _buildCategoryBadge(memory.category)),
        const SizedBox(width: 12),
        _buildReturnMiniBadge(memory.wouldReturn),
      ],
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0F172A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0F172A),
            blurRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        category.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildReturnMiniBadge(bool wouldReturn) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: wouldReturn ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0F172A), width: 2),
      ),
      child: Icon(
        wouldReturn ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
        size: 18,
        color: const Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildRestaurantCard(MemoryModel memory) {
    return AnimatedCard(
      child: Row(
        children: [
          const IconBox(
            icon: Icons.storefront_rounded,
            backgroundColor: Color(0xFFFFD400),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LUGAR',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  memory.restaurantName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PUNTUACIÓN
  // ============================================================

  // ============================================================
  // DETALLES DINÁMICOS
  // ============================================================

  Widget _buildExperienceDetails(
    Map<String, dynamic> extraFields,
    String? otroSabor,
  ) {
    final List<MapEntry<String, dynamic>> entries = extraFields.entries
        .toList();

    if (otroSabor != null && otroSabor.trim().isNotEmpty) {
      entries.add(MapEntry('otro_sabor', otroSabor));
    }

    return AnimatedCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBox(
                icon: Icons.tune_rounded,
                backgroundColor: Color(0xFFFFD400),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'DETALLES DE LA EXPERIENCIA',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          ...List.generate(entries.length, (index) {
            final entry = entries[index];

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + (index * 80)),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDetailRow(entry.key, entry.value),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String key, dynamic value) {
    final cleanedValue = _cleanValue(value);

    if (cleanedValue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0F172A).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              key == 'otro_sabor' ? 'Sabor adicional' : _formatKey(key),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              cleanedValue,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OPINIÓN
  // ============================================================

  Widget _buildOpinionSection(String description) {
    final bool hasDescription = description.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          icon: Icons.format_quote_rounded,
          title: 'Tu opinión',
        ),
        const SizedBox(height: 12),
        AnimatedCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 26,
                color: hasDescription
                    ? const Color(0xFFFFD400)
                    : Colors.grey.shade300,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasDescription
                      ? description
                      : 'Sin descripción personal añadida en este recuerdo.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: hasDescription
                        ? const Color(0xFF0F172A)
                        : Colors.grey.shade400,
                    height: 1.6,
                    fontStyle: hasDescription
                        ? FontStyle.normal
                        : FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RECOMENDACIÓN
  // ============================================================

  Widget _buildRecommendationCard(MemoryModel memory) {
    final bool wouldReturn = memory.wouldReturn;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: wouldReturn ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF0F172A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0F172A),
            blurRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(wouldReturn),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD400),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0F172A), width: 2),
              ),
              child: Icon(
                wouldReturn ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                size: 20,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wouldReturn ? 'RECOMENDACIÓN' : 'IMPRESIÓN PERSONAL',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  wouldReturn
                      ? '¡Sí volvería a este lugar sin duda!'
                      : 'No tengo claro si volvería',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMPONENTES REUTILIZABLES
  // ============================================================

  Widget _buildFloatingEditButton(BuildContext context, MemoryModel memory) {
    return FloatingActionButton.extended(
      heroTag: 'edit-memory-${memory.id}',
      backgroundColor: const Color(0xFFFFD400),
      foregroundColor: const Color(0xFF0F172A),
      elevation: 0,
      onPressed: () => _openEditPage(context, memory),
      icon: const Icon(Icons.edit_rounded, size: 19),
      label: Text(
        'Editar',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF0F172A), width: 2),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 2, color: const Color(0xFF0F172A))),
        const SizedBox(width: 12),
        const Icon(
          Icons.restaurant_rounded,
          size: 18,
          color: Color(0xFF0F172A),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 2, color: const Color(0xFF0F172A))),
      ],
    );
  }

  // ============================================================
  // NAVEGACIÓN
  // ============================================================

  void _openEditPage(BuildContext context, MemoryModel memory) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return MemoryFormPage(memory: memory);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Colors.black.withValues(alpha: 0.96),
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: 'memory-image-${widget.memory.id}',
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: SmartImage(
                          imagePath: imagePath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: CircleButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Cerrar',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // ============================================================
  // UTILIDADES
  // ============================================================

  String _formatKey(String key) {
    if (key.isEmpty) {
      return '';
    }

    final formatted = key.replaceAll('_', ' ');

    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  String _cleanValue(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is List) {
      return value.map((item) => item.toString()).join(', ');
    }

    if (value is bool) {
      return value ? 'Sí' : 'No';
    }

    String text = value.toString();

    text = text
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", '');

    return text.trim();
  }
}
