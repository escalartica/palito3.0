
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/data/categories.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/theme/components/constrained_fab_location.dart';
import '../../../core/theme/components/home_widgets.dart';
import '../../../core/theme/components/memory_card.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/dock_provider.dart';

// ===========================================================================
// PALETA (alias locales sobre AppColors, la fuente única de verdad — ver
// core/theme/tokens/app_colors.dart)
// ===========================================================================

const Color colorBackground = AppColors.background;
const Color colorCardSurface = AppColors.surface;
const Color colorTextMain = AppColors.textPrimary;
const Color colorAccentCoral = AppColors.accent;

// ===========================================================================
// HOME PAGE
// ===========================================================================

class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  // =========================================================================
  // CONTROLADOR PRINCIPAL DE ENTRADA
  // =========================================================================

  late final AnimationController _entryController;

  // =========================================================================
  // ANIMACIONES
  // =========================================================================

  late final Animation<double> _headerAnimation;
  late final Animation<double> _heroAnimation;
  late final Animation<double> _sectionAnimation;
  late final Animation<double> _filtersAnimation;
  late final Animation<double> _fabAnimation;

  // =========================================================================
  // ORDEN DE MEMORIAS
  // =========================================================================
  //
  // false:
  // Mayor puntuación → menor puntuación.
  //
  // true:
  // Menor puntuación → mayor puntuación.
  //
  // Este estado solo afecta al orden visual de Inicio.
  // No modifica Firestore ni StorageService.

  bool _sortRatingAscending = false;

  @override
  void initState() {
    super.initState();

    // =========================================================================
    // CONTROLADOR DE ENTRADA
    // =========================================================================
    //
    // La pantalla no aparece toda de golpe.
    //
    // Cada bloque tiene su propio intervalo dentro de esta animación.
    // Esto genera una entrada escalonada y mucho más natural.

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1100,
      ),
    );

    // =========================================================================
    // CABECERA
    // =========================================================================

    _headerAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(
        0.00,
        0.30,
        curve: Curves.easeOutCubic,
      ),
    );

    // =========================================================================
    // HERO
    // =========================================================================

    _heroAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(
        0.12,
        0.48,
        curve: Curves.easeOutCubic,
      ),
    );

    // =========================================================================
    // CABECERA DE SECCIÓN
    // =========================================================================

    _sectionAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(
        0.32,
        0.58,
        curve: Curves.easeOutCubic,
      ),
    );

    // =========================================================================
    // FILTROS
    // =========================================================================

    _filtersAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(
        0.42,
        0.70,
        curve: Curves.easeOutCubic,
      ),
    );

    // =========================================================================
    // FAB
    // =========================================================================

    _fabAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(
        0.65,
        1.00,
        curve: Curves.easeOutBack,
      ),
    );

    // =========================================================================
    // INICIAR ANIMACIÓN
    // =========================================================================

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(
      memoryProvider,
    );

    // Evita el "flash" del estado vacío ("No hay experiencias guardadas")
    // durante el primer arranque, mientras la caché local / Firestore
    // todavía no han respondido — antes se mostraba brevemente como si
    // el usuario no tuviera ningún recuerdo, aunque sí los tuviera.
    final bool hasLoaded =
        memories.isNotEmpty ||
        ref.read(memoryProvider.notifier).hasReceivedFirestoreData;

    // Si Firestore está fallando (sin red, permisos, etc.) y todavía no
    // hay ningún recuerdo que mostrar (ni en caché local ni ya
    // recibido), esto evita que la pantalla se quede en "Cargando..."
    // para siempre sin que el usuario sepa que algo va mal.
    final bool hasStreamError =
        memories.isEmpty &&
        ref.read(memoryProvider.notifier).hasStreamError;

    final selectedCategory = ref.watch(
      selectedCategoryProvider,
    );

    // =========================================================================
    // FILTRADO POR CATEGORÍA
    // =========================================================================

    final filteredMemories = selectedCategory == "Todos"
        ? List.of(memories)
        : memories
            .where(
              (memory) =>
                  memory.category == selectedCategory,
            )
            .toList();

    // =========================================================================
    // ORDENACIÓN POR PUNTUACIÓN
    // =========================================================================

    filteredMemories.sort(
      (a, b) {
        final int ratingComparison =
            _sortRatingAscending
                ? a.rating.compareTo(
                    b.rating,
                  )
                : b.rating.compareTo(
                    a.rating,
                  );

        if (ratingComparison != 0) {
          return ratingComparison;
        }

        // La más reciente aparece primero
        // en caso de empate.

        return b.date.compareTo(
          a.date,
        );
      },
    );

    // =========================================================================
    // RECUERDO DESTACADO (PORTADA)
    // =========================================================================
    //
    // La portada es lo primero que ve el usuario, así que debe mostrar
    // siempre una foto real y apetecible en vez de forzar el mejor
    // valorado aunque no tenga foto (eso dejaba el hueco vacío en el sitio
    // más visible de la app). Se elige el mejor valorado QUE TENGA FOTO;
    // solo se cae al estado vacío si de verdad no hay ninguna foto en la
    // categoría seleccionada.
    final MemoryModel? heroMemory = filteredMemories.isEmpty
        ? null
        : filteredMemories.firstWhere(
            (memory) => memory.imageUrls.isNotEmpty,
            orElse: () => filteredMemories.first,
          );

    return Scaffold(
      backgroundColor: colorBackground,

      // =========================================================================
      // STACK PRINCIPAL
      // =========================================================================
      //
      // Center + ConstrainedBox: en móvil (donde el ancho ya es menor que
      // el máximo) no cambia nada; en la PWA de escritorio evita que el
      // contenido se estire a lo ancho de toda la ventana. Ahora es
      // seguro: el FAB ya no vive dentro de este Stack (ver
      // floatingActionButton más abajo), así que no depende de cómo este
      // Stack calcule su tamaño.

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Stack(
        children: [
          // =====================================================================
          // CONTENIDO PRINCIPAL
          // =====================================================================

          NotificationListener<UserScrollNotification>(
            onNotification: (
              notification,
            ) {
              if (notification.direction ==
                  ScrollDirection.reverse) {
                ref
                    .read(
                      dockVisibleProvider.notifier,
                    )
                    .state = false;
              } else if (notification.direction ==
                  ScrollDirection.forward) {
                ref
                    .read(
                      dockVisibleProvider.notifier,
                    )
                    .state = true;
              }

              return true;
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // =================================================================
                // CABECERA ANIMADA
                // =================================================================

                _buildSlideFadeTransition(
                  animation: _headerAnimation,
                  beginOffset: const Offset(
                    0,
                    -0.12,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        12,
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        crossAxisAlignment:
                            CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Palito de Sabores",
                                  style:
                                      GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight:
                                        FontWeight.bold,
                                    color:
                                        colorTextMain,
                                    letterSpacing:
                                        -0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // =====================================================
                          // LOGOTIPO
                          // =====================================================

                          Container(
                            decoration:
                                BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(
                                22,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(
                                    alpha: 0.10,
                                  ),
                                  blurRadius: 16,
                                  offset:
                                      const Offset(
                                    0,
                                    6,
                                  ),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                0,
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // =================================================================
                // HERO ANIMADO
                // =================================================================

                _buildSlideFadeTransition(
                  animation: _heroAnimation,
                  beginOffset: const Offset(
                    0,
                    0.10,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: SizedBox(
                      height:
                          MediaQuery.of(context)
                                  .size
                                  .height *
                              0.34,
                      child: HomeHero(
                        memory: heroMemory,
                      ),
                    ),
                  ),
                ),

                // =================================================================
                // CABECERA DE SECCIÓN
                // =================================================================

                _buildSlideFadeTransition(
                  animation: _sectionAnimation,
                  beginOffset: const Offset(
                    0,
                    0.08,
                  ),
                  child: _buildSectionHeader(
                    "Últimos Registros",
                  ),
                ),

                // =================================================================
                // FILTROS
                // =================================================================

                _buildSlideFadeTransition(
                  animation: _filtersAnimation,
                  beginOffset: const Offset(
                    0,
                    0.08,
                  ),
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection:
                          Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      children: [
                        _buildFilterChip(
                          "Todos",
                          selectedCategory,
                          ref,
                        ),
                        ...gastronomicCategories.map(
                          (
                            cat,
                          ) =>
                              _buildFilterChip(
                            cat.name,
                            selectedCategory,
                            ref,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                // =================================================================
                // LISTADO DE MEMORIAS
                // =================================================================

                filteredMemories.isEmpty
                    ? (hasStreamError
                          ? _buildErrorState()
                          : (hasLoaded
                                ? _buildEmptyState()
                                : _buildLoadingState()))
                    : Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        child: Column(
                          children:
                              filteredMemories
                                  .asMap()
                                  .entries
                                  .map(
                            (
                              entry,
                            ) {
                              final index =
                                  entry.key;

                              final memory =
                                  entry.value;

                              return _buildAnimatedMemoryCard(
                                memory: memory,
                                index: index,
                              );
                            },
                          ).toList(),
                        ),
                      ),

                // =================================================================
                // ESPACIO PARA DOCK + FAB
                // =================================================================

                const SizedBox(
                  height: 300,
                ),
              ],
            ),
          ),

        ],
      ),
        ),
      ),

      // =========================================================================
      // FAB ANIMADO
      // =========================================================================
      //
      // Vive en el slot floatingActionButton de Scaffold, no como
      // Positioned manual dentro del Stack del body — así su posición no
      // depende de cómo el Stack calcule su propio tamaño (antes, un
      // Positioned(bottom: 125) aquí se recortaba fuera de la pantalla
      // en cuanto el body se envolvía en un ancho máximo para la PWA de
      // escritorio; ver UX-3 en TECHNICAL_AUDIT.md).
      floatingActionButtonLocation:
          const ConstrainedEndFloatLocation(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: 109,
        ),
        child: ScaleTransition(
          scale: _fabAnimation,
          child: FadeTransition(
            opacity: _fabAnimation,
            child: Container(
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorTextMain,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorTextMain,
                    blurRadius: 0,
                    offset:
                        const Offset(
                      3,
                      3,
                    ),
                  ),
                ],
              ),
              child:
                  FloatingActionButton(
                backgroundColor:
                    colorAccentCoral,
                elevation: 0,
                onPressed: () =>
                    context.push(
                  '/new-memory',
                ),
                shape:
                    const CircleBorder(),
                child:
                    const Icon(
                  Icons.add_rounded,
                  color:
                      Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ANIMACIÓN GENÉRICA SLIDE + FADE
  // ===========================================================================

  Widget _buildSlideFadeTransition({
    required Animation<double> animation,
    required Offset beginOffset,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (
        context,
        child,
      ) {
        final curvedValue =
            animation.value;

        final offset = Offset(
          beginOffset.dx *
              (1 - curvedValue),
          beginOffset.dy *
              (1 - curvedValue),
        );

        return Opacity(
          opacity: curvedValue,
          child: Transform.translate(
            offset: Offset(
              offset.dx * 60,
              offset.dy * 60,
            ),
            child: child,
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TARJETA DE MEMORIA ANIMADA
  // ===========================================================================

  // ===========================================================================
  // CONFIRMACIÓN DE BORRADO
  // ===========================================================================
  //
  // El swipe-to-delete es fácil de disparar sin querer mientras se hace
  // scroll por la lista (un gesto ligeramente diagonal). Por eso el borrado
  // real solo ocurre si el usuario confirma explícitamente en este diálogo.

  Future<bool> _confirmDeleteMemory(
    dynamic memory,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: colorTextMain.withValues(alpha: 0.55),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorTextMain, width: 2),
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
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorTextMain, width: 2),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Eliminar recuerdo?',
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: colorTextMain,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.4,
                    color: colorTextMain.withValues(alpha: 0.75),
                  ),
                  children: [
                    const TextSpan(text: '"'),
                    TextSpan(
                      text: memory.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(
                      text: '" se eliminará permanentemente. '
                          'Esta acción no se puede deshacer.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _buildDialogButton(
                      label: 'Cancelar',
                      backgroundColor: Colors.white,
                      textColor: colorTextMain,
                      onTap: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDialogButton(
                      label: 'Eliminar',
                      backgroundColor: colorAccentCoral,
                      textColor: Colors.white,
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

  Widget _buildDialogButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorTextMain, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF0F172A),
              blurRadius: 0,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMemoryCard({
    required dynamic memory,
    required int index,
  }) {
    // Cada tarjeta tiene un retraso progresivo.
    //
    // Las primeras entran ligeramente antes.
    // Las siguientes aparecen progresivamente.
    //
    // Limitamos el retraso para que una lista muy larga
    // no haga esperar demasiado al usuario.

    final double start =
        (0.55 + (index * 0.045))
            .clamp(
              0.55,
              0.82,
            );

    final double end =
        (start + 0.25)
            .clamp(
              0.70,
              1.00,
            );

    final Animation<double>
        cardAnimation =
        CurvedAnimation(
      parent: _entryController,
      curve: Interval(
        start,
        end,
        curve:
            Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: cardAnimation,
      builder: (
        context,
        child,
      ) {
        final value =
            cardAnimation.value;

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              0,
              28 * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: Padding(
        padding:
            const EdgeInsets.only(
          bottom: 10,
        ),
        child: Dismissible(
          key: Key(
            memory.id,
          ),
          direction:
              DismissDirection
                  .endToStart,
          confirmDismiss: (
            _,
          ) =>
              _confirmDeleteMemory(
            memory,
          ),
          onDismissed: (
            _,
          ) =>
              ref
                  .read(
                    memoryProvider
                        .notifier,
                  )
                  .removeMemory(
                    memory.id,
                  ),
          background:
              Container(
            alignment:
                Alignment.centerRight,
            padding:
                const EdgeInsets.only(
              right: 20,
            ),
            decoration:
                BoxDecoration(
              color:
                  Colors.red.shade400,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),
            child:
                const Icon(
              Icons
                  .delete_outline_rounded,
              color:
                  Colors.white,
              size: 24,
            ),
          ),
          child:
              MemoryCardCompact(
            memory:
                memory,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ESTADO VACÍO
  // ===========================================================================

  Widget _buildEmptyState() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 20,
      ),
      child: Center(
        child: Container(
          width:
              double.infinity,
          padding:
              const EdgeInsets.all(
            28,
          ),
          decoration: BoxDecoration(
            color: colorCardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorTextMain, width: 2),
            boxShadow: [
              BoxShadow(
                color: colorTextMain,
                blurRadius: 0,
                offset: const Offset(3, 3),
              ),
            ],
          ),
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons
                    .restaurant_menu_rounded,
                size: 32,
                color:
                    Colors.grey
                        .shade400,
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                "No hay experiencias guardadas aquí",
                style:
                    GoogleFonts.outfit(
                  color:
                      colorTextMain,
                  fontWeight:
                      FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ESTADO DE ERROR
  // ===========================================================================
  //
  // Antes, si el stream de Firestore fallaba (sin red, reglas de
  // seguridad rechazando el acceso, etc.) y no había nada en caché
  // local, la pantalla se quedaba en "Cargando tus recuerdos..." para
  // siempre, sin ningún indicio de que algo iba mal. Mismo contenedor
  // visual que el estado vacío, para no introducir un salto de layout.

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 20,
      ),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: colorCardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorTextMain, width: 2),
            boxShadow: [
              BoxShadow(
                color: colorTextMain,
                blurRadius: 0,
                offset: const Offset(3, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 32,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 10),
              Text(
                "No se pudieron cargar tus recuerdos",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: colorTextMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Comprueba tu conexión — se actualizará solo en cuanto vuelva.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ESTADO DE CARGA
  // ===========================================================================
  //
  // Mismo contenedor visual que el estado vacío, para que no haya un salto
  // brusco de layout cuando los datos terminan de llegar.

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 20,
      ),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: colorCardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorTextMain, width: 2),
            boxShadow: [
              BoxShadow(
                color: colorTextMain,
                blurRadius: 0,
                offset: const Offset(3, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorAccentCoral,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Cargando tus recuerdos...",
                style: GoogleFonts.outfit(
                  color: colorTextMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // CABECERA DE SECCIÓN
  // ===========================================================================

  Widget _buildSectionHeader(
    String title,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        8,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [
          Text(
            title,
            style:
                GoogleFonts.outfit(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color:
                  colorTextMain,
              letterSpacing:
                  -0.3,
            ),
          ),

          // ===================================================================
          // BOTÓN DE ORDENACIÓN
          // ===================================================================

          Material(
            color:
                Colors.transparent,
            child:
                InkWell(
              onTap: () {
                setState(() {
                  _sortRatingAscending =
                      !_sortRatingAscending;
                });
              },
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
              child:
                  Padding(
                padding:
                    const EdgeInsets.all(
                  6,
                ),
                child:
                    Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration:
                          const Duration(
                        milliseconds:
                            250,
                      ),
                      transitionBuilder:
                          (
                        child,
                        animation,
                      ) {
                        return ScaleTransition(
                          scale:
                              animation,
                          child:
                              child,
                        );
                      },
                      child:
                          Icon(
                        _sortRatingAscending
                            ? Icons
                                .south_rounded
                            : Icons
                                .north_rounded,
                        key:
                            ValueKey(
                          _sortRatingAscending,
                        ),
                        size:
                            20,
                        color:
                            colorAccentCoral,
                      ),
                    ),
                    const SizedBox(
                      width: 2,
                    ),
                    const Icon(
                      Icons
                          .star_rounded,
                      size: 17,
                      color:
                          colorAccentCoral,
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

  // ===========================================================================
  // FILTRO DE CATEGORÍA
  // ===========================================================================

  Widget _buildFilterChip(
    String label,
    String selected,
    WidgetRef ref,
  ) {
    final bool isSelected =
        label == selected;

    return Padding(
      padding:
          const EdgeInsets.only(
        right: 8,
      ),
      child:
          GestureDetector(
        onTap: () {
          ref
              .read(
                selectedCategoryProvider
                    .notifier,
              )
              .state = label;
        },
        child:
            AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 250,
          ),
          curve:
              Curves.easeOutCubic,
          alignment:
              Alignment.center,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          decoration:
              BoxDecoration(
            color: isSelected
                ? colorTextMain
                : colorCardSurface,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black
                        .withValues(
                  alpha:
                      isSelected
                          ? 0.12
                          : 0.03,
                ),
                blurRadius:
                    isSelected
                        ? 6
                        : 4,
                offset:
                    const Offset(
                  0,
                  2,
                ),
              ),
            ],
          ),
          child:
              Text(
            label,
            style:
                GoogleFonts.outfit(
              color: isSelected
                  ? Colors.white
                  : Colors
                      .grey
                      .shade700,
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

