import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // <--- ESTO ES LO QUE HACE QUE FUNCIONE .push()

import '../../core/providers/dock_provider.dart';
import '../../core/theme/components/memory_card.dart';
import '../../core/theme/tokens/app_spacing.dart';
// Importamos nuestros datos reales
import '../../core/data/mock_data.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos el estado del Dock
    final isDockVisible = ref.watch(dockVisibleProvider);

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is UserScrollNotification) {
            if (notification.direction == ScrollDirection.reverse) {
              ref.read(dockVisibleProvider.notifier).state = false;
            } else if (notification.direction == ScrollDirection.forward) {
              ref.read(dockVisibleProvider.notifier).state = true;
            }
          }
          return true;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            100,
          ),
          itemCount: mockMemories.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final memory = mockMemories[index];
            return MemoryCard(
              memory: memory,
            );
          },
        ),
      ),
      // BOTÓN FLOTANTE CON ESTRUCTURA CORREGIDA
      floatingActionButton: AnimatedOpacity(
        opacity: isDockVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80.0),
          child: FloatingActionButton(
            onPressed: () {
              // Ahora que 'go_router' está importado, context.push funcionará
              context.push('/new-memory');
            },
            backgroundColor: const Color(0xFF2C3E50),
            elevation: 4,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
    );
  }
}