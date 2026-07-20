import 'package:flutter/material.dart';

class CaptureFab extends StatelessWidget {
  const CaptureFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => print("Loop de Captura iniciado"),
      backgroundColor: Colors.yellow[700], // Token de marca
      elevation: 8,
      shape: const CircleBorder(),
      child: const Icon(Icons.add, color: Colors.black, size: 32),
    );
  }
}