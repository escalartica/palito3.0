import 'package:flutter/material.dart';
import '../../models/memory_model.dart';
import '../../../features/home/memory_detail_page.dart';
 // Asegúrate de que esta ruta sea correcta

// 1. Variante Compacta (Para listas)
class MemoryCardCompact extends StatelessWidget {
  final MemoryModel memory;
  const MemoryCardCompact({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MemoryDetailPage(memory: memory)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: memory.imageUrl != null && memory.imageUrl!.isNotEmpty
                          ? Image.network(memory.imageUrl!, width: 56, height: 56, fit: BoxFit.cover)
                          : Container(width: 56, height: 56, color: Colors.grey.shade200),
                    ),
                    if (memory.isRecent)
                      Positioned(
                        right: 0, top: 0,
                        child: Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(memory.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(memory.restaurantName, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 2. Variante Grande (Para el scroll horizontal)
class MemoryCardLarge extends StatelessWidget {
  final MemoryModel? memory;
  const MemoryCardLarge({super.key, this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: memory == null ? null : () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MemoryDetailPage(memory: memory!)),
          ),
          child: memory != null && memory!.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(memory!.imageUrl!, fit: BoxFit.cover),
                )
              : Center(child: Text(memory?.title ?? "Recuerdo destacado")),
        ),
      ),
    );
  }
}