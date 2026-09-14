import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:palito_3_0/firebase_options.dart';
import 'package:palito_3_0/core/models/memory_model.dart';
import 'package:palito_3_0/core/providers/auth_provider.dart';
import 'package:palito_3_0/core/providers/dock_provider.dart';
import 'package:palito_3_0/core/providers/household_provider.dart';
import 'package:palito_3_0/core/theme/app_theme.dart';
import 'package:palito_3_0/core/theme/components/app_dock.dart';
import 'package:palito_3_0/core/utils/app_log.dart';
import 'package:palito_3_0/features/auth/sign_in_page.dart';
import 'package:palito_3_0/features/gamer/gamer_page.dart';
import 'package:palito_3_0/features/home/home_page.dart';
import 'package:palito_3_0/features/home/memory_detail_page.dart';
import 'package:palito_3_0/features/home/memory_form_page.dart';
import 'package:palito_3_0/features/map/map_page.dart';
import 'package:palito_3_0/features/onboarding/household_setup_page.dart';
import 'package:palito_3_0/features/onboarding/invite_partner_page.dart';
import 'package:palito_3_0/features/onboarding/name_page.dart';
import 'package:palito_3_0/features/profile/profile_page.dart';

/// Indica si Firebase se ha inicializado correctamente.
bool firebaseInitialized = false;

final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  final bool firebaseReady = await _initializeFirebase();

  if (firebaseReady) {
    _initializeObservability();
  } else {
    AppLog.e('Firebase no pudo inicializarse correctamente.');
  }

  runApp(const ProviderScope(child: PalitoDeSaboresApp()));
}

// ================================================================
// FIREBASE
// ================================================================

Future<bool> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    firebaseInitialized = true;
    AppLog.i('Firebase inicializado (${Firebase.app().options.projectId}).');

    return true;
  } catch (e, stack) {
    // Los volcados anteriores imprimían el uid y el correo del usuario en el
    // log del sistema, que NO se desactiva en release. Ver core/utils/app_log.
    firebaseInitialized = false;
    AppLog.e('Error inicializando Firebase', e, stack);

    return false;
  }
}

/// Analytics y Crashlytics. Crashlytics no existe en Flutter Web, así que se
/// omite ahí en vez de fallar. En debug se desactiva la recogida en ambos: no
/// tiene sentido mezclar sesiones de desarrollo con datos reales de uso.
void _initializeObservability() {
  try {
    analytics.setAnalyticsCollectionEnabled(!kDebugMode);

    if (!kIsWeb) {
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (e, stack) {
    AppLog.e('No se pudo inicializar Analytics/Crashlytics', e, stack);
  }
}

// ================================================================
// APP PRINCIPAL
// ================================================================

class PalitoDeSaboresApp extends ConsumerStatefulWidget {
  const PalitoDeSaboresApp({super.key});

  @override
  ConsumerState<PalitoDeSaboresApp> createState() => _PalitoDeSaboresAppState();
}

class _PalitoDeSaboresAppState extends ConsumerState<PalitoDeSaboresApp> {
  // Evita relanzar la creación del grupo personal más de una vez por sesión
  // mientras la escritura está en curso.
  String? _backfillInFlightForUid;

  @override
  Widget build(BuildContext context) {
    // Cuentas creadas antes de introducir grupos múltiples (o cualquier cuenta
    // cuyo documento exista pero sin `personalGroupId`) no pasan por
    // AuthService.signInWithApple() en cada apertura, así que ese backfill
    // nunca se dispararía para una sesión ya persistida. Este listener lo
    // cubre de forma reactiva.
    ref.listen<AsyncValue<Map<String, dynamic>?>>(currentUserDocProvider, (
      AsyncValue<Map<String, dynamic>?>? previous,
      AsyncValue<Map<String, dynamic>?> next,
    ) {
      if (!next.hasValue) return;

      final String? uid = ref.read(currentUidProvider);
      if (uid == null) return;
      if (_backfillInFlightForUid == uid) return;

      final Map<String, dynamic>? data = next.value;
      if (data != null && data['personalGroupId'] != null) return;

      _backfillInFlightForUid = uid;

      ref
          .read(authServiceProvider)
          .ensureUserDocument(uid, existingData: data)
          .whenComplete(() {
            if (_backfillInFlightForUid == uid) _backfillInFlightForUid = null;
          });
    });

    return MaterialApp.router(
      title: 'Palito de Sabores',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: ref.watch(routerProvider),
      builder: (BuildContext context, Widget? child) {
        // La app tiene bastantes alturas fijas (chips, dock, botones). Con el
        // texto del sistema al 200% varias de ellas reventaban con overflow.
        // Se permite escalar —es un requisito de accesibilidad— pero con un
        // techo que las estructuras actuales sí soportan.
        final MediaQueryData mq = MediaQuery.of(context);

        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.4,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

// ================================================================
// NAVEGACIÓN
// ================================================================

/// Pestañas del dock. Inicio es una de ellas: antes no lo era, así que desde
/// Mapa/Gamer/Perfil no había ninguna forma evidente de volver.
const List<_Tab> _tabs = <_Tab>[
  _Tab(path: '/', icon: Icons.home_rounded, label: 'Inicio'),
  _Tab(path: '/map', icon: Icons.map_rounded, label: 'Mapa'),
  _Tab(
    path: '/gamer',
    icon: Icons.videogame_asset_rounded,
    label: 'Zona Gamer',
  ),
  _Tab(path: '/profile', icon: Icons.person_rounded, label: 'Perfil'),
];

class _Tab {
  const _Tab({required this.path, required this.icon, required this.label});

  final String path;
  final IconData icon;
  final String label;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Declaradas aquí dentro (no como `final` de nivel superior) para que cada
  // instancia de routerProvider tenga sus propias GlobalKey: compartirlas
  // entre varias instancias de GoRouter rompía los tests en cuanto había más
  // de uno en la misma ejecución.
  final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>();

  // `ref.watch` aquí (no `.read`) es deliberado: reconstruye el GoRouter
  // entero —con un `redirect` nuevo que cierra sobre estos valores ya
  // resueltos— cada vez que cambia la sesión, evitando la condición de
  // carrera de leer providers derivados dentro del propio `redirect`.
  final String? uid = ref.watch(currentUidProvider);
  final AsyncValue<Map<String, dynamic>?> userDocAsync = ref.watch(
    currentUserDocProvider,
  );
  final bool needsName = ref.watch(needsDisplayNameProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    observers: <NavigatorObserver>[
      // El `if` evita tocar FirebaseAnalytics.instance (y por tanto
      // Firebase.app()) cuando Firebase no se ha inicializado — el caso de los
      // tests de widget, que construyen la app sin pasar por main().
      if (firebaseInitialized) FirebaseAnalyticsObserver(analytics: analytics),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;
      final bool onSignIn = location == '/sign-in';
      final bool onNamePage = location == '/tu-nombre';

      if (uid == null) {
        return onSignIn ? null : '/sign-in';
      }

      if (userDocAsync.isLoading) {
        // Todavía no sabemos si su grupo personal está creado ni si tiene
        // nombre — no redirigir hasta saberlo.
        return null;
      }

      // Única puerta de onboarding: el nombre. Apple solo entrega el nombre
      // real la PRIMERA vez que se autoriza la app; sin esta pantalla, quien
      // reinstalaba se quedaba sin nombre (y antes, con el prefijo de su
      // correo: `gdvcgp2gdt`) sin forma de arreglarlo.
      if (needsName) {
        return onNamePage ? null : '/tu-nombre';
      }

      if (onSignIn || onNamePage) {
        return '/';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/sign-in',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(context, state, const SignInPage()),
      ),

      GoRoute(
        path: '/tu-nombre',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(context, state, const NamePage()),
      ),

      // Compartir con alguien (crear/unirse a un grupo) — opcional,
      // alcanzable desde Perfil, nunca por redirect.
      GoRoute(
        path: '/household-setup',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) => _page(
          context,
          state,
          HouseholdSetupPage(initialMode: state.uri.queryParameters['mode']),
        ),
      ),

      GoRoute(
        path: '/invite-partner',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (BuildContext context, GoRouterState state) =>
            state.extra is String ? null : '/',
        pageBuilder: (BuildContext context, GoRouterState state) => _page(
          context,
          state,
          InvitePartnerPage(groupId: state.extra as String),
        ),
      ),

      GoRoute(
        path: '/memory-detail',
        parentNavigatorKey: rootNavigatorKey,
        // Sin esta guarda, entrar por enlace profundo o volver tras un
        // reinicio del proceso reventaba con un cast nulo.
        redirect: (BuildContext context, GoRouterState state) =>
            state.extra is MemoryModel ? null : '/',
        pageBuilder: (BuildContext context, GoRouterState state) => _page(
          context,
          state,
          MemoryDetailPage(memory: state.extra as MemoryModel),
        ),
      ),

      GoRoute(
        path: '/new-memory',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _page(context, state, const MemoryFormPage()),
      ),

      // ============================================================
      // SHELL PRINCIPAL — las cuatro pestañas del dock
      // ============================================================
      //
      // Antes, solo `/` estaba dentro del shell: Mapa, Zona Gamer y Perfil
      // eran rutas sueltas sin dock, así que la barra de navegación
      // desaparecía en cuanto salías de Inicio — y el índice de pestaña que
      // se calculaba para ellas no se llegaba a ver nunca.
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return _ShellScaffold(location: state.uri.path, child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _page(context, state, const HomePage()),
          ),
          GoRoute(
            path: '/map',
            pageBuilder: (BuildContext context, GoRouterState state) => _page(
              context,
              state,
              MapPage(initialCategory: state.extra as String?),
            ),
          ),
          GoRoute(
            path: '/gamer',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _page(context, state, const GamerPage()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (BuildContext context, GoRouterState state) =>
                _page(context, state, const ProfilePage()),
          ),
        ],
      ),
    ],
  );
});

/// Andamio común de las cuatro pestañas: el contenido y, encima, el dock.
class _ShellScaffold extends ConsumerWidget {
  const _ShellScaffold({required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // El dock solo se esconde al hacer scroll en Inicio. En el resto de
    // pestañas está siempre visible: antes bastaba con abrir un recuerdo
    // (que apagaba `dockVisibleProvider` y no volvía a encenderlo) para
    // quedarse sin barra de navegación hasta reiniciar la app.
    final bool isHome = location == '/';
    final bool isVisible = !isHome || ref.watch(dockVisibleProvider);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final int selectedIndex = _tabs.indexWhere((_Tab t) => t.path == location);

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: child),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              offset: isVisible ? Offset.zero : const Offset(0, 2),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              child: SafeArea(
                top: false,
                child: Padding(
                  // Un único sitio que decide la separación inferior: antes
                  // el margen estaba a la vez dentro de AppDock y aquí, y se
                  // sumaban sin que nadie lo supiera.
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: AppDock(
                      items: _tabs
                          .map(
                            (_Tab t) => DockItem(icon: t.icon, label: t.label),
                          )
                          .toList(),
                      currentIndex: selectedIndex,
                      onTap: (int index) {
                        HapticFeedback.lightImpact();
                        context.go(_tabs[index].path);
                      },
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
}

// ================================================================
// TRANSICIÓN DE PÁGINAS
// ================================================================

/// Transición compartida por todas las rutas. Respeta "Reducir movimiento"
/// (`MediaQuery.disableAnimations`): con esa opción activada, la app tardaba
/// más de un segundo en mostrar nada porque las animaciones de entrada seguían
/// corriendo igual.
CustomTransitionPage<void> _page(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 320),
    reverseTransitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 240),
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          if (reduceMotion) return child;

          final CurvedAnimation curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0.02),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
  );
}
