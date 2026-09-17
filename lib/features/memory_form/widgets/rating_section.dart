import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'form_field_containers.dart';
import '../../../core/theme/components/star_row.dart';
import '../../../core/data/rating_scale.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_animation.dart';
import '../../../core/theme/tokens/app_shape.dart';
import '../../../core/theme/tokens/app_typography.dart';

/// ===========================================================================
/// LA PUNTUACIÓN: CINCO ESTRELLAS, NO UN TIRADOR
/// ===========================================================================
///
/// Esto era un `Slider` de 0 a 5 con once posiciones. Funcionaba, y aun así
/// era el peor control del formulario, por tres razones:
///
/// 1. **Arrancaba pegado a la izquierda**, que es donde vive el cero. La
///    pastilla de al lado ponía "—" para dejar claro que aún no habías
///    puntuado, pero lo que se mira es el tirador, no la pastilla: la
///    pantalla decía "cero" y la letra pequeña decía "todavía nada".
/// 2. **Un tirador no dice cuánto vale lo que estás poniendo.** Hay que
///    soltarlo y leer el número. Cinco estrellas se leen enteras de un
///    vistazo, sin cifra de por medio, porque todo el mundo sabe ya lo que
///    significan.
/// 3. **Es el control que se toca en cada recuerdo que guardas.** Si hay un
///    sitio donde merece la pena gastar el rato, es este.
///
/// ── CÓMO FUNCIONA ──
///
/// Toca o arrastra por encima de la fila. Se calcula la nota por la posición
/// del dedo y se redondea **hacia arriba** a la media estrella más cercana,
/// así que tocar en cualquier punto de la primera estrella da 0,5 y tocar en
/// el borde derecho da 5. Son los mismos once valores que tenía el tirador.
///
/// El gesto se lee sobre la fila entera en vez de poner una zona táctil por
/// estrella: así arrastrar y tocar son el mismo código, y no hay huecos
/// muertos entre estrella y estrella.
///
/// ── COLOR Y FORMA ──
///
/// El amarillo de marca sobre blanco mide **1,43:1**: una estrella amarilla
/// lisa sería una mancha clara. Por eso cada estrella llena lleva su
/// contorno navy encima (17,85:1): la forma se lee aunque el color no, que
/// es la regla que sigue el resto de la app.
class RatingSection extends StatelessWidget {
  final double rating;

  /// ¿Ha puntuado ya?
  ///
  /// Sin esto, un formulario recién abierto enseñaba **0.0**. Y "0.0" no se
  /// lee como "todavía no has puntuado", se lee como "le has puesto un cero"
  /// — que en una app de comida es una acusación.
  final bool hasInteracted;

  final AnimationController ratingAnimationController;
  final ValueChanged<double> onChanged;

  const RatingSection({
    super.key,
    required this.rating,
    required this.hasInteracted,
    required this.ratingAnimationController,
    required this.onChanged,
  });

  /// Parte izquierda de una estrella que cuenta como MEDIA. El resto cuenta
  /// como estrella entera.
  ///
  /// No es la mitad, y esa es toda la gracia. Ver [ratingAt].
  static const double _halfZone = 1 / 3;

  /// Nota correspondiente a un toque en [dx] dentro de una fila de [width].
  ///
  /// Tocar en el borde izquierdo da media estrella y nunca cero, porque cero
  /// aquí significa "sin puntuar" y a ese estado no se debe poder llegar
  /// tocando.
  ///
  /// DÓNDE ESTÁ LA FRONTERA ENTRE MEDIA Y ENTERA. Esto era:
  ///
  ///     return ((raw * 2).ceil() / 2)...
  ///
  /// que parece razonable hasta que se hace la cuenta. La estrella número i
  /// ocupa el tramo [(i-1)/5, i/5], así que su CENTRO cae en `raw = i - 0,5`;
  /// y `ceil((i - 0,5) · 2) / 2` devuelve exactamente `i - 0,5`. Un pelo más
  /// a la derecha devuelve `i`.
  ///
  /// O sea: la frontera entre "media" y "entera" estaba clavada en el centro
  /// geométrico de la estrella — justo el punto al que apunta el dedo cuando
  /// quieres esa estrella. Probándolo en el simulador, un píxel de diferencia
  /// daba 3,5 o 4,0. El control no se sentía impreciso: se sentía aleatorio.
  ///
  /// Ahora la media estrella vive en el tercio izquierdo y la entera en los
  /// dos tercios restantes, así que apuntar al centro da siempre la estrella
  /// entera y hay que ir claramente al borde para pedir la media.
  static double ratingAt(double dx, double width) {
    if (width <= 0) return RatingScale.max;

    final double fraction = (dx / width).clamp(0.0, 1.0);
    final double raw = fraction * RatingScale.max;

    // Qué estrella se ha tocado (0..4) y en qué punto de ella cayó el dedo.
    final int index = raw.floor().clamp(0, RatingScale.max.toInt() - 1);
    final double within = raw - index;

    final double value = within <= _halfZone ? index + 0.5 : index + 1.0;

    return value.clamp(0.5, RatingScale.max).toDouble();
  }

  /// Cómo se dice una puntuación en voz alta.
  ///
  /// Se usa en los tres sitios que exige el árbol de accesibilidad: dónde
  /// estás, a dónde te lleva subir y a dónde te lleva bajar.
  static String _dicho(double r) =>
      '${r.toStringAsFixed(1).replaceAll('.', ',')} de 5. '
      '${RatingScale.qualitativeLabel(r)}';

  void _handle(double dx, double width) {
    final double next = ratingAt(dx, width);
    if (next == rating) return;

    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionLabel(SectionLabels.puntuacion),
        const SizedBox(height: 8),
        NeoContainer(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            children: <Widget>[
              Semantics(
                // `slider: true` hace que VoiceOver ofrezca subir y bajar con
                // un gesto, sin tener que acertar en una estrella concreta.
                slider: true,
                label: 'Puntuación general',
                // ══ ESTO REVENTABA LA APP CON VOICEOVER ENCENDIDO ══
                //
                // Había `value` y había `onIncrease`/`onDecrease`, pero no
                // `increasedValue` ni `decreasedValue`. Y Flutter lo
                // prohíbe expresamente:
                //
                //   A SemanticsNode with action "increase" needs to be
                //   annotated with either both "value" and "increasedValue"
                //   or neither
                //
                // El árbol de accesibilidad solo se construye cuando hay un
                // lector de pantalla escuchando, así que probando la app a
                // dedo no salía nunca. Con VoiceOver puesto, abrir el
                // formulario de un recuerdo lanzaba esa aserción y detrás
                // un `'node.built': is not true` — el árbol a medio montar.
                //
                // Y el motivo de que faltaran es comprensible: sin lector,
                // «dónde estoy» es lo único que se ve. Con lector hacen
                // falta las tres: dónde estás, a dónde te lleva subir y a
                // dónde te lleva bajar. Son las que VoiceOver lee al hacer
                // el gesto, y sin ellas el gesto no dice nada aunque
                // funcione.
                value: hasInteracted ? _dicho(rating) : 'Sin puntuar',
                increasedValue: _dicho(
                  (rating + 0.5).clamp(0.5, RatingScale.max).toDouble(),
                ),
                decreasedValue: _dicho(
                  (rating - 0.5).clamp(0.5, RatingScale.max).toDouble(),
                ),
                onIncrease: rating < RatingScale.max
                    ? () => onChanged(
                        (rating + 0.5).clamp(0.5, RatingScale.max).toDouble(),
                      )
                    : null,
                onDecrease: rating > 0.5
                    ? () => onChanged(
                        (rating - 0.5).clamp(0.5, RatingScale.max).toDouble(),
                      )
                    : null,
                child: ExcludeSemantics(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (TapDownDetails d) =>
                            _handle(d.localPosition.dx, c.maxWidth),
                        onHorizontalDragStart: (DragStartDetails d) =>
                            _handle(d.localPosition.dx, c.maxWidth),
                        onHorizontalDragUpdate: (DragUpdateDetails d) =>
                            _handle(d.localPosition.dx, c.maxWidth),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            for (int i = 1; i <= RatingScale.max.toInt(); i++)
                              // Sin puntuar: todas vacías, aunque `rating`
                              // valga 0 por dentro.
                              Star(
                                fill: hasInteracted
                                    ? StarRow.fillFor(rating, i)
                                    : 0,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                  CurvedAnimation(
                    parent: ratingAnimationController,
                    curve: AppAnimation.pop,
                  ),
                ),
                child: _Verdict(rating: rating, hasInteracted: hasInteracted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Una estrella. [fill]: 0 vacía, 1 media, 2 llena.
/// La cifra y lo que significa.
///
/// `qualitativeLabel` estaba escrito en `RatingScale` desde el principio y no
/// se usaba en el formulario: solo salía el número. Poner «Muy bueno» al lado
/// del 4,0 convierte una cifra en una opinión, que es lo que de verdad estás
/// dando.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.rating, required this.hasInteracted});

  final double rating;
  final bool hasInteracted;

  @override
  Widget build(BuildContext context) {
    if (!hasInteracted) {
      return Text(
        'Toca las estrellas para puntuar',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(color: AppColors.textPrimary, width: 2),
          ),
          child: Text(
            rating.toStringAsFixed(1).replaceAll('.', ','),
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontSize: 15,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          RatingScale.qualitativeLabel(rating),
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
