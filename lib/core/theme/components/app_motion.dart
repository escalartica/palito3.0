import 'package:flutter/material.dart';

import '../tokens/app_animation.dart';

/// ===========================================================================
/// APARICIONES
/// ===========================================================================
///
/// **Nada en el mundo real aparece desde el tamaño cero.**
///
/// Un globo desinflado sigue teniendo forma. Una puerta cerrada sigue
/// ocupando el hueco. Cuando algo crece desde 0 en pantalla no se lee como
/// "ha aparecido", se lee como "ha salido de la nada", y el ojo lo nota
/// aunque la cabeza no sepa decir qué.
///
/// La app tenía seis `ScaleTransition` con la animación cruda de 0 a 1: el
/// botón de nuevo recuerdo, los iconos de los chips, la flecha de ordenar,
/// las notas del formulario y el panel que canta el ganador en la ruleta.
/// Todos hacían lo mismo mal.
///
/// Aquí está el remedio en un solo sitio: se entra desde el 94 % y con la
/// opacidad acompañando. El salto es pequeño a propósito — lo justo para que
/// se lea como que algo se coloca, no como que algo explota.
/// ===========================================================================
abstract final class AppMotion {
  /// Aparición estándar de la app. Escala + opacidad, nunca desde cero.
  ///
  /// Pensada para el `transitionBuilder` de un `AnimatedSwitcher` y para
  /// cualquier `ScaleTransition` que antes recibía la animación pelada.
  ///
  /// Usa `Tween.chain(CurveTween(...))` en vez de `CurvedAnimation` a
  /// propósito: esto se construye dentro de un `builder`, y un
  /// `CurvedAnimation` creado ahí es un objeto con ciclo de vida que nadie
  /// libera. Un `Tween` encadenado no tiene estado.
  static Widget popIn(
    Animation<double> animation,
    Widget child, {
    double from = 0.94,
    Curve curve = AppAnimation.pop,
  }) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: from,
          end: 1.0,
        ).chain(CurveTween(curve: curve)).animate(animation),
        child: child,
      ),
    );
  }

  /// Aparición sobria: opacidad y un desplazamiento corto hacia arriba.
  ///
  /// Para listas y bloques de texto. La tipografía escalada se ve borrosa a
  /// mitad de recorrido —el motor la rasteriza a un tamaño y la estira—, así
  /// que donde hay texto se mueve, no se escala.
  static Widget riseIn(
    Animation<double> animation,
    Widget child, {
    double offset = 0.06,
    Curve curve = AppAnimation.enter,
  }) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, offset),
          end: Offset.zero,
        ).chain(CurveTween(curve: curve)).animate(animation),
        child: child,
      ),
    );
  }
}
