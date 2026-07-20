import 'package:flutter/material.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/last_memory.jpg'), // Placeholder
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.bottomLeft,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tortilla de Betanzos", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text("La Penela", style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}