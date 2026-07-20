import 'package:flutter/material.dart';
import 'widgets/hero_card.dart';
import 'widgets/capture_fab.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Capa de contenido editorial
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) print("Navegar a Pasaporte");
              if (details.primaryVelocity! < 0) print("Navegar a Radar");
            },
            child: const HeroCard(),
          ),
          // Capa de acción
          const Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(child: CaptureFab()),
          ),
        ],
      ),
    );
  }
}