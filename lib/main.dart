import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:palito_3_0/firebase_options.dart';
import 'package:palito_3_0/core/models/memory_model.dart';
import 'package:palito_3_0/core/providers/auth_provider.dart';
import 'package:palito_3_0/core/providers/household_provider.dart';
import 'package:palito_3_0/core/theme/app_theme.dart';
import 'package:palito_3_0/core/theme/components/app_dock.dart';
import 'package:palito_3_0/core/providers/dock_provider.dart';
import 'package:palito_3_0/features/auth/sign_in_page.dart';
import 'package:palito_3_0/features/home/home_page.dart';
import 'package:palito_3_0/features/home/memory_detail_page.dart';
import 'package:palito_3_0/features/home/memory_form_page.dart';
import 'package:palito_3_0/features/map/map_page.dart';
import 'package:palito_3_0/features/gamer/gamer_page.dart';
import 'package:palito_3_0/features/onboarding/household_setup_page.dart';
import 'package:palito_3_0/features/onboarding/invite_partner_page.dart';
import 'package:palito_3_0/features/profile/profile_page.dart';

/// Indica si Firebase se ha inicializado correctamente.
bool firebaseInitialized = false;

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();

// ============================================================
// ORIENTACIÓN
// ============================================================

await SystemChrome.setPreferredOrientations([
DeviceOrientation.portraitUp,
]);

// ============================================================
// FIREBASE
// ============================================================

final firebaseReady = await _initializeFirebase();

if (!firebaseReady) {
debugPrint(
'❌ Firebase no pudo inicializarse correctamente.',
);
}

// ============================================================
// OBSERVABILIDAD (ANALYTICS + CRASHLYTICS)
// ============================================================
//
// Antes no había ninguna forma de saber si algo fallaba en producción
// salvo que un usuario lo reportara a mano.

if (firebaseReady) {
_initializeObservability();
}

// ============================================================
// ESTADO FINAL DE FIREBASE
// ============================================================
//
// Ya no hay autenticación anónima silenciosa aquí: con Sign in with
// Apple, el usuario inicia sesión explícitamente desde SignInPage, y el
// `redirect` de GoRouter (ver routerProvider) reacciona solo a los
// cambios de sesión — no hace falta bloquear runApp() para esperarla.

_printFirebaseStatus();

// ============================================================
// APP
// ============================================================

runApp(
const ProviderScope(
child: PalitoDeSaboresApp(),
),
);
}

// ================================================================
// FIREBASE INITIALIZATION
// ================================================================

Future<bool> _initializeFirebase() async {
try {
debugPrint('🔥 Inicializando Firebase...');

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

firebaseInitialized = true;

final app = Firebase.app();

debugPrint(
  '✅ Firebase inicializado correctamente.',
);

debugPrint(
  '🔥 Firebase App name: ${app.name}',
);

debugPrint(
  '🔥 Firebase Project ID: ${app.options.projectId}',
);

debugPrint(
  '🔥 Firebase App ID: ${app.options.appId}',
);

debugPrint(
  '🔥 Firebase Messaging Sender ID: '
  '${app.options.messagingSenderId}',
);

debugPrint(
  '🔥 Firebase iOS Bundle ID: '
  '${app.options.iosBundleId}',
);

return true;

} on FirebaseException catch (e, stack) {
firebaseInitialized = false;

debugPrint(
  '❌ ERROR INICIALIZANDO FIREBASE',
);

debugPrint(
  '❌ Código: ${e.code}',
);

debugPrint(
  '❌ Mensaje: ${e.message}',
);

debugPrintStack(
  stackTrace: stack,
);

return false;

} catch (e, stack) {
firebaseInitialized = false;

debugPrint(
  '❌ ERROR INESPERADO INICIALIZANDO FIREBASE: $e',
);

debugPrintStack(
  stackTrace: stack,
);

return false;

}
}

// ================================================================
// OBSERVABILIDAD (ANALYTICS + CRASHLYTICS)
// ================================================================
//
// Crashlytics no está disponible en Flutter Web (solo iOS/Android), así
// que se omite en esa plataforma en vez de fallar. Analytics sí
// funciona en las tres plataformas.
//
// En debug (desarrollo local) se desactiva la recogida en ambos: no
// tiene sentido mezclar sesiones de prueba del propio desarrollo con
// datos reales de uso, ni llenar Crashlytics de errores provocados a
// propósito mientras se depura.

final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

void _initializeObservability() {
try {
analytics.setAnalyticsCollectionEnabled(!kDebugMode);

if (!kIsWeb) {
  FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );

  FlutterError.onError =
      FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (
    Object error,
    StackTrace stack,
  ) {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: true,
    );

    return true;
  };
}

debugPrint(
  '📊 Analytics/Crashlytics inicializados '
  '(recogida activa: ${!kDebugMode}).',
);
} catch (e, stack) {
debugPrint(
  '⚠️ No se pudo inicializar Analytics/Crashlytics: $e',
);

debugPrintStack(stackTrace: stack);
}
}

// ================================================================
// FIREBASE STATUS
// ================================================================

void _printFirebaseStatus() {
debugPrint(
'============================================================',
);

debugPrint(
'🔥 ESTADO FINAL DE FIREBASE',
);

debugPrint(
'============================================================',
);

debugPrint(
'🔥 Firebase inicializado: $firebaseInitialized',
);

if (!firebaseInitialized) {
debugPrint(
'❌ Firebase no está disponible.',
);

debugPrint(
  '============================================================',
);

return;

}

try {
final app = Firebase.app();
final user = FirebaseAuth.instance.currentUser;

debugPrint(
  '🔥 Firebase apps activas: ${Firebase.apps.length}',
);

debugPrint(
  '🔥 Firebase App: ${app.name}',
);

debugPrint(
  '🔥 Project ID: ${app.options.projectId}',
);

debugPrint(
  '🔥 App ID: ${app.options.appId}',
);

debugPrint(
  '🔥 Bundle ID: ${app.options.iosBundleId}',
);

if (user != null) {
  debugPrint(
    '✅ Firebase Auth: USUARIO AUTENTICADO',
  );

  if (kDebugMode) {
    debugPrint(
      '🔐 UID: ${user.uid}',
    );

    debugPrint(
      '🔐 Usuario anónimo: ${user.isAnonymous}',
    );
  }
} else {
  debugPrint(
    '❌ Firebase Auth: SIN USUARIO',
  );

  debugPrint(
    '❌ Firestore no podrá acceder a '
    'users/{uid}/memories.',
  );
}

} catch (e) {
debugPrint(
'❌ Error comprobando estado final de Firebase: $e',
);
}

debugPrint(
'============================================================',
);
}

// ================================================================
// APP PRINCIPAL
// ================================================================

class PalitoDeSaboresApp extends ConsumerWidget {
const PalitoDeSaboresApp({
super.key,
});

@override
Widget build(BuildContext context, WidgetRef ref) {
return MaterialApp.router(
title: 'Palito de Sabores',
debugShowCheckedModeBanner: false,
theme: AppTheme.lightTheme,
routerConfig: ref.watch(routerProvider),
);
}
}

// ================================================================
// NAVEGACIÓN
// ================================================================

final routerProvider = Provider<GoRouter>((ref) {
// Declaradas aquí dentro (no como `final` de nivel superior) para que
// cada instancia de routerProvider —una sola vez en la app real, pero
// una nueva por cada ProviderScope en los tests— tenga sus propias
// GlobalKey. Compartir las mismas claves entre varias instancias de
// GoRouter (como ocurría antes) confunde a Flutter sobre qué Navigator
// es cuál — invisible con un solo GoRouter vivo a la vez, pero rompía
// los tests en cuanto había más de uno en la misma ejecución.
final rootNavigatorKey =
GlobalKey<NavigatorState>();

final shellNavigatorKey =
GlobalKey<NavigatorState>();

// `ref.watch` aquí (no `.read`) es deliberado: reconstruye por completo
// el GoRouter —con un `redirect` nuevo que cierra sobre estos valores ya
// resueltos como variables locales normales— cada vez que cambia la
// sesión o el hogar. La alternativa (un solo GoRouter con
// `refreshListenable` y `redirect` leyendo providers con `ref.read` en
// cada llamada) tiene una condición de carrera real: `ref.listen`
// puede disparar la notificación de refresco antes de que Riverpod
// termine de recalcular los providers derivados que ese mismo
// `redirect` necesita leer, así que `ref.read` devuelve el valor
// anterior (caducado) justo en el momento decisivo. Reconstruir el
// GoRouter entero evita el problema de raíz: no hay nada que leer
// "por fuera" del ciclo de build.
final String? uid = ref.watch(currentUidProvider);
final userDocAsync = ref.watch(currentUserDocProvider);
final String? householdId = ref.watch(currentHouseholdIdProvider);

return GoRouter(
navigatorKey: rootNavigatorKey,
initialLocation: '/',
// El `if` evita tocar FirebaseAnalytics.instance (y por tanto
// Firebase.app()) cuando Firebase no se ha inicializado — el caso de
// los tests de widget, que construyen PalitoDeSaboresApp sin pasar por
// main().
observers: [
if (firebaseInitialized)
  FirebaseAnalyticsObserver(analytics: analytics),
],
redirect: (context, state) {
  final String location = state.matchedLocation;
  final bool onSignIn = location == '/sign-in';
  final bool onSetup = location == '/household-setup';

  if (uid == null) {
    return onSignIn ? null : '/sign-in';
  }

  if (userDocAsync.isLoading) {
    // Todavía no sabemos si tiene hogar — no redirigir hasta
    // saberlo, para no rebotar a household-setup y de vuelta.
    return null;
  }

  if (householdId == null) {
    return onSetup ? null : '/household-setup';
  }

  if (onSignIn || onSetup) {
    return '/';
  }

  return null;
},
routes: [
// ============================================================
// INICIO DE SESIÓN
// ============================================================

GoRoute(
  path: '/sign-in',
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) {
    return _buildDynamicPage(
      context: context,
      state: state,
      child: const SignInPage(),
      direction: 1,
    );
  },
),

// ============================================================
// CONFIGURACIÓN DE HOGAR
// ============================================================

GoRoute(
  path: '/household-setup',
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) {
    return _buildDynamicPage(
      context: context,
      state: state,
      child: const HouseholdSetupPage(),
      direction: 1,
    );
  },
),

// ============================================================
// INVITAR A LA PAREJA
// ============================================================

GoRoute(
  path: '/invite-partner',
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) {
    final householdId = state.extra as String?;

    return _buildDynamicPage(
      context: context,
      state: state,
      child: InvitePartnerPage(
        householdId: householdId,
      ),
      direction: 1,
    );
  },
),
// ============================================================
// DETALLE DE MEMORIA
// ============================================================

GoRoute(
  path: '/memory-detail',
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) {
    final memory =
        state.extra as MemoryModel;

    return _buildDynamicPage(
      context: context,
      state: state,
      child: MemoryDetailPage(
        memory: memory,
      ),
      direction: 1,
    );
  },
),

// ============================================================
// NUEVA MEMORIA
// ============================================================

GoRoute(
  path: '/new-memory',
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) {
    return _buildDynamicPage(
      context: context,
      state: state,
      child: const MemoryFormPage(),
      direction: 1,
    );
  },
),

// ============================================================
// GAMER
// ============================================================

GoRoute(
  path: '/gamer',
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) {
    return _buildDynamicPage(
      context: context,
      state: state,
      child: const GamerPage(),
      direction: 1,
    );
  },
),

// ============================================================
// MAPA
// ============================================================

GoRoute(
  path: '/map',
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) {
    final initialCategory =
        state.extra as String?;

    return _buildDynamicPage(
      context: context,
      state: state,
      child: MapPage(
        initialCategory: initialCategory,
      ),
      direction: 1,
    );
  },
),

// ============================================================
// PERFIL
// ============================================================

GoRoute(
  path: '/profile',
  parentNavigatorKey: rootNavigatorKey,
  pageBuilder: (context, state) {
    return _buildDynamicPage(
      context: context,
      state: state,
      child: const ProfilePage(),
      direction: 1,
    );
  },
),

// ============================================================
// SHELL PRINCIPAL
// ============================================================

ShellRoute(
  navigatorKey: shellNavigatorKey,
  builder: (
    context,
    state,
    child,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFFDFBF7),
      body: Stack(
        children: [
          // ==================================================
          // CONTENIDO PRINCIPAL
          // ==================================================

          Positioned.fill(
            child: child,
          ),

          // ==================================================
          // APP DOCK
          // ==================================================

          Align(
            alignment:
                Alignment.bottomCenter,
            child: Consumer(
              builder: (
                context,
                ref,
                _,
              ) {
                final isVisible =
                    ref.watch(
                  dockVisibleProvider,
                );

                return AnimatedSlide(
                  offset: isVisible
                      ? Offset.zero
                      : const Offset(
                          0,
                          2,
                        ),
                  duration:
                      const Duration(
                    milliseconds: 350,
                  ),
                  curve:
                      Curves.easeOutCubic,
                  child: Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 24,
                      left: 24,
                      right: 24,
                    ),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(
                        maxWidth: 640,
                      ),
                      child: AppDock(
                      items: const [
                        Icons
                            .map_rounded,
                        Icons
                            .videogame_asset_rounded,
                        Icons
                            .person_rounded,
                      ],
                      currentIndex:
                          _calculateSelectedIndex(
                        context,
                      ),
                      onTap:
                          (index) {
                        _onItemTapped(
                          index,
                          context,
                        );
                      },
                    ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  },
  routes: [
    // ========================================================
    // HOME
    // ========================================================

    GoRoute(
      path: '/',
      pageBuilder: (
        context,
        state,
      ) {
        return _buildDynamicPage(
          context: context,
          state: state,
          child: const HomePage(),
          direction: 1,
        );
      },
    ),
  ],
),

],
);
});

// ================================================================
// TRANSICIÓN DINÁMICA DE PÁGINAS
// ================================================================

CustomTransitionPage<void> _buildDynamicPage({
required BuildContext context,
required GoRouterState state,
required Widget child,
required int direction,
}) {
return CustomTransitionPage<void>(
key: state.pageKey,
child: child,
transitionDuration:
const Duration(
milliseconds: 500,
),
reverseTransitionDuration:
const Duration(
milliseconds: 350,
),
transitionsBuilder: (
context,
animation,
secondaryAnimation,
child,
) {
final curvedAnimation =
CurvedAnimation(
parent: animation,
curve: Curves.easeOutCubic,
reverseCurve: Curves.easeInCubic,
);

  final slideAnimation =
      Tween<Offset>(
    begin: Offset(
      0.12 * direction,
      0.035,
    ),
    end: Offset.zero,
  ).animate(
    curvedAnimation,
  );

  final scaleAnimation =
      Tween<double>(
    begin: 0.96,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ),
  );

  final fadeAnimation =
      Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    ),
  );

  return FadeTransition(
    opacity: fadeAnimation,
    child: SlideTransition(
      position: slideAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        alignment: Alignment.center,
        child: child,
      ),
    ),
  );
},

);
}

// ================================================================
// ÍNDICE DEL DOCK
// ================================================================

int _calculateSelectedIndex(
BuildContext context,
) {
final String location =
GoRouterState
.of(context)
.uri
.path;

// MAPA
if (location.startsWith('/map')) {
return 0;
}

// GAMER
if (location.startsWith('/gamer')) {
return 1;
}

// PERFIL
if (location.startsWith('/profile')) {
return 2;
}

// HOME Y CUALQUIER OTRA RUTA
// No seleccionamos ningún icono.
return -1;
}

// ================================================================
// NAVEGACIÓN DEL DOCK
// ================================================================

void _onItemTapped(
int index,
BuildContext context,
) {
HapticFeedback.lightImpact();

switch (index) {
case 0:
context.go('/map');
break;


case 1:
  context.go('/gamer');
  break;

case 2:
  context.go('/profile');
  break;

}
}
