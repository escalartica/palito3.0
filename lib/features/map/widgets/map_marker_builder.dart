import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/data/rating_scale.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';
import '../../../core/theme/tokens/app_animation.dart';
import '../../../core/theme/components/app_motion.dart';

/// Construye los [Marker] de flutter_map que se dibujan sobre el mapa de
/// recuerdos.
///
/// ── UN SOLO IDIOMA VISUAL ──
///
/// Los tres marcadores eran pastillas y círculos **rellenos del color de la
/// categoría**: granate, cian, marrón, morado, rosa... ocho colores de la
/// paleta de Material sobre un mapa que ya es de siete colores. El resultado
/// es el de las capturas: un mapa que parece de otra aplicación, con
/// manchas que no significan nada — porque en ninguna parte se dice que el
/// marrón es Tortilla, así que el color no informa de nada y solo ensucia.
///
/// Ahora todos los marcadores son la pastilla de Palito: fondo blanco, borde
/// navy y sombra dura. Encima de un mapa claro, eso destaca más que un
/// relleno de color y además se lee igual de bien sobre una autopista, sobre
/// un parque o sobre el mar. La categoría no desaparece: sigue estando, en
/// un punto de color a la izquierda, donde acompaña sin gritar.
///
/// El dato que de verdad interesa —la nota, y si volverías— pasa a ir en
/// navy y en verde/rojo de la marca, con el contraste medido, en vez de en
/// blanco sobre lo que tocara.
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
/// depende de `_MapPageState`.
class MapMarkerBuilder {
  const MapMarkerBuilder._();

  // ============================================================
  // LA PASTILLA
  // ============================================================

  /// Cuerpo común de los marcadores de un recuerdo. Existe para que el
  /// normal y el desplegado no puedan divergir: eran dos copias del mismo
  /// widget con tamaños de letra distintos por descuido.
  static Widget _pill({
    required double rating,
    required bool wouldReturn,
    required Color categoryColor,
    required double fontSize,
  }) {
    final String? label = RatingScale.shortLabel(rating);

    // `FittedBox` como red de seguridad: si algún día la pastilla vuelve a
    // pedir más de lo que el `Marker` reserva, se encoge en vez de pintar la
    // franja de desbordamiento encima del mapa del usuario.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.textPrimary, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.textPrimary,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // La categoría, en un punto. Informa a quien quiera fijarse y no
          // molesta a quien no.
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: categoryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label ?? '–',
            style: GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          if (label != null)
            Icon(
              Icons.star_rounded,
              size: fontSize + 1,
              color: AppColors.textPrimary,
            ),
          const SizedBox(width: 3),
          Icon(
            wouldReturn ? Icons.check_rounded : Icons.close_rounded,
            size: fontSize + 2,
            color: wouldReturn ? AppColors.success : AppColors.error,
          ),
        ],
      ),
      ),
    );
  }

  // ============================================================
  // MARKER NORMAL
  // ============================================================

  static Marker buildMarker({
    required MemoryModel memory,
    required LatLng point,
    required Color Function(String category) getCategoryColor,
    required void Function(MemoryModel memory) onMarkerTapped,
  }) {
    return Marker(
      // 84 se quedaba corto: con "4.0", la estrella y el visto, la pastilla
      // pedía 85,2 y Flutter pintaba la franja amarilla y negra de
      // desbordamiento por encima del mapa. Un `Marker` tiene ancho fijo, así
      // que el contenido no puede negociar: o cabe, o desborda.
      width: 104,
      height: 40,
      point: point,
      child: Semantics(
        button: true,
        label: RatingScale.shortLabel(memory.rating) == null
            ? '${memory.restaurantName}, sin nota'
            : '${memory.restaurantName}, '
                  '${RatingScale.shortLabel(memory.rating)} estrellas',
        child: ExcludeSemantics(
          // Una chincheta se toca con el dedo encima del propio dibujo: si
          // no contesta nada al apoyarlo, durante un instante no sabes si el
          // mapa te ha oído o has fallado el toque.
          child: PressScale(
            onTap: () => onMarkerTapped(memory),
            child: _pill(
              rating: memory.rating,
              wouldReturn: memory.wouldReturn,
              categoryColor: getCategoryColor(memory.category),
              fontSize: 13,
            ),
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
      child: Semantics(
        button: true,
        label: isExpanded
            ? 'Cerrar el grupo de $count recuerdos'
            : '$count recuerdos en este sitio. Toca para separarlos',
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedScale(
              scale: isExpanded ? 1.12 : 1.0,
              duration: spiderfyAnimationDuration,
              curve: AppAnimation.pop,
              child: Container(
                alignment: Alignment.center,
                // El grupo sí va en navy macizo: es el elemento que tiene
                // que ganar al resto del mapa, porque esconde varios
                // recuerdos y hay que darse cuenta de que está ahí.
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: AppColors.textPrimary,
                      offset: Offset(2, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      isExpanded ? Icons.close_rounded : Icons.place_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    Text(
                      '$count',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        color: AppColors.surface,
                      ),
                    ),
                  ],
                ),
              ),
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
    final double distance = sqrt(
      pow(point.latitude - center.latitude, 2) +
          pow(point.longitude - center.longitude, 2),
    );

    final double scale =
        (distance / getSpiderfyRadius(count)).clamp(0.0, 1.0).toDouble();

    return Marker(
      width: 104,
      height: 42,
      point: point,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: scale),
        duration: AppMotion.durFromPlatform(
          AppAnimation.stagger(
            index,
            base: AppAnimation.fast,
            stepMs: 30,
            maxSteps: 8,
          ),
        ),
        curve: AppAnimation.pop,
        builder: (BuildContext context, double animationValue, Widget? child) {
          return Opacity(
            opacity: animationValue,
            child: Transform.scale(scale: animationValue, child: child),
          );
        },
        child: Semantics(
          button: true,
          label: memory.restaurantName,
          child: ExcludeSemantics(
            child: PressScale(
              onTap: () => onMarkerTapped(memory),
              child: _pill(
                rating: memory.rating,
                wouldReturn: memory.wouldReturn,
                categoryColor: getCategoryColor(memory.category),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
