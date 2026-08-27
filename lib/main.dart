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
import 'package:palito_3_0/core/services/household_migration_service.dart';
import 'package:palito_3_0/core/services/legacy_photo_migration.dart';
import 'package:palito_3_0/core/models/memory_model.dart';
import 'package:palito_3_0/core/theme/app_theme.dart';
import 'package:palito_3_0/core/theme/components/app_dock.dart';
import 'package:palito_3_0/core/providers/dock_provider.dart';
import 'package:palito_3_0/features/home/home_page.dart';
import 'package:palito_3_0/features/home/memory_detail_page.dart';
import 'package:palito_3_0/features/home/memory_form_page.dart';
import 'package:palito_3_0/features/map/map_page.dart';
import 'package:palito_3_0/features/gamer/gamer_page.dart';
import 'package:palito_3_0/features/profile/profile_page.dart';

/// Indica si Firebase se ha inicializado correctamente.
bool firebaseInitialized = false;

/// Indica si existe un usuario autenticado.
bool firebaseAuthenticated = false;

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
// FIREBASE AUTH
// ============================================================

if (firebaseReady) {
await _ensureFirebaseAuthentication();
}

// ============================================================
// MIGRACIÓN A HOGAR COMPARTIDO
// ============================================================
//
// Copia (una sola vez, por dispositivo) los datos guardados bajo el
// antiguo uid anónimo de este teléfono al documento compartido del
// hogar, para que los recuerdos y estadísticas ya registrados no se
// pierdan al pasar a la arquitectura multi-dispositivo.

if (firebaseAuthenticated) {
await migrateLegacyUserDataToHousehold();
await migrateLegacyPhotosToStorage();
}

// ============================================================
// ESTADO FINAL DE FIREBASE
// ============================================================

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
// FIREBASE AUTHENTICATION
// ================================================================

Future<void> _ensureFirebaseAuthentication() async {
if (!firebaseInitialized) {
debugPrint(
'⚠️ No se puede autenticar: Firebase no está inicializado.',
);

return;

}

final auth = FirebaseAuth.instance;

// ============================================================
// COMPROBAR USUARIO EXISTENTE
// ============================================================

final existingUser = auth.currentUser;

if (existingUser != null) {
firebaseAuthenticated = true;

debugPrint(
  '🔐 Usuario Firebase ya autenticado.',
);

// UID y email identifican la sesión — en una build Web de
// producción quedarían visibles en la consola del navegador para
// cualquiera que la abra, así que solo se imprimen en debug.
if (kDebugMode) {
  debugPrint(
    '🔐 UID: ${existingUser.uid}',
  );

  debugPrint(
    '🔐 Anónimo: ${existingUser.isAnonymous}',
  );

  debugPrint(
    '🔐 Email: ${existingUser.email}',
  );
}

return;

}

debugPrint(
'🔐 No existe usuario Firebase.',
);

// ============================================================
// AUTENTICACIÓN ANÓNIMA
// ============================================================

try {
debugPrint(
'🔐 Iniciando autenticación anónima...',
);

final UserCredential credential =
    await auth.signInAnonymously();

final user = credential.user;

if (user == null) {
  firebaseAuthenticated = false;

  debugPrint(
    '❌ Firebase Auth terminó sin devolver usuario.',
  );

  return;
}

firebaseAuthenticated = true;

debugPrint(
  '✅ AUTENTICACIÓN FIREBASE CORRECTA',
);

if (kDebugMode) {
  debugPrint(
    '🔐 UID: ${user.uid}',
  );

  debugPrint(
    '🔐 Usuario anónimo: ${user.isAnonymous}',
  );

  debugPrint(
    '🔐 Email: ${user.email}',
  );
}

} on FirebaseAuthException catch (e, stack) {
firebaseAuthenticated = false;

debugPrint(
  '❌ ERROR DE FIREBASE AUTH',
);

debugPrint(
  '❌ Código: ${e.code}',
);

debugPrint(
  '❌ Mensaje: ${e.message}',
);

debugPrint(
  '❌ Plugin: FirebaseAuth',
);

debugPrint(
  '❌ Firebase inicializado: $firebaseInitialized',
);

switch (e.code) {
  case 'operation-not-allowed':
    debugPrint(
      '🚨 La autenticación anónima NO está habilitada '
      'en Firebase Console.',
    );

    debugPrint(
      '🚨 Revisar: '
      'Firebase Console > Authentication > Sign-in method '
      '> Anonymous.',
    );
    break;

  case 'network-request-failed':
    debugPrint(
      '🌐 Firebase Auth no puede comunicarse con los servidores.',
    );

    debugPrint(
      '🌐 Comprobar conexión a Internet del iPhone.',
    );
    break;

  case 'too-many-requests':
    debugPrint(
      '🚨 Firebase ha bloqueado temporalmente solicitudes '
      'por exceso de intentos.',
    );
    break;

  case 'invalid-api-key':
    debugPrint(
      '🚨 La API Key de Firebase no es válida.',
    );
    break;

  case 'app-not-authorized':
    debugPrint(
      '🚨 La aplicación iOS no está autorizada '
      'para utilizar Firebase Auth.',
    );

    debugPrint(
      '🚨 Revisar Bundle ID y restricciones de la API Key.',
    );
    break;

  case 'internal-error':
    debugPrint(
      '🚨 Firebase Auth devolvió INTERNAL-ERROR.',
    );

    debugPrint(
      '🚨 Revisar configuración del proveedor Anonymous, '
      'GoogleService-Info.plist, Bundle ID y dependencias '
      'nativas de Firebase.',
    );
    break;

  default:
    debugPrint(
      '⚠️ Error Firebase Auth no clasificado: ${e.code}',
    );
}

debugPrintStack(
  stackTrace: stack,
);

} catch (e, stack) {
firebaseAuthenticated = false;

debugPrint(
  '❌ ERROR INESPERADO DURANTE FIREBASE AUTH: $e',
);

debugPrintStack(
  stackTrace: stack,
);

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

class PalitoDeSaboresApp extends StatelessWidget {
const PalitoDeSaboresApp({
super.key,
});

@override
Widget build(BuildContext context) {
return MaterialApp.router(
title: 'Palito de Sabores',
debugShowCheckedModeBanner: false,
theme: AppTheme.lightTheme,
routerConfig: _router,
);
}
}

// ================================================================
// NAVEGACIÓN
// ================================================================

final _rootNavigatorKey =
GlobalKey<NavigatorState>();

final _shellNavigatorKey =
GlobalKey<NavigatorState>();

final _router = GoRouter(
navigatorKey: _rootNavigatorKey,
initialLocation: '/',
// El `if` evita tocar FirebaseAnalytics.instance (y por tanto
// Firebase.app()) cuando Firebase no se ha inicializado — el caso de
// los tests de widget, que construyen PalitoDeSaboresApp sin pasar por
// main().
observers: [
if (firebaseInitialized)
  FirebaseAnalyticsObserver(analytics: analytics),
],
routes: [
// ============================================================
// DETALLE DE MEMORIA
// ============================================================

GoRoute(
  path: '/memory-detail',
  parentNavigatorKey: _rootNavigatorKey,
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
  parentNavigatorKey: _rootNavigatorKey,
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
  parentNavigatorKey: _rootNavigatorKey,
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
  parentNavigatorKey: _rootNavigatorKey,
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
  parentNavigatorKey: _rootNavigatorKey,
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
  navigatorKey: _shellNavigatorKey,
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
