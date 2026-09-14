import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/data/rating_scale.dart';

/// Construye los [Marker] de flutter_map que se dibujan sobre el mapa de
/// recuerdos.
///
/// Agrupa tres variantes:
///
/// - [buildMarker]: marcador normal, un único recuerdo con coordenada
///   propia.
/// - [buildSpiderfyGroupMarker]: marcador circular que representa un grupo
///   de recuerdos que comparten coordenada (antes de expandirse).
/// - [buildSpiderfyMemoryMarker]: marcador individual de un recuerdo
///   dentro de un grupo ya expandido ("spiderfy").
///
/// No mantiene estado propio: recibe mediante callbacks todo lo que
/// depende de `_MapPageState` (color por categoría, tap sobre un
/// recuerdo, radio de spiderfy) para poder vivir fuera de esa clase sin
/// cambiar ningún comportamiento.
class MapMarkerBuilder {
  const MapMarkerBuilder._();

  // ============================================================
  // MARKER NORMAL
  // ============================================================

  static Marker buildMarker({
    required MemoryModel memory,
    required LatLng point,
    required Color Function(String category) getCategoryColor,
    required void Function(MemoryModel memory) onMarkerTapped,
  }) {
    final categoryColor = getCategoryColor(memory.category);

    final wouldReturn = memory.wouldReturn;

    return Marker(
      width: 68,
      height: 36,
      point: point,
      child: GestureDetector(
        onTap: () {
          onMarkerTapped(memory);
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: categoryColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                RatingScale.shortLabel(memory.rating) == null
                    ? '—'
                    : '${RatingScale.shortLabel(memory.rating)}★',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                wouldReturn ? Icons.check_rounded : Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MARKER GRUPO
  // ============================================================

  static Marker buildSpiderfyGroupMarker({
    required LatLng point,
    required int count,
    required Color categoryColor,
    required bool isExpanded,
    required VoidCallback onTap,
    required Duration spiderfyAnimationDuration,
  }) {
    return Marker(
      width: 64,
      height: 64,
      point: point,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: isExpanded ? 1.12 : 1.0,
          duration: spiderfyAnimationDuration,
          curve: Curves.easeOutBack,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: categoryColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isExpanded ? Icons.close_rounded : Icons.place_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MARKER SPIDERFY
  // ============================================================

  static Marker buildSpiderfyMemoryMarker({
    required MemoryModel memory,
    required LatLng point,
    required LatLng center,
    required int index,
    required int count,
    required Color Function(String category) getCategoryColor,
    required void Function(MemoryModel memory) onMarkerTapped,
    required double Function(int count) getSpiderfyRadius,
  }) {
    final categoryColor = getCategoryColor(memory.category);

    final distance = sqrt(
      pow(point.latitude - center.latitude, 2) +
          pow(point.longitude - center.longitude, 2),
    );

    final normalizedDistance = distance / getSpiderfyRadius(count);

    final scale = normalizedDistance.clamp(0.0, 1.0);

    return Marker(
      width: 68,
      height: 42,
      point: point,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: scale),
        duration: Duration(milliseconds: 180 + (index * 35)),
        curve: Curves.easeOutBack,
        builder: (context, animationValue, child) {
          return Opacity(
            opacity: animationValue,
            child: Transform.scale(scale: animationValue, child: child),
          );
        },
        child: GestureDetector(
          onTap: () {
            onMarkerTapped(memory);
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 9,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  RatingScale.shortLabel(memory.rating) == null
                      ? '—'
                      : '${RatingScale.shortLabel(memory.rating)}★',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  memory.wouldReturn
                      ? Icons.check_rounded
                      : Icons.close_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
