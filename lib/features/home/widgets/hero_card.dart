import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // IMPORTANTE AÑADIR
import '../../memory_form/widgets/smart_image.dart'; 
import '../../../core/models/memory_model.dart';

class HeroCard extends ConsumerWidget { // Cambiamos de StatelessWidget a ConsumerWidget
  final MemoryModel? memory;

  const HeroCard({super.key, this.memory});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Añadimos WidgetRef
    if (memory == null) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.4,
        color: Colors.grey[200],
        child: const Center(child: Text("Aún no tienes recuerdos")),
      );
    }

    final String? path = (memory!.imageUrls.isNotEmpty) ? memory!.imageUrls.first : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.grey[300]),
      child: Stack(
        children: [
          Positioned.fill(
            child: (path != null && path.isNotEmpty)
                ? SmartImage(imagePath: path, fit: BoxFit.cover)
                : Container(color: Colors.grey[300], child: const Icon(Icons.image, size: 50, color: Colors.white)),
          ),
          
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory!.title, 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                  Text(
                    memory!.restaurantName, 
                    style: const TextStyle(color: Colors.white70, fontSize: 16)
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}