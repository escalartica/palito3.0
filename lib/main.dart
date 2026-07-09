import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/models/memory_model.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/components/app_dock.dart';
import 'features/home/home_page.dart';
import 'features/home/memory_detail_page.dart';
import 'features/home/memory_form_page.dart';

void main() {
  runApp(const ProviderScope(child: PalitoDeSaboresApp()));
}

class PalitoDeSaboresApp extends StatelessWidget {
  const PalitoDeSaboresApp({super.key});

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

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // RUTA DE DETALLE (Fuera del ShellRoute para que no tenga Dock)
    GoRoute(
      path: '/memory-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final memory = state.extra as MemoryModel;
        return MemoryDetailPage(memory: memory);
      },
    ),
    GoRoute(
  path: '/new-memory',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) => const MemoryFormPage(),
),
    // RUTAS CON DOCK (Dentro del ShellRoute)
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return Scaffold(
          body: Stack(
            children: [
              child,
              AppDock(
                items: const [
                  Icons.home_rounded,
                  Icons.explore_rounded,
                  Icons.person_rounded,
                ],
                currentIndex: _calculateSelectedIndex(context),
                onTap: (index) => _onItemTapped(index, context),
              ),
            ],
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/explore',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text("Explorar sabores")),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text("Mi Perfil")),
          ),
        ),
      ],
    ),
  ],
);

int _calculateSelectedIndex(BuildContext context) {
  final String location = GoRouterState.of(context).uri.path;
  if (location.startsWith('/explore')) return 1;
  if (location.startsWith('/profile')) return 2;
  return 0;
}

void _onItemTapped(int index, BuildContext context) {
  HapticFeedback.lightImpact();
  switch (index) {
    case 0:
      context.go('/');
      break;
    case 1:
      context.go('/explore');
      break;
    case 2:
      context.go('/profile');
      break;
  }
}