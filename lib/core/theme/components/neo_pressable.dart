import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_animation.dart';
import '../tokens/app_shape.dart';

/// ===========================================================================
/// SUPERFICIE PULSABLE "STICKER"
/// ===========================================================================
///
/// Borde grueso + sombra maciza sin difuminar que, al pulsar, se desplaza
/// físicamente hasta cubrir su propia sombra: la tecla se hunde. La
/// profundidad la da el desplazamiento, no el desenfoque.
///
/// POR QUÉ IMPORTA. Las charlas de Apple sobre interfaces fluidas insisten en
/// que la respuesta al tacto tiene que ocurrir **al apoyar el dedo**, no al
/// levantarlo, y que tiene que ser continua durante el gesto. En cuanto
/// aparece retardo, la sensación de manipular algo directo "se cae por un
/// precipicio". En un lenguaje visual como este, además, el hundimiento no es
/// decoración: es lo que hace que un rectángulo con borde negro se lea como
/// un botón y no como una caja.
///
/// Lo que le faltaba a la versión anterior:
///
///   1. **No era un botón para VoiceOver.** Un `GestureDetector` pelado no
///      tiene rol ni etiqueta: el lector de pantalla anunciaba el contenido y
///      no decía que se pudiera pulsar.
///   2. **No respetaba "reducir movimiento".** Quien tiene activada esa
///      opción del sistema —a menudo por vértigo o migraña— seguía viendo el
///      desplazamiento.
///   3. **No tenía respuesta háptica**, que es la otra mitad del "se ha
///      pulsado" en iOS, y tiene que dispararse en el mismo instante que el
///      movimiento para que el cerebro los una.
///
/// Y un cuarto detalle: el área de toque no estaba garantizada. Ahora hay un
/// mínimo de 44x44, que es lo que piden las guías de Apple.
/// ===========================================================================
class NeoPressable extends StatefulWidget {
  const NeoPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = AppRadius.lg,
    this.borderWidth = AppBorder.normal,
    this.borderColor = AppColors.textPrimary,
    this.shadowColor = AppColors.textPrimary,
    this.shadowOffset = const Offset(4, 4),
    this.color,
    this.padding,
    this.semanticLabel,
    this.haptics = true,
    this.minTapTarget = 44,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final double borderWidth;
  final Color borderColor;
  final Color shadowColor;
  final Offset shadowOffset;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  /// Lo que dice VoiceOver. Si es null, se lee el contenido del hijo, que a
  /// veces basta (una tarjeta con su título dentro) y a veces no.
  final String? semanticLabel;

  /// Golpecito háptico al pulsar. Se desactiva en superficies grandes donde
  /// vibrar resultaría excesivo (una tarjeta de lista, por ejemplo).
  final bool haptics;

  /// Lado mínimo del área de toque, en puntos.
  final double minTapTarget;

  @override
  State<NeoPressable> createState() => _NeoPressableState();
}

class _NeoPressableState extends State<NeoPressable> {
  bool _pressed = false;

  bool get _isInteractive => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (!_isInteractive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (widget.haptics) HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final Offset restingOffset = widget.shadowOffset;
    final Offset currentShadowOffset = _pressed ? Offset.zero : restingOffset;
    final Offset translation = _pressed ? restingOffset : Offset.zero;

    final Widget surface = AnimatedContainer(
      // 80 ms: el mismo orden de magnitud que usa Apple en sus propios
      // ejemplos de estado pulsado. Más lento se siente pastoso; más rápido
      // no llega a verse.
      duration: reduceMotion ? Duration.zero : AppAnimation.press,
      curve: AppAnimation.enter,
      transform: Matrix4.translationValues(
        // Con "reducir movimiento" no se desplaza: solo se apaga la sombra,
        // que sigue comunicando el estado sin mover nada por la pantalla.
        reduceMotion ? 0 : translation.dx,
        reduceMotion ? 0 : translation.dy,
        0,
      ),
      padding: widget.padding,
      alignment: Alignment.center,
      constraints: BoxConstraints(
        minWidth: widget.minTapTarget,
        minHeight: widget.minTapTarget,
      ),
      decoration: BoxDecoration(
        color: widget.color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: widget.borderColor,
          width: widget.borderWidth,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: widget.shadowColor,
            offset: currentShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: widget.child,
    );

    return Semantics(
      button: _isInteractive,
      enabled: _isInteractive,
      label: widget.semanticLabel,
      // Con etiqueta propia, lo de dentro sobra: el lector leería el rótulo
      // dos veces.
      child: widget.semanticLabel == null
          ? _wrapGestures(surface)
          : ExcludeSemantics(child: _wrapGestures(surface)),
    );
  }

  Widget _wrapGestures(Widget surface) => GestureDetector(
    // `opaque`: sin esto, un toque en el relleno interior del botón no
    // contaba como toque.
    behavior: HitTestBehavior.opaque,
    onTap: _isInteractive ? _handleTap : null,
    onLongPress: widget.onLongPress,
    // Al APOYAR el dedo, no al levantarlo.
    onTapDown: (_) => _setPressed(true),
    onTapUp: (_) => _setPressed(false),
    onTapCancel: () => _setPressed(false),
    child: surface,
  );
}

/// Botón de acción principal con el mismo lenguaje: rótulo, icono opcional,
/// una línea de ayuda opcional y el hundimiento al pulsar.
///
/// Existe para que los botones importantes de la app dejen de ser cada uno de
/// su padre y su madre. Antes, cada pantalla montaba su propio
/// `Material` + `InkWell` + `Container`, y esa repetición ya había producido
/// un fallo real: una sombra sin difuminar sobre un contenedor sin color de
/// fondo se pinta como un rectángulo negro macizo por encima del color del
/// `Material`, y el botón salía negro en vez de coral.
class NeoActionButton extends StatelessWidget {
  const NeoActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.hint,
    this.background,
    this.foreground = AppColors.textPrimary,
    this.trailing,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Una línea que explica qué pasa al pulsar. Cuando un botón necesita
  /// explicación, escribirla es mejor que confiar en que se adivine.
  final String? hint;

  final Color? background;
  final Color foreground;
  final Widget? trailing;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: NeoPressable(
        onTap: onTap,
        borderRadius: AppRadius.md,
        shadowOffset: const Offset(3, 3),
        color: background ?? AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        semanticLabel: hint == null ? label : '$label. $hint',
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 22, color: foreground),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: hint == null
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                  if (hint != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      hint!,
                      // `textSecondary` mide 5,93:1 sobre blanco, pero solo
                      // **4,14:1** sobre el amarillo de marca — por debajo
                      // del mínimo, y precisamente en la frase que explica
                      // qué hay detrás del botón. Sobre amarillo se usa un
                      // gris más oscuro (5,10:1).
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: background == AppColors.primary
                            ? AppColors.textSecondaryOnPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
