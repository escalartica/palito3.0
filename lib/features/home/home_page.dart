import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/data/categories.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/theme/components/app_dock.dart';
import '../../../core/theme/components/constrained_fab_location.dart';
import '../../../core/theme/components/group_switcher.dart';
import '../../../core/theme/components/home_widgets.dart';
import '../../../core/theme/components/memory_card.dart';
import '../../../core/theme/components/neo_pressable.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/dock_provider.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/theme/tokens/app_animation.dart';
import '../../core/theme/components/app_motion.dart';
import '../../core/theme/components/category_chip.dart';

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
  const HomePage({super.key});

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

  /// Por qué se ordena la lista.
  ///
  /// Antes era un `bool` —nota de mayor a menor, o al revés— y no había
  /// forma de ordenar por fecha. En un diario de comidas eso es raro: la
  /// cabecera dice "Últimos registros" y lo que había debajo era un ranking
  /// por nota, así que "últimos" no significaba nada. Y el "cuándo" no
  /// aparecía en ninguna parte de la pantalla.
  _SortMode _sortMode = _SortMode.recent;

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
      duration: AppAnimation.entry,
    );

    // =========================================================================
    // CABECERA
    // =========================================================================

    _headerAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.00, 0.30, curve: AppAnimation.enter),
    );

    // =========================================================================
    // HERO
    // =========================================================================

    _heroAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.12, 0.48, curve: AppAnimation.enter),
    );

    // =========================================================================
    // CABECERA DE SECCIÓN
    // =========================================================================

    _sectionAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.32, 0.58, curve: AppAnimation.enter),
    );

    // =========================================================================
    // FILTROS
    // =========================================================================

    _filtersAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.42, 0.70, curve: AppAnimation.enter),
    );

    // =========================================================================
    // FAB
    // =========================================================================

    _fabAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.65, 1.00, curve: AppAnimation.pop),
    );

    // =========================================================================
    // INICIAR ANIMACIÓN
    // =========================================================================

    _entryController.forward();
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
      _entryController.value = 1.0;
    }
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
    final memories = ref.watch(memoryProvider);

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
        memories.isEmpty && ref.read(memoryProvider.notifier).hasStreamError;

    final bool isPermissionDenied = ref
        .read(memoryProvider.notifier)
        .isPermissionDenied;

    final selectedCategory = ref.watch(selectedCategoryProvider);

    // =========================================================================
    // FILTRADO POR CATEGORÍA
    // =========================================================================

    final filteredMemories = selectedCategory == "Todos"
        ? List.of(memories)
        : memories
              .where((memory) => memory.category == selectedCategory)
              .toList();

    // =========================================================================
    // ORDENACIÓN POR PUNTUACIÓN
    // =========================================================================

    filteredMemories.sort((MemoryModel a, MemoryModel b) {
      if (_sortMode == _SortMode.recent) return b.date.compareTo(a.date);

      final int ratingComparison = _sortMode == _SortMode.ratingAsc
          ? a.rating.compareTo(b.rating)
          : b.rating.compareTo(a.rating);

      if (ratingComparison != 0) return ratingComparison;

      // La más reciente primero en caso de empate.
      return b.date.compareTo(a.date);
    });

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
    // EL DESTACADO ES EL MEJOR, NO EL PRIMERO DE LA LISTA.
    //
    // Esto era `filteredMemories.firstWhere(tiene foto)`, y
    // `filteredMemories` ya viene ordenada según el botón "Nota" de la
    // cabecera. Al invertir el orden a ascendente, el primero con foto pasa
    // a ser **el peor valorado de todos** — y la app lo corona con el
    // rótulo "PLATO ESTRELLA". Un titular que cambia de significado según
    // cómo esté ordenada la lista de abajo no es un titular.
    //
    // Ahora se busca el de nota más alta con foto, pase lo que pase con el
    // orden visual. Y si ninguno tiene foto no se cae al primero: sin foto
    // la tarjeta no se puede pintar (ver abajo), así que se devuelve null y
    // sale el estado vacío, que sí está escrito para eso.
    MemoryModel? best;
    for (final MemoryModel memory in filteredMemories) {
      if (memory.imageUrls.isEmpty) continue;
      if (best == null || memory.rating > best.rating) best = memory;
    }
    final MemoryModel? heroMemory = best;

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
                onNotification: (notification) {
                  if (notification.direction == ScrollDirection.reverse) {
                    ref.read(dockVisibleProvider.notifier).state = false;
                  } else if (notification.direction ==
                      ScrollDirection.forward) {
                    ref.read(dockVisibleProvider.notifier).state = true;
                  }

                  return true;
                },
                // ── Por qué CustomScrollView y no ListView ──
                //
                // Esto era un `ListView(children: [...])` con TODAS las
                // tarjetas de recuerdos dentro de un `Column`. Un `Column`
                // mide y coloca a todos sus hijos a la vez, siempre: no hay
                // pereza que valga. Con doscientos recuerdos guardados se
                // construían, medían y pintaban doscientas tarjetas en cada
                // reconstrucción de la pantalla — y la pantalla se
                // reconstruye al filtrar, al ordenar y cada vez que el dock
                // se esconde al hacer scroll.
                //
                // Quien más recuerdos tiene es justo quien más usa la app, o
                // sea que el fallo castigaba precisamente a los mejores
                // usuarios. Con `SliverList.builder` solo existen las
                // tarjetas que caben en pantalla más un poco de margen.
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: Column(
                        // `stretch` porque un ListView ya daba a sus hijos el
                        // ancho completo; un Column, por defecto, los
                        // centraría y todo se estrecharía de golpe.
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // =================================================================
                          // CABECERA ANIMADA
                          // =================================================================
                          _buildSlideFadeTransition(
                            animation: _headerAnimation,
                            beginOffset: const Offset(0, -0.12),
                            child: SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  12,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // El titular de Inicio ya no repite el nombre
                                    // de la app —que el usuario acaba de tocar para
                                    // abrirla, y que está en el logotipo de al
                                    // lado—: ahora es el nombre del DIARIO que
                                    // estás viendo, que es el dato que cambia todo
                                    // lo que hay debajo. Ver GroupSwitcher.
                                    const Expanded(child: GroupSwitcher()),

                                    // =====================================================
                                    // LOGOTIPO
                                    // =====================================================
                                    // Único logotipo de la app: sombra suave
                                    // (no la "sticker" del resto de la interfaz)
                                    // porque aquí se lee como marca, no como
                                    // superficie pulsable. Excepción deliberada al
                                    // sistema de radios: el PNG ya trae sus
                                    // propias esquinas redondeadas, así que no se
                                    // reclipa (radio 0) para no duplicar la curva.
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.textPrimary
                                                .withValues(alpha: 0.10),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(0),
                                        child: Image.asset(
                                          'assets/images/logo.png',
                                          semanticLabel:
                                              'Logotipo de Palito de Sabores',
                                          width: 64,
                                          height: 64,
                                          // El PNG mide 607×622 y se pintaba
                                          // entero en memoria —1,5 MB— para
                                          // un hueco de 64 dp. `neo_header`
                                          // ya lo hacía bien con el mismo
                                          // fichero; aquí faltaba.
                                          cacheWidth: 192,
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
                          //
                          // Solo cuando hay algo que destacar. Con el diario vacío,
                          // la portada era un marcador de posición de 200 px —"Tu
                          // mejor plato aparecerá aquí"— justo encima de OTRO
                          // estado vacío, el de la lista. Dos carteles seguidos
                          // diciendo que no hay nada, y entre los dos empujaban el
                          // botón de "Añadir tu primer recuerdo" por debajo del
                          // dock. Con el diario vacío, la tarjeta de bienvenida es
                          // la portada.
                          if (heroMemory != null)
                            _buildSlideFadeTransition(
                              animation: _heroAnimation,
                              beginOffset: const Offset(0, 0.10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: SizedBox(
                                  // `sizeOf` no reconstruye al abrir el teclado, y
                                  // el clamp evita que en un iPhone SE quede una
                                  // tarjeta aplastada o, en una tablet,
                                  // desproporcionada.
                                  height:
                                      (MediaQuery.sizeOf(context).height * 0.34)
                                          .clamp(190.0, 300.0)
                                          .toDouble(),
                                  child: HomeHero(memory: heroMemory),
                                ),
                              ),
                            ),

                          // =================================================================
                          // CABECERA DE SECCIÓN
                          // =================================================================
                          _buildSlideFadeTransition(
                            animation: _sectionAnimation,
                            beginOffset: const Offset(0, 0.08),
                            // "Últimos registros" era falso: la lista se
                            // ordenaba por nota, no por fecha. Ahora el orden
                            // se elige al lado y puede ser cualquiera de tres,
                            // así que la cabecera dice lo único que es
                            // siempre cierto.
                            child: _buildSectionHeader('Tus recuerdos'),
                          ),

                          // =================================================================
                          // FILTROS
                          // =================================================================
                          _buildSlideFadeTransition(
                            animation: _filtersAnimation,
                            beginOffset: const Offset(0, 0.08),
                            child: SizedBox(
                              // 48 px: objetivo táctil mínimo. Con 38 los filtros eran
                              // casi imposibles de acertar.
                              height: 48,
                              // La fila de categorías se desplaza, pero nada lo
                              // decía: la última quedaba partida por la mitad
                              // contra el borde de la pantalla y se leía como un
                              // fallo de maquetación, no como "hay más a la
                              // derecha". El desvanecido del borde derecho es la
                              // señal universal de "esto continúa"; desaparece solo
                              // cuando llegas al final de la fila.
                              child: ShaderMask(
                                shaderCallback: (Rect bounds) =>
                                    const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      stops: <double>[0.0, 0.88, 1.0],
                                      colors: <Color>[
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                    ).createShader(bounds),
                                blendMode: BlendMode.dstIn,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 28,
                                  ),
                                  children: [
                                    _buildFilterChip(
                                      "Todos",
                                      selectedCategory,
                                      ref,
                                    ),
                                    ...gastronomicCategories.map(
                                      (cat) => _buildFilterChip(
                                        cat.name,
                                        selectedCategory,
                                        ref,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // =================================================================
                          // LISTADO DE MEMORIAS
                          // =================================================================
                          // Sin recuerdos que listar, aquí va el estado que toque
                          // — error, vacío o cargando. Es un bloque suelto, así que
                          // se queda dentro de la cabecera.
                          if (filteredMemories.isEmpty)
                            hasStreamError
                                ? _buildErrorState(isPermissionDenied)
                                : (hasLoaded
                                      ? _buildEmptyState(
                                          selectedCategory,
                                          memories.isNotEmpty,
                                        )
                                      : _buildLoadingState()),
                        ],
                      ),
                    ),

                    // =================================================================
                    // LISTADO DE RECUERDOS — perezoso
                    // =================================================================
                    if (filteredMemories.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: filteredMemories.length,
                          itemBuilder: (BuildContext context, int index) =>
                              _buildAnimatedMemoryCard(
                                memory: filteredMemories[index],
                                index: index,
                              ),
                        ),
                      ),

                    // =================================================================
                    // ESPACIO PARA DOCK + FAB
                    // =================================================================

                    // Hueco para que la última tarjeta no quede debajo del dock
                    // ni del FAB. Antes era un 300 fijo sin relación con nada.
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height:
                            AppDock.height +
                            96 +
                            MediaQuery.viewPaddingOf(context).bottom,
                      ),
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
      floatingActionButtonLocation: const ConstrainedEndFloatLocation(),
      // El hueco inferior se deriva del alto real del dock (AppDock.height)
      // más el área segura, en vez de un 109 mágico que no cuadraba con los
      // dos márgenes de 24 que el dock tenía sumados sin saberlo.
      // Sin recuerdos que listar no hay FAB: la tarjeta de estado vacío ya
      // lleva su propio botón "Añadir tu primer recuerdo", a ancho completo y
      // con su nombre escrito. Tener los dos a la vez era peor que redundante
      // — el redondo se montaba justo encima de la esquina de la tarjeta y
      // parecía un error de montaje, no un botón.
      floatingActionButton: filteredMemories.isEmpty
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom:
                    AppDock.height +
                    20 +
                    MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: AnimatedSlide(
                // El FAB no se escondía al hacer scroll aunque el dock sí: se
                // quedaba solo, flotando sobre la lista.
                offset: ref.watch(dockVisibleProvider)
                    ? Offset.zero
                    : const Offset(0, 2),
                duration: AppAnimation.slow,
                curve: AppAnimation.enter,
                child: ScaleTransition(
                  // Desde el 82 %, no desde cero: el boton no sale de la nada, se
                  // coloca. Con `_fabAnimation` pelada crecia desde un punto.
                  scale: Tween<double>(
                    begin: 0.82,
                    end: 1.0,
                  ).animate(_fabAnimation),
                  child: FadeTransition(
                    opacity: _fabAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colorTextMain, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: colorTextMain,
                            blurRadius: 0,
                            offset: const Offset(3, 3),
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        backgroundColor: colorAccentCoral,
                        elevation: 0,
                        // Sin tooltip, VoiceOver anunciaba solo "botón".
                        tooltip: 'Añadir un recuerdo nuevo',
                        onPressed: () => context.push('/new-memory'),
                        shape: const CircleBorder(),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
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
      builder: (context, child) {
        final curvedValue = animation.value;

        final offset = Offset(
          beginOffset.dx * (1 - curvedValue),
          beginOffset.dy * (1 - curvedValue),
        );

        return Opacity(
          opacity: curvedValue,
          child: Transform.translate(
            offset: Offset(offset.dx * 60, offset.dy * 60),
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

  Future<bool> _confirmDeleteMemory(dynamic memory) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: colorTextMain.withValues(alpha: 0.55),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceWarm,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colorTextMain, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.textPrimary,
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
                  color: AppColors.tintError,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorTextMain, width: 2),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
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
                      text:
                          '" se eliminará permanentemente. '
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
                      // Blanco sobre el coral de marca mide 3,31:1. El minimo
                      // de WCAG AA para texto es 4,5:1, y este rotulo no llega
                      // al tamano que permitiria bajar a 3:1. El navy mide
                      // 5,39:1 sobre el mismo coral.
                      textColor: AppColors.onAccent,
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
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: colorTextMain, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: AppColors.textPrimary,
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

    final double start = (0.55 + (index * 0.045)).clamp(0.55, 0.82);

    final double end = (start + 0.25).clamp(0.70, 1.00);

    // `drive`, no `CurvedAnimation`.
    //
    // `CurvedAnimation` registra un oyente en el controlador padre al
    // construirse y solo lo quita su `dispose()`. Este método se llama desde
    // el `itemBuilder` de la lista, así que cada tarjeta que entra y sale de
    // pantalla dejaba un oyente colgado de `_entryController`: recorrer
    // doscientos recuerdos arriba y abajo deja cientos, y ninguno se
    // desengancha nunca.
    //
    // `drive` devuelve una animación derivada que no se suscribe a nada por
    // su cuenta: se engancha cuando alguien la escucha —el `AnimatedBuilder`
    // de aquí abajo— y se desengancha sola cuando ese widget desaparece.
    final Animation<double> cardAnimation = _entryController.drive(
      CurveTween(curve: Interval(start, end, curve: AppAnimation.enter)),
    );

    return AnimatedBuilder(
      animation: cardAnimation,
      builder: (context, child) {
        final value = cardAnimation.value;

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 28 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Dismissible(
          key: Key(memory.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDeleteMemory(memory),
          onDismissed: (_) =>
              ref.read(memoryProvider.notifier).removeMemory(memory.id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.error,
              // Mismo radio que la tarjeta que desliza por encima
              // (NeoPressable borderRadius: 16 = AppRadius.md), para que
              // no se vea un borde cuadrado asomando en las esquinas.
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          child: MemoryCardCompact(memory: memory),
        ),
      ),
    );
  }

  // ===========================================================================
  // ESTADO VACÍO
  // ===========================================================================

  /// [selectedCategory] y [diaryHasMemories] distinguen dos situaciones
  /// que antes daban exactamente el mismo cartel:
  ///
  ///   • El diario está vacío de verdad → hay que explicar qué es esto y
  ///     ofrecer el primer paso.
  ///   • El diario tiene recuerdos, pero el FILTRO seleccionado no tiene
  ///     ninguno → decirle "apunta un sitio al que hayas ido" a alguien que
  ///     ya tiene veinte recuerdos guardados es desconcertante: lo que
  ///     necesita es saber que basta con volver a "Todos".
  Widget _buildEmptyState(String selectedCategory, bool diaryHasMemories) {
    final bool isFiltered = diaryHasMemories && selectedCategory != 'Todos';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        // Entrada suave (sin rebote: no es una celebración, solo evita que
        // el estado vacío aparezca de golpe la primera vez que se ve).
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: AppAnimation.slow,
          curve: AppAnimation.enter,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.95 + (0.05 * value),
                child: child,
              ),
            );
          },
          // ESTADO VACÍO CON SALIDA. Antes esto era un icono gris —en
          // `Colors.grey.shade400`, 1,9:1 de contraste, por debajo de
          // cualquier mínimo legible— y la frase "No hay experiencias
          // guardadas aquí". Constataba el problema y no ofrecía nada. Es la
          // primera pantalla que ve alguien que acaba de descargarse la app,
          // y la dejaba en un callejón sin salida: el único camino era
          // descubrir por su cuenta el botón redondo naranja de la esquina.
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: colorCardSurface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
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
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: colorTextMain, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: colorTextMain,
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    size: 28,
                    color: colorTextMain,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isFiltered
                      ? 'Nada en $selectedCategory todavía'
                      : 'Aquí no hay nada todavía',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: colorTextMain,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isFiltered
                      ? 'Tienes recuerdos guardados, pero ninguno en esta '
                            'categoría. Toca «Todos» ahí arriba para verlos '
                            'todos.'
                      : 'Apunta un sitio al que hayas ido: la tortilla, las '
                            'croquetas, la nota que le pondrías. Se guarda en '
                            'este diario y lo verá quien esté en él.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                // El mismo botón compartido que el resto de la app, con su
                // hundimiento al pulsar. Antes esto era un Material + InkWell
                // + Container montado a mano aquí mismo, que es de donde
                // salió el fallo del botón negro.
                NeoActionButton(
                  label: isFiltered
                      ? 'Añadir uno de $selectedCategory'
                      : 'Añadir tu primer recuerdo',
                  icon: Icons.add_rounded,
                  background: colorAccentCoral,
                  // Navy, no blanco: blanco sobre el coral de marca da 3,32:1
                  // y el mínimo para texto es 4,5:1. El navy da 5,12:1 sobre
                  // ese mismo coral, y además es el lenguaje de la app —texto
                  // oscuro sobre color— en todas partes menos aquí.
                  foreground: colorTextMain,
                  onTap: () => context.push('/new-memory'),
                ),
              ],
            ),
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

  Widget _buildErrorState(bool isPermissionDenied) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: AppAnimation.slow,
          curve: AppAnimation.enter,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.95 + (0.05 * value),
                child: child,
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colorCardSurface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  isPermissionDenied
                      ? Icons.lock_outline_rounded
                      : Icons.cloud_off_rounded,
                  size: 32,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 10),
                Text(
                  isPermissionDenied
                      ? "Ya no tienes acceso a este diario"
                      : "No se pudieron cargar tus recuerdos",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: colorTextMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // ANTES DECÍA: "Avisa para añadir este dispositivo a la
                  // lista autorizada."
                  //
                  // No existe ninguna lista autorizada, ni nadie a quien
                  // avisar: era vocabulario de una whitelist de desarrollo
                  // filtrado a una app publicada en la App Store. La persona
                  // que lo leía no tenía forma de saber qué hacer.
                  //
                  // `permission-denied` sobre los recuerdos significa una
                  // sola cosa: ya no eres miembro del grupo que estás
                  // mirando. O te han quitado, o el diario se ha borrado.
                  // Eso sí se puede contar, y tiene salida.
                  isPermissionDenied
                      ? "Puede que alguien te haya quitado de él, o que se "
                            "haya borrado. Tu diario personal sigue intacto."
                      : "Comprueba tu conexión — se actualizará solo en cuanto vuelva.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                // Una pantalla de error sin ningún botón es un callejón sin
                // salida: se mira y ya. Desde aquí se vuelve a un sitio que
                // seguro funciona.
                if (isPermissionDenied) ...<Widget>[
                  const SizedBox(height: 16),
                  NeoActionButton(
                    label: 'Ir a mi diario',
                    icon: Icons.menu_book_rounded,
                    background: AppColors.primary,
                    expand: false,
                    onTap: () => switchActiveGroup(ref, null),
                  ),
                ],
              ],
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: colorCardSurface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorTextMain,
              letterSpacing: -0.3,
            ),
          ),

          // ===================================================================
          // BOTÓN DE ORDENACIÓN
          // ===================================================================

          // Dos iconos sin etiqueta ni tooltip: ni un lector de pantalla ni
          // una persona vidente podían saber que esto ordena por puntuación.
          Tooltip(
            message: 'Cambiar el orden de la lista',
            child: Semantics(
              button: true,
              label:
                  'Ordenado por ${_sortMode.label}. '
                  'Tocar para ordenar por ${_sortMode.next.label}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _sortMode = _sortMode.next);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    // CON LA PALABRA ESCRITA. Antes eran una flecha y una
                    // estrella, los dos en coral, sin un solo carácter de
                    // texto. El tooltip y la etiqueta de VoiceOver ya estaban
                    // bien, pero quien mira la pantalla no ve tooltips: veía
                    // dos pictogramas en la esquina y no tenía forma de saber
                    // que aquello ordenaba la lista por nota.
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorCardSurface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: colorTextMain, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: colorTextMain,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: AppAnimation.fast,
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                                  return AppMotion.popIn(animation, child);
                                },
                            child: Row(
                              key: ValueKey<_SortMode>(_sortMode),
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  _sortMode.shortLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: colorTextMain,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _sortMode.icon,
                                  size: 15,
                                  color: colorAccentCoral,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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

  Widget _buildFilterChip(String label, String selected, WidgetRef ref) {
    final bool isSelected = label == selected;

    return CategoryChip(
      label: label,
      isSelected: isSelected,
      onTap: () {
        ref.read(selectedCategoryProvider.notifier).state = label;
      },
    );
  }
}

/// Los tres órdenes de la lista de Inicio, en un ciclo.
///
/// Un solo control que dice en palabras en qué orden está, en vez de dos
/// pictogramas que había que interpretar. Empieza por fecha, que es lo que
/// promete la cabecera de la sección.
enum _SortMode {
  recent,
  ratingDesc,
  ratingAsc;

  _SortMode get next => switch (this) {
    _SortMode.recent => _SortMode.ratingDesc,
    _SortMode.ratingDesc => _SortMode.ratingAsc,
    _SortMode.ratingAsc => _SortMode.recent,
  };

  String get shortLabel => switch (this) {
    _SortMode.recent => 'Reciente',
    _SortMode.ratingDesc => 'Nota',
    _SortMode.ratingAsc => 'Nota',
  };

  /// Lo que lee un lector de pantalla: aquí sí hace falta la frase entera,
  /// porque la flecha no se puede oír.
  String get label => switch (this) {
    _SortMode.recent => 'fecha, lo más reciente primero',
    _SortMode.ratingDesc => 'nota, de mayor a menor',
    _SortMode.ratingAsc => 'nota, de menor a mayor',
  };

  IconData get icon => switch (this) {
    _SortMode.recent => Icons.schedule_rounded,
    _SortMode.ratingDesc => Icons.arrow_downward_rounded,
    _SortMode.ratingAsc => Icons.arrow_upward_rounded,
  };
}
