
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

  const MemoryDetailPage({
    super.key,
    required this.memory,
  });

  @override
  ConsumerState<MemoryDetailPage> createState() =>
      _MemoryDetailPageState();
}

class _MemoryDetailPageState
    extends ConsumerState<MemoryDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _imagePressed = false;

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
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

    final firstImageUrl =
        currentMemory.imageUrls.isNotEmpty
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
        Map<String, dynamic>.from(
      currentMemory.specificFields,
    )
          ..remove('description')
          ..remove('nota')
          ..remove('otro_sabor');

    final String? otroSabor =
        currentMemory.specificFields['otro_sabor']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      floatingActionButton: _buildFloatingEditButton(
        context,
        currentMemory,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeroHeader(
            context,
            currentMemory,
            firstImageUrl,
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
  // CABECERA HERO
  // ============================================================

  Widget _buildHeroHeader(
    BuildContext context,
    MemoryModel memory,
    String? firstImageUrl,
  ) {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFFFFFDF5),
      elevation: 0,
      automaticallyImplyLeading: false,

      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _buildCircleButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Volver',
          onTap: () => Navigator.pop(context),
        ),
      ),

      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _buildCircleButton(
            icon: Icons.edit_rounded,
            tooltip: 'Editar recuerdo',
            onTap: () => _openEditPage(
              context,
              memory,
            ),
          ),
        ),
      ],

      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: GestureDetector(
          onTap: firstImageUrl != null
              ? () => _openFullScreenImage(
                    context,
                    firstImageUrl,
                  )
              : null,
          onTapDown: (_) {
            if (mounted) {
              setState(() {
                _imagePressed = true;
              });
            }
          },
          onTapUp: (_) {
            if (mounted) {
              setState(() {
                _imagePressed = false;
              });
            }
          },
          onTapCancel: () {
            if (mounted) {
              setState(() {
                _imagePressed = false;
              });
            }
          },
          child: AnimatedScale(
            scale: _imagePressed ? 0.985 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'memory-image-${memory.id}',
                  child: firstImageUrl != null &&
                          firstImageUrl.isNotEmpty
                      ? SmartImage(
                          imagePath: firstImageUrl,
                          fit: BoxFit.cover,
                        )
                      : _buildImagePlaceholder(),
                ),

                _buildImageGradient(),

                if (firstImageUrl != null &&
                    firstImageUrl.isNotEmpty)
                  Positioned(
                    right: 18,
                    bottom: 48,
                    child: _buildImagePreviewBadge(),
                  ),

                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 46,
                  child: _buildHeroTitle(memory),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 70,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildImageGradient() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.78),
          ],
          stops: const [
            0.0,
            0.42,
            1.0,
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.fullscreen_rounded,
            size: 16,
            color: Color(0xFF0F172A),
          ),
          const SizedBox(width: 6),
          Text(
            'Ver foto',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTitle(
    MemoryModel memory,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          memory.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.8,
            height: 1.05,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        if (memory.restaurantName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                size: 16,
                color: Color(0xFFFFD400),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  memory.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
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
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF5),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        20,
        26,
        20,
        100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDragHandle(),

          const SizedBox(height: 20),

          _buildTopSummary(memory),

          const SizedBox(height: 24),

          if (showRestaurantSubtitle &&
              memory.restaurantName.isNotEmpty)
            _buildRestaurantCard(memory),

          if (showRestaurantSubtitle &&
              memory.restaurantName.isNotEmpty)
            const SizedBox(height: 20),

          _buildRatingCard(memory),

          const SizedBox(height: 20),

          if (extraFields.isNotEmpty ||
              (otroSabor != null &&
                  otroSabor.isNotEmpty))
            _buildExperienceDetails(
              extraFields,
              otroSabor,
            ),

          if (extraFields.isNotEmpty ||
              (otroSabor != null &&
                  otroSabor.isNotEmpty))
            const SizedBox(height: 24),

          _buildOpinionSection(description),

          const SizedBox(height: 24),

          _buildRecommendationCard(memory),

          const SizedBox(height: 28),

          _buildSectionDivider(),

          const SizedBox(height: 24),

          _buildLocationSection(memory),
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
          color: const Color(0xFF0F172A)
              .withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildTopSummary(
    MemoryModel memory,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildCategoryBadge(
            memory.category,
          ),
        ),
        const SizedBox(width: 12),
        _buildReturnMiniBadge(
          memory.wouldReturn,
        ),
      ],
    );
  }

  Widget _buildCategoryBadge(
    String category,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildReturnMiniBadge(
    bool wouldReturn,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: wouldReturn
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0F172A),
          width: 2,
        ),
      ),
      child: Icon(
        wouldReturn
            ? Icons.thumb_up_rounded
            : Icons.thumb_down_rounded,
        size: 18,
        color: const Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildRestaurantCard(
    MemoryModel memory,
  ) {
    return _buildAnimatedCard(
      child: Row(
        children: [
          _buildIconBox(
            Icons.storefront_rounded,
            const Color(0xFFFFD400),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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

  Widget _buildRatingCard(
    MemoryModel memory,
  ) {
    final rating = memory.rating.clamp(0.0, 10.0);
    final progress = rating / 10.0;

    return _buildAnimatedCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildIconBox(
                    Icons.star_rounded,
                    const Color(0xFFFFD400),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Puntuación',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color:
                          const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              _buildRatingNumber(rating),
            ],
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: progress,
              ),
              duration:
                  const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder:
                  (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor:
                      Colors.grey.shade200,
                  valueColor:
                      const AlwaysStoppedAnimation<
                          Color>(
                    Color(0xFFFFD400),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                _ratingLabel(rating),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                '10',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingNumber(
    double rating,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD400),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0F172A),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0F172A),
            blurRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star_rounded,
            size: 18,
            color: Color(0xFF0F172A),
          ),
          const SizedBox(width: 5),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(double rating) {
    if (rating >= 9) {
      return 'Extraordinario';
    }

    if (rating >= 8) {
      return 'Excelente';
    }

    if (rating >= 7) {
      return 'Muy bueno';
    }

    if (rating >= 5) {
      return 'Correcto';
    }

    return 'Por mejorar';
  }

  // ============================================================
  // DETALLES DINÁMICOS
  // ============================================================

  Widget _buildExperienceDetails(
    Map<String, dynamic> extraFields,
    String? otroSabor,
  ) {
    final List<MapEntry<String, dynamic>> entries =
        extraFields.entries.toList();

    if (otroSabor != null &&
        otroSabor.trim().isNotEmpty) {
      entries.add(
        MapEntry(
          'otro_sabor',
          otroSabor,
        ),
      );
    }

    return _buildAnimatedCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconBox(
                Icons.tune_rounded,
                const Color(0xFFFFD400),
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

          ...List.generate(
            entries.length,
            (index) {
              final entry = entries[index];

              return TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 0,
                  end: 1,
                ),
                duration: Duration(
                  milliseconds:
                      300 + (index * 80),
                ),
                curve: Curves.easeOut,
                builder:
                    (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        8 * (1 - value),
                      ),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: _buildDetailRow(
                    entry.key,
                    entry.value,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String key,
    dynamic value,
  ) {
    final cleanedValue =
        _cleanValue(value);

    if (cleanedValue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xFF0F172A)
                  .withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              key == 'otro_sabor'
                  ? 'Sabor adicional'
                  : _formatKey(key),
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

  Widget _buildOpinionSection(
    String description,
  ) {
    final bool hasDescription =
        description.trim().isNotEmpty;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          icon: Icons.format_quote_rounded,
          title: 'Tu opinión',
        ),
        const SizedBox(height: 12),
        _buildAnimatedCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
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

  Widget _buildRecommendationCard(
    MemoryModel memory,
  ) {
    final bool wouldReturn =
        memory.wouldReturn;

    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: wouldReturn
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(18),
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
      child: Row(
        children: [
          AnimatedSwitcher(
            duration:
                const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(wouldReturn),
              padding:
                  const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD400),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      const Color(0xFF0F172A),
                  width: 2,
                ),
              ),
              child: Icon(
                wouldReturn
                    ? Icons.thumb_up_rounded
                    : Icons.thumb_down_rounded,
                size: 20,
                color:
                    const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  wouldReturn
                      ? 'RECOMENDACIÓN'
                      : 'IMPRESIÓN PERSONAL',
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
                    color:
                        const Color(0xFF0F172A),
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
  // UBICACIÓN
  // ============================================================

  Widget _buildLocationSection(
    MemoryModel memory,
  ) {
    final hasCoordinates =
        memory.location.lat != null &&
            memory.location.lng != null;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          icon: Icons.location_on_rounded,
          title: 'Ubicación',
        ),

        const SizedBox(height: 12),

        _buildAnimatedCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildIconBox(
                    Icons.location_on_rounded,
                    const Color(0xFFFFD400),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      memory.location.address,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color:
                            const Color(0xFF0F172A),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),

              if (hasCoordinates) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFFFFDF5),
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          const Color(0xFF0F172A)
                              .withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        size: 16,
                        color:
                            Color(0xFF0F172A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${memory.location.lat!.toStringAsFixed(5)}, '
                          '${memory.location.lng!.toStringAsFixed(5)}',
                          style:
                              GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w700,
                            color: Colors
                                .grey
                                .shade600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color:
                            Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COMPONENTES REUTILIZABLES
  // ============================================================

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF0F172A),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildIconBox(
    IconData icon,
    Color backgroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFF0F172A),
          width: 2,
        ),
      ),
      child: Icon(
        icon,
        size: 18,
        color: const Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildAnimatedCard({
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
      child: child,
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF0F172A),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF0F172A),
                  blurRadius: 0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0F172A),
              size: 17,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingEditButton(
    BuildContext context,
    MemoryModel memory,
  ) {
    return FloatingActionButton.extended(
      heroTag: 'edit-memory-${memory.id}',
      backgroundColor:
          const Color(0xFFFFD400),
      foregroundColor:
          const Color(0xFF0F172A),
      elevation: 0,
      onPressed: () =>
          _openEditPage(context, memory),
      icon: const Icon(
        Icons.edit_rounded,
        size: 19,
      ),
      label: Text(
        'Editar',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFF0F172A),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 2,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(
          Icons.restaurant_rounded,
          size: 18,
          color: Color(0xFF0F172A),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 2,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NAVEGACIÓN
  // ============================================================

  void _openEditPage(
    BuildContext context,
    MemoryModel memory,
  ) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration:
            const Duration(milliseconds: 400),
        reverseTransitionDuration:
            const Duration(milliseconds: 300),
        pageBuilder:
            (
          context,
          animation,
          secondaryAnimation,
        ) {
          return MemoryFormPage(
            memory: memory,
          );
        },
        transitionsBuilder:
            (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final curvedAnimation =
              CurvedAnimation(
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

  void _openFullScreenImage(
    BuildContext context,
    String imagePath,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration:
            const Duration(milliseconds: 350),
        pageBuilder:
            (
          context,
          animation,
          secondaryAnimation,
        ) {
          return Scaffold(
            backgroundColor:
                Colors.black.withValues(alpha: 0.96),
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag:
                          'memory-image-${widget.memory.id}',
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
                    child: _buildCircleButton(
                      icon:
                          Icons.close_rounded,
                      tooltip: 'Cerrar',
                      onTap: () =>
                          Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder:
            (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
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

    final formatted =
        key.replaceAll('_', ' ');

    return formatted[0].toUpperCase() +
        formatted.substring(1);
  }

  String _cleanValue(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is List) {
      return value
          .map((item) => item.toString())
          .join(', ');
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

