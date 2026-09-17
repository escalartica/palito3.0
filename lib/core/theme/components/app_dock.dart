import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_animation.dart';
import '../tokens/app_shape.dart';

// Paleta neo-brutalista (alias locales sobre AppColors, la fuente única de
// verdad — ver core/theme/tokens/app_colors.dart).
const Color palitoDark = AppColors.textPrimary;
const Color palitoYellow = AppColors.primary;

/// Una pestaña del dock.
///
/// [label] es el nombre completo y es lo que lee VoiceOver/TalkBack.
/// [shortLabel] es lo que se pinta debajo del icono cuando el nombre completo
/// no cabe en un cuarto de pantalla ("La ruleta" → "Ruleta"); si es null se
/// pinta [label].
class DockItem {
  const DockItem({required this.icon, required this.label, this.shortLabel});

  final IconData icon;
  final String label;
  final String? shortLabel;

  String get visibleLabel => shortLabel ?? label;
}

/// Barra de navegación flotante.
///
/// Ya no decide ni su posición (el `margin` inferior lo pone quien lo coloca,
/// para que no haya dos márgenes sumándose sin que nadie lo sepa) ni su
/// visibilidad (la decide la pantalla que lo contiene). Solo se dibuja.
///
/// LLEVA TEXTO. La versión anterior era solo de iconos: cuatro pictogramas sin
/// una sola palabra. Un pictograma no dice "el mapa de tus recuerdos" ni
/// "echar a suertes quién elige" a nadie que abra la app por primera vez, y
/// era una de las causas directas de
/// que la navegación resultara difícil de entender. Las Human Interface
/// Guidelines de Apple piden etiqueta en las pestañas precisamente por esto.
class AppDock extends StatelessWidget {
  const AppDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<DockItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Alto real del dock, para que quien lo coloque pueda reservar el hueco
  /// exacto por debajo (el FAB de Inicio y el final de la lista lo usan).
  static const double height = 76;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    // El texto del dock no escala hasta el 140% general de la app: a cuatro
    // columnas no cabría y se cortaría. Sube hasta el 115%, que es lo que
    // admite el ancho de un iPhone SE, y a partir de ahí se queda quieto.
    // El contenido de las pantallas sí escala del todo; esto es solo el
    // crómo de navegación.
    final TextScaler dockScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.15);

    // ALTURA FIJA. Sin esto, el dock se come la pantalla entera: va dentro
    // de un `Align` que le ofrece todo el alto disponible, y el `Center` de
    // cada pestaña, al recibir una altura acotada, se queda con toda ella.
    // El resultado era una tarjeta blanca con borde negro del tamaño de la
    // pantalla tapando la pantalla de Inicio, con los cuatro iconos
    // flotando en mitad del vacío.
    return SizedBox(
      height: height,
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: palitoDark, width: AppBorder.normal),
        boxShadow: AppShadow.lg,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        // ═══════════════════════════════════════════════════════════════════
        // LA PASTILLA VIAJA
        // ═══════════════════════════════════════════════════════════════════
        //
        // Antes cada pestaña tenía SU pastilla y se encendía o se apagaba:
        // el amarillo desaparecía de un sitio y aparecía en otro. Dos cosas
        // pasando a la vez que el ojo tiene que juntar por su cuenta.
        //
        // Ahora es una sola pastilla que se desplaza. Y eso hace dos cosas
        // que la otra versión no hacía: enseña que las pestañas están EN
        // FILA —cosa que cuatro iconos sueltos no dicen— y se mueve en el
        // mismo sentido que la pantalla que entra (ver `_travelDx` en
        // main.dart), así que el dock y el contenido cuentan lo mismo en
        // lugar de contarlo por separado.
        //
        // `AnimatedAlign` y no `AnimatedPositioned`: así no hay que medir
        // nada. La alineación va de -1 (izquierda) a +1 (derecha) y el
        // `FractionallySizedBox` se queda con un cuarto del ancho, sea cual
        // sea el ancho del móvil.
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: AnimatedAlign(
                duration: reduceMotion ? Duration.zero : AppAnimation.standard,
                // `inOut`: esto no entra ni sale, se desplaza de un sitio a
                // otro dentro de la pantalla. Es el caso exacto para el que
                // existe esa curva.
                curve: AppAnimation.inOut,
                alignment: Alignment(
                  items.length < 2
                      ? 0
                      : -1 + 2 * (currentIndex / (items.length - 1)),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  heightFactor: 1,
                  // 4 arriba y abajo: el dock mide 76, menos 12 del relleno
                  // exterior quedan 64, menos estos 8 son los 56 de alto que
                  // tenía la pastilla de antes. La pastilla no cambia de
                  // tamaño; lo único nuevo es que se mueve.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palitoYellow,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: palitoDark, width: 2),
                        boxShadow: AppShadow.sm,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
          children: List<Widget>.generate(items.length, (int index) {
            final DockItem item = items[index];
            final bool isSelected = currentIndex == index;

            return Expanded(
              child: Semantics(
                button: true,
                selected: isSelected,
                label: item.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () {
                    if (!isSelected) HapticFeedback.selectionClick();
                    onTap(index);
                  },
                  child: Center(
                    // Ya no pinta la pastilla: la pinta el `Stack` de arriba,
                    // una sola para las cuatro. Aquí solo queda el contenido
                    // y su área táctil.
                    child: Container(
                      // 48x48 mínimo: el área táctil anterior era de 42 px de
                      // alto, por debajo del mínimo de iOS (44) y de Android
                      // (48).
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 56,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      alignment: Alignment.center,
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(item.icon, size: 22, color: palitoDark),
                            const SizedBox(height: 3),
                            Text(
                              item.visibleLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              textScaler: dockScaler,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.0,
                                letterSpacing: -0.1,
                                // El seleccionado en negro sólido; los demás
                                // un punto más suaves, pero nunca por debajo
                                // de 4.5:1 sobre blanco (AppColors.textSecondary
                                // mide 5,94:1).
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? palitoDark
                                    : AppColors.textSecondary,
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
          }),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
