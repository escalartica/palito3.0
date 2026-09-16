import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/data/memory_awards.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/theme/components/app_motion.dart';
import '../../../core/theme/components/constrained_fab_location.dart';
import '../../../core/providers/memory_provider.dart';
import 'memory_form_page.dart';
import '../../core/theme/components/smart_image.dart';
import 'widgets/animated_card.dart';
import 'widgets/awards_card.dart';
import 'widgets/circle_button.dart';
import 'widgets/hero_header.dart';
import 'widgets/icon_box.dart';
import 'widgets/location_section.dart';
import 'widgets/rating_card.dart';
import 'widgets/section_title.dart';
import 'widgets/variedades_card.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/theme/tokens/app_animation.dart';

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

    // Antes se apagaba aquí `dockVisibleProvider` y NO se volvía a encender
    // en dispose(): al volver de un recuerdo, Inicio se quedaba sin barra de
    // navegación hasta que el usuario hacía scroll hacia arriba — y si la
    // lista era corta y no había scroll posible, hasta reiniciar la app.
    // Esta pantalla se pinta fuera del shell, así que el dock no se ve aquí
    // de todas formas: no hay nada que apagar.

    _animationController = AnimationController(
      vsync: this,
      duration: AppAnimation.slow,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: AppAnimation.enter,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: AppAnimation.enter,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
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
      _animationController.value = 1.0;
    }
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
          ..remove('variedades')
          // FUERA LOS HUECOS.
          //
          // Al desmarcar un chip, el formulario no borra la clave: la pone
          // a `null`, y así viaja a Firestore. Aquí eso hacía que
          // `extraFields.isNotEmpty` fuera cierto, se pintara la cabecera
          // "DETALLES DE LA EXPERIENCIA" con su icono... y debajo no hubiera
          // nada, porque cada fila devuelve un widget vacío. Una sección
          // entera anunciando contenido que no existe.
          //
          // Lo mismo con una selección múltiple que se ha vaciado (`[]`) o
          // con un texto que quedó en blanco.
          ..removeWhere(
            (String key, dynamic value) =>
                value == null ||
                (value is String && value.trim().isEmpty) ||
                (value is Iterable && value.isEmpty) ||
                (value is Map && value.isEmpty),
          );

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
      backgroundColor: AppColors.background,
      floatingActionButtonLocation: const ConstrainedEndFloatLocation(),
      floatingActionButton: _buildFloatingEditButton(context, currentMemory),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              HeroHeader(
                memory: currentMemory,
                firstImageUrl: firstImageUrl,
                onBack: () => Navigator.pop(context),
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
                        awardsFor(currentMemory.specificFields),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    List<MemoryAward> awards,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceWarm,
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

          // ── Lo que este sitio se ganó solo ──
          //
          // Salen de las respuestas del formulario, no de una nota que
          // alguien pone a mano, y por eso significan algo cuando aparecen.
          // Lo normal es que no aparezca ninguno.
          //
          // El motor llevaba escrito desde el principio en
          // `features/memory_results/`, una carpeta que no importaba nadie:
          // terminado, con sus condiciones bien puestas, y sin ejecutarse
          // nunca porque no había pantalla que lo llamara.
          if (awards.isNotEmpty) ...<Widget>[
            AwardsCard(awards: awards),
            const SizedBox(height: 20),
          ],

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

          // Hueco para el botón flotante de "Editar".
          //
          // Sin esto, el botón se queda encima de la última tarjeta y no hay
          // forma de apartarlo: el contenido termina justo debajo de él, así
          // que la esquina de la última tarjeta es inalcanzable. Se ve en
          // cuanto abres un recuerdo con pocos datos. El hueco es el alto del
          // botón más su margen, y el área segura del teléfono.
          SizedBox(height: 88 + MediaQuery.viewPaddingOf(context).bottom),
        ],
      ),
    );
  }

  // Esta vista no es un bottom sheet y no se puede arrastrar: el asa
  // invitaba a un gesto que no existe.
  Widget _buildDragHandle() => const SizedBox(height: 4);

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
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.textPrimary, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.textPrimary,
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
      duration: AppAnimation.slow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // Tinte de `success` para "sí volvería"; el naranja de "no" no
        // tiene un token equivalente (no es un error, es una preferencia)
        // así que se queda como valor propio, documentado, a la espera de
        // que aparezca un segundo caso que justifique un token nuevo.
        // Opaco. Ver AppColors.tintSuccess: con alpha, la sombra maciza
        // se veía a través y esta tarjeta salía casi negra, con el texto
        // encima a 1,11:1 — ilegible.
        color: wouldReturn ? AppColors.tintSuccess : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.textPrimary, width: 2),
      ),
      // El pulgar era la única forma de saberlo: sin texto y sin
      // `Semantics`, para un lector de pantalla este recuadro no existía.
      // La tarjeta de puntuación de al lado sí lo hacía bien.
      child: Semantics(
        label: wouldReturn ? 'Volverías a este sitio' : 'No volverías',
        child: ExcludeSemantics(
          child: Icon(
            wouldReturn ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(MemoryModel memory) {
    return AnimatedCard(
      child: Row(
        children: [
          const IconBox(
            icon: Icons.storefront_rounded,
            backgroundColor: AppColors.primary,
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
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  memory.restaurantName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
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
                backgroundColor: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'DETALLES DE LA EXPERIENCIA',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
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
              duration: AppAnimation.stagger(index, stepMs: 55),
              curve: AppAnimation.enter,
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
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.12),
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
                color: AppColors.textSecondary,
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
                color: AppColors.textPrimary,
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
                    ? AppColors.primary
                    : AppColors.textMuted,
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
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
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
      duration: AppAnimation.slow,
      curve: AppAnimation.enter,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // Opaco. Ver AppColors.tintSuccess: con alpha, la sombra maciza
        // se veía a través y esta tarjeta salía casi negra, con el texto
        // encima a 1,11:1 — ilegible.
        color: wouldReturn ? AppColors.tintSuccess : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.textPrimary, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.textPrimary,
            blurRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: AppAnimation.standard,
            child: Container(
              key: ValueKey(wouldReturn),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textPrimary, width: 2),
              ),
              child: Icon(
                wouldReturn ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                size: 20,
                color: AppColors.textPrimary,
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
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // El formulario solo ofrece "Sí" y "No"; quien pulsaba
                  // "No" leía aquí "No tengo claro si volvería", que no es
                  // lo que había contestado.
                  wouldReturn
                      ? '¡Sí volvería a este lugar sin duda!'
                      : 'No volvería',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
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
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      onPressed: () => _openEditPage(context, memory),
      icon: const Icon(Icons.edit_rounded, size: 19),
      label: Text(
        'Editar',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.textPrimary, width: 2),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 2, color: AppColors.textPrimary)),
        const SizedBox(width: 12),
        const Icon(
          Icons.restaurant_rounded,
          size: 18,
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 2, color: AppColors.textPrimary)),
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
        transitionDuration: AppAnimation.slow,
        reverseTransitionDuration: AppAnimation.standard,
        pageBuilder: (context, animation, secondaryAnimation) {
          return MemoryFormPage(memory: memory);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            AppMotion.pageIn(
              animation,
              child,
              from: const Offset(0, 0.04),
            ),
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: AppAnimation.slow,
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
                          // Aquí sí se amplía con los dedos, así que se
                          // pide bastante más que en la cabecera — pero con
                          // tope, no la foto original: `SmartImage` corta en
                          // 1600 px, que es donde un móvil deja de notar la
                          // diferencia.
                          width: 800,
                          semanticLabel: 'Foto de ${widget.memory.title}',
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
