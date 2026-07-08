import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void main() {
  // ProviderScope es obligatorio para utilizar Riverpod en toda la app
  runApp(const ProviderScope(child: PalitoDeSaboresApp()));
}

class PalitoDeSaboresApp extends StatelessWidget {
  const PalitoDeSaboresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Palito de Sabores',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      routerConfig: _router,
    );
  }
}

// Configuración inicial de GoRouter
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Palito de Sabores - Inicio')),
      ),
    ),
  ],
);