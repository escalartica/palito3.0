import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:palito_3_0/firebase_options.dart';
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
// FIREBASE AUTH
// ============================================================

if (firebaseReady) {
await _ensureFirebaseAuthentication();
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

debugPrint(
  '🔐 UID: ${existingUser.uid}',
);

debugPrint(
  '🔐 Anónimo: ${existingUser.isAnonymous}',
);

debugPrint(
  '🔐 Email: ${existingUser.email}',
);

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

debugPrint(
  '🔐 UID: ${user.uid}',
);

debugPrint(
  '🔐 Usuario anónimo: ${user.isAnonymous}',
);

debugPrint(
  '🔐 Email: ${user.email}',
);


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

// ==========================================================
// DIAGNÓSTICO ESPECÍFICO
// ==========================================================

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

  debugPrint(
    '🔐 UID: ${user.uid}',
  );

  debugPrint(
    '🔐 Usuario anónimo: ${user.isAnonymous}',
  );
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
routes: [
// ============================================================
// DETALLE DE MEMORIA
// ============================================================


GoRoute(
  path: '/memory-detail',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) {
    final memory =
        state.extra as MemoryModel;

    return MemoryDetailPage(
      memory: memory,
    );
  },
),

// ============================================================
// NUEVA MEMORIA
// ============================================================

GoRoute(
  path: '/new-memory',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) {
    return const MemoryFormPage();
  },
),

// ============================================================
// GAMER
// ============================================================

GoRoute(
  path: '/gamer',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) {
    return const GamerPage();
  },
),

// ============================================================
// MAPA
// ============================================================

GoRoute(
  path: '/map',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) {
    final initialCategory =
        state.extra as String?;

    return MapPage(
      initialCategory: initialCategory,
    );
  },
),

// ============================================================
// PERFIL
// ============================================================

GoRoute(
  path: '/profile',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) {
    return const ProfilePage();
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
          child,

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
                    milliseconds: 300,
                  ),
                  curve:
                      Curves.easeInOut,
                  child: Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 24,
                      left: 24,
                      right: 24,
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
      builder: (
        context,
        state,
      ) {
        return const HomePage();
      },
    ),
  ],
),


],
);

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

if (location.startsWith('/map')) {
return 0;
}

if (location.startsWith('/gamer')) {
return 1;
}

if (location.startsWith('/profile')) {
return 2;
}

return 0;
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
