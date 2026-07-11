import 'package:flutter/material.dart';
import '../../models/memory_model.dart'; // Asegúrate de ajustar la ruta si es necesario

class HomeHero extends StatelessWidget {
  final MemoryModel? memory;

  const HomeHero({super.key, this.memory});

  @override
  Widget build(BuildContext context) {
    // Definimos los valores por defecto si no hay memoria
    final imageUrl = memory?.imageUrl ?? 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800';
    final title = memory?.title ?? "Tu mejor experiencia gastronómica";

    return Container(
      height: 340,
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
    child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
  );
}