import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

/// ===========================================================================
/// LA CINTA DE CIFRAS
/// ===========================================================================
///
/// Una banda oscura a todo el ancho con los números de quien la mira, en
/// versalitas muy espaciadas, desfilando despacio hacia la izquierda.
///
/// POR QUÉ. Los mismos datos ya estaban en la app, repartidos en cajitas:
/// "3 Registros", "3.5 Nota media", "100% Volverías". Una cajita con un
/// número dentro es un dato. La misma cifra dicha seguida —"3 RECUERDOS ◆
/// NOTA MEDIA 3,5 ◆ VOLVERÍAS AL 100 % ◆ TU DEBILIDAD: CROQUETAS"— ya no es
/// un dato, es un retrato. Es la diferencia entre una ficha y una frase.
///
/// ACCESIBILIDAD, que aquí no es opcional:
///
///   • **Se puede parar.** La WCAG (2.2.2) exige que cualquier cosa que se
///     mueva sola más de cinco segundos junto a otro contenido se pueda
///     detener. Un toque la para; otro la reanuda.
///   • **Con "Reducir movimiento" nace quieta.** Ni un píxel.
///   • **Para un lector de pantalla no desfila nada:** el contenido visual
///     se excluye y se anuncia una sola frase con todas las cifras
///     seguidas. Perseguir texto en movimiento con VoiceOver es imposible.
///   • **Cifras de ancho fijo**, o los números bailan al desplazarse.
/// ===========================================================================
class StatsTicker extends StatefulWidget {
  const StatsTicker({
    super.key,
    required this.items,
    this.height = 44,
    this.pixelsPerSecond = 26,
  });

  /// Las frases, ya escritas. Van en mayúsculas.
  final List<String> items;

  final double height;

  /// Despacio a propósito: esto se lee, no se persigue.
  final double pixelsPerSecond;

  @override
  State<StatsTicker> createState() => _StatsTickerState();
}

class _StatsTickerState extends State<StatsTicker>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El MediaQuery no existe en initState, así que la decisión de arrancar
    // o no se toma aquí.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _running = false;
      if (_ticker?.isActive ?? false) _ticker!.stop();
    } else if (_running && !(_ticker?.isActive ?? true)) {
      _lastTick = Duration.zero;
      _ticker!.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (!_scroll.hasClients) return;
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final double dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    // `jumpTo` y no `animateTo`: el movimiento constante lo marca el reloj de
    // la pantalla, no una curva. Una curva aquí produciría tirones.
    _scroll.jumpTo(_scroll.offset + widget.pixelsPerSecond * dt);
  }

  void _toggle() {
    setState(() {
      _running = !_running;
      if (_running) {
        _lastTick = Duration.zero;
        _ticker?.start();
      } else {
        _ticker?.stop();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      // Una sola frase, con todo dentro. Quien usa VoiceOver se entera de
      // sus cifras sin tener que cazar nada.
      label: widget.items.join('. '),
      button: !reduceMotion,
      // El `onTap` tiene que estar TAMBIÉN aquí, no solo en el
      // `GestureDetector` de dentro: el `ExcludeSemantics` de abajo se traga
      // la acción del gesto, así que este nodo anunciaba "botón" sin
      // registrar ninguna acción de pulsación. Con VoiceOver, el doble toque
      // no paraba la cinta.
      onTap: reduceMotion ? null : _toggle,
      hint: reduceMotion
          ? null
          : (_running ? 'Toca para detener el desfile' : 'Toca para reanudarlo'),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: reduceMotion ? null : _toggle,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // El borde de arriba no es una línea recta: es una fila de
              // ondas. Una banda rectangular sobre un fondo liso es una
              // barra de interfaz; con el borde ondulado es una tira
              // recortada, que es el idioma del logo de la app.
              const _ScallopEdge(),
              Container(
            height: widget.height,
            color: AppColors.textPrimary,
            alignment: Alignment.centerLeft,
            child: ListView.builder(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              // Nadie la arrastra con el dedo: el gesto es el toque para
              // parar, y un arrastre competiría con él.
              physics: const NeverScrollableScrollPhysics(),
              // Sin itemCount: la lista no termina nunca, así que no hay
              // salto al volver al principio. Flutter solo construye lo que
              // cabe en pantalla.
              itemBuilder: (BuildContext context, int index) =>
                  _TickerItem(text: widget.items[index % widget.items.length]),
            ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La fila de ondas del borde superior. Semicírculos del color de la banda,
/// apoyados sobre ella: desde arriba, la tira parece cortada con tijeras de
/// bordes redondeados.
class _ScallopEdge extends StatelessWidget {
  const _ScallopEdge();

  /// 7 puntos: unas 28 ondas en un iPhone. Más grandes se leen como globos;
  /// más pequeñas, como un borde mal antialiasado.
  static const double _radius = 7;

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: _radius,
    width: double.infinity,
    child: CustomPaint(
      painter: _ScallopPainter(radius: _radius, color: AppColors.textPrimary),
    ),
  );
}

class _ScallopPainter extends CustomPainter {
  const _ScallopPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    // Se dibuja una onda de más por cada lado para que en ningún ancho de
    // pantalla quede media onda cortada contra el borde.
    final int count = (size.width / (radius * 2)).ceil() + 1;
    for (int i = -1; i < count; i++) {
      canvas.drawCircle(
        Offset(radius + i * radius * 2, radius),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScallopPainter old) =>
      old.radius != radius || old.color != color;
}

class _TickerItem extends StatelessWidget {
  const _TickerItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          text.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            // Muy espaciado. Es lo que convierte un rótulo en una cinta: sin
            // este aire las mayúsculas se apelmazan y se leen como un grito.
            letterSpacing: 1.6,
            height: 1,
            color: AppColors.background,
            fontFeatures: AppTypography.tabular,
          ),
        ),
        const SizedBox(width: 18),
        // El separador es un cuadrado girado, no un carácter: un glifo de
        // rombo o de destello no está en todas las fuentes y, cuando falta,
        // sale el rectángulo vacío.
        Transform.rotate(
          angle: 0.785398, // 45°
          child: Container(width: 6, height: 6, color: AppColors.primary),
        ),
        const SizedBox(width: 18),
      ],
    );
  }
}
