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

  /// Entrada de una PANTALLA entera, para el `transitionsBuilder` de una
  /// ruta.
  ///
  /// Vive aquí por la misma razón que lo de arriba, pero el caso es mucho
  /// peor: el `transitionsBuilder` de una ruta se llama **en cada fotograma**
  /// de la transición. Las dos rutas de la app construían ahí dentro un
  /// `CurvedAnimation`, o sea unos sesenta objetos por navegación, cada uno
  /// suscrito a la animación de la ruta y ninguno liberado. Y como todos
  /// siguen escuchando mientras dura la transición, el coste de cada
  /// fotograma va creciendo a medida que la transición avanza: la animación
  /// se va frenando justo según se acerca al final, que es cuando más se
  /// mira.
  ///
  /// `drive` con un `CurveTween` calcula exactamente lo mismo sin crear nada
  /// que haya que destruir. (Se puede prescindir de `reverseCurve` porque
  /// `AppAnimation.exit` y `AppAnimation.enter` son la misma curva.)
  static Widget pageIn(
    Animation<double> animation,
    Widget child, {
    Offset from = const Offset(0.06, 0.02),
    Curve curve = AppAnimation.enter,
  }) {
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: curve)),
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(
            begin: from,
            end: Offset.zero,
          ).chain(CurveTween(curve: curve)),
        ),
        child: child,
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // "REDUCIR MOVIMIENTO", EN UN SOLO SITIO
  // ═════════════════════════════════════════════════════════════════════════
  //
  // Flutter NO desactiva las animaciones implícitas por su cuenta: un
  // `AnimatedContainer` con `duration: 240ms` dura 240 ms aunque el sistema
  // tenga activado "Reducir movimiento". Hay que preguntarlo a mano en cada
  // sitio, y por eso se olvida: al contarlo, **trece ficheros de esta app
  // animaban sin preguntar**, entre ellos el formulario entero, que es donde
  // más se toca la app.
  //
  // Quien activa esa opción no lo hace por gusto: hay gente a la que el
  // movimiento en pantalla le produce mareo de verdad. Una app que lo ignora
  // no es que quede menos fina, es que le sienta mal a alguien.
  //
  // Se pregunta aquí y se responde en una línea.

  /// ¿Ha pedido esta persona menos movimiento?
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// La duración que toca: la pedida, o cero si se ha pedido menos
  /// movimiento. El cambio SIGUE OCURRIENDO — solo que instantáneo.
  static Duration dur(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;

  /// Lo mismo, para código que **no tiene un `BuildContext` a mano**.
  ///
  /// POR QUÉ HACE FALTA. Los campos del formulario que cambian según la
  /// categoría —`CroquetasFields`, `PostreFields`, `TortillaFields`…— no son
  /// widgets: son clases planas que implementan `DynamicFieldGenerator` y
  /// devuelven una lista de widgets. Sus métodos privados construyen
  /// `AnimatedSwitcher`, `AnimatedSize` y compañía sin recibir ningún
  /// contexto, y ahí estaban **dieciséis animaciones** que no preguntaban
  /// nada. Justo en el formulario, que es donde más se toca la app.
  ///
  /// Las salidas malas eran dos: pasar el contexto por toda la interfaz
  /// `DynamicFieldGenerator` (tocar ocho clases y la fábrica para mover un
  /// dato de accesibilidad), o envolver cada sitio en un `Builder` (dieciséis
  /// widgets de más y dieciséis reindentados a mano).
  ///
  /// `MediaQuery.disableAnimationsOf` lee exactamente ESTE valor: la bandera
  /// que el sistema operativo enciende cuando alguien activa "Reducir
  /// movimiento". Preguntarla directamente da la misma respuesta.
  ///
  /// LA DIFERENCIA, que hay que saberla: esto no ve un `MediaQuery` puesto a
  /// mano más arriba del árbol. Para un test que quiera simular la opción, o
  /// para una pantalla que quisiera forzarla en un trozo suyo, hay que usar
  /// [dur]. Para la opción real del sistema, que es de lo que se trata, las
  /// dos son la misma cosa.
  static Duration durFromPlatform(Duration d) =>
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
          .disableAnimations
      ? Duration.zero
      : d;

  // ═════════════════════════════════════════════════════════════════════════
  // ENTRADA ESCALONADA DE UNA LISTA
  // ═════════════════════════════════════════════════════════════════════════
  //
  // Esta cuenta estaba escrita a mano dentro de `home_page`:
  //
  //     final start = (0.55 + index * 0.045).clamp(0.55, 0.82);
  //     final end   = (start + 0.25).clamp(0.70, 1.00);
  //
  // Cuatro números mágicos que nadie más podía reutilizar, así que el resto
  // de listas de la app —los diarios, los comensales, los recuerdos del
  // mapa, el historial— aparecían de golpe. El escalón es lo que hace que
  // una lista se lea COMO una lista y no como un bloque que aterriza entero.
  //
  // El tope importa tanto como el escalón: sin él, la tarjeta número
  // cuarenta empezaría a entrar cuando la animación ya ha terminado, o sea
  // nunca. A partir del sexto elemento el ojo ya ha entendido el gesto y lo
  // único que queda es la espera, así que de ahí en adelante entran juntos.
  // Es la misma regla que ya usa `AppAnimation.stagger` para los retardos.

  /// La ventana de tiempo que le toca al elemento [index] dentro de la
  /// entrada de una lista.
  static Animation<double> listSlot(
    Animation<double> parent,
    int index, {
    int maxSteps = 6,
    double step = 0.055,
    double window = 0.35,
  }) {
    final double start = (index < maxSteps ? index : maxSteps) * step;
    final double end = (start + window).clamp(0.0, 1.0);
    // `drive`, no `CurvedAnimation`.
    //
    // Esto se llama desde el `itemBuilder` de una lista. Un
    // `CurvedAnimation` se suscribe al padre al construirse y solo lo suelta
    // su `dispose()`: recorrer doscientos recuerdos arriba y abajo dejaría
    // cientos de oyentes colgados del controlador, y ninguno se
    // desengancharía nunca. `drive` se engancha cuando alguien la escucha y
    // se suelta sola.
    return parent.drive(
      CurveTween(curve: Interval(start, end, curve: AppAnimation.enter)),
    );
  }

  /// Un elemento de lista entrando: opacidad y un empujón desde abajo.
  ///
  /// Solo `opacity` y `transform`, que son las dos propiedades que la GPU
  /// compone sin volver a medir nada. Animar altura o relleno en una lista
  /// obliga a recalcular el `layout` en cada fotograma de cada fila.
  static Widget listItem(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      // El `child` se pasa aparte a propósito: así el contenido de la fila se
      // construye UNA vez y en cada fotograma solo se vuelve a componer la
      // opacidad y el desplazamiento.
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double v = animation.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // EL MOVIMIENTO DICE HACIA DÓNDE HAS IDO
  // ═════════════════════════════════════════════════════════════════════════
  //
  // Las cuatro pestañas están en fila: Inicio, Mapa, La ruleta, Perfil. Pero
  // la transición entre ellas entraba SIEMPRE desde el mismo lado, fueras a
  // donde fueras. Así, pasar de Inicio a Perfil y de Perfil a Inicio se veían
  // exactamente igual, y el movimiento —que es lo único que puede contarlo—
  // no contaba nada.
  //
  // Esto importa más aquí que en otras apps. La queja de la gente que se
  // bajó Palito es que no sabe qué hace cada parte; y una barra de cuatro
  // iconos no dice por sí sola que hay un ORDEN, ni en qué punto de ese
  // orden estás. Si el contenido entra por la derecha cuando avanzas y por
  // la izquierda cuando retrocedes, la barra deja de ser cuatro botones
  // sueltos y pasa a ser una fila por la que te mueves. Eso se aprende sin
  // leer nada, en dos o tres toques.
  //
  // La pantalla que se va acompaña: se aparta hacia el lado contrario, medio
  // recorrido. Las dos se mueven como un par, que es lo que hace que se lea
  // como UNA cosa desplazándose y no como dos pantallas peleándose por el
  // mismo hueco.

  /// Cambio entre pantallas hermanas, con sentido.
  ///
  /// [dx] positivo = el contenido nuevo llega desde la derecha (has avanzado
  /// en la fila); negativo = desde la izquierda.
  ///
  /// [secondary] es la animación de ESTA pantalla cuando otra se le pone
  /// encima. Sin usarla, la que se va se queda quieta mientras la nueva se
  /// funde por delante: correcto, pero plano.
  static Widget pageSwap(
    Animation<double> animation,
    Animation<double> secondary,
    Widget child, {
    required double dx,
    double dy = 0.0,
  }) {
    final Widget entrando = FadeTransition(
      opacity: animation.drive(CurveTween(curve: AppAnimation.enter)),
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(
            begin: Offset(dx, dy),
            end: Offset.zero,
          ).chain(CurveTween(curve: AppAnimation.enter)),
        ),
      child: child,
      ),
    );

    return SlideTransition(
      position: secondary.drive(
        Tween<Offset>(
          begin: Offset.zero,
          // La mitad: la que se va cede el sitio, no huye.
          end: Offset(-dx * 0.5, 0),
        ).chain(CurveTween(curve: AppAnimation.enter)),
      ),
      child: entrando,
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

/// ===========================================================================
/// UN ELEMENTO QUE ENTRA SOLO
/// ===========================================================================
///
/// El hermano pequeño de [AppMotion.listSlot]. Aquel necesita que alguien
/// monte un `AnimationController` y lo mantenga vivo, que es lo correcto para
/// una lista perezosa de doscientos recuerdos: un reloj para todos.
///
/// Pero la mayor parte de las listas de esta app **no son eso**: son los
/// cinco diarios de una hoja, los seis logros de un panel, las cuatro reglas
/// del juego. Ahí montar un controlador, guardarlo, liberarlo y repartir
/// intervalos a mano es tanto trabajo que no se hace — y por eso todas esas
/// listas aparecían de golpe, de una pieza, como un cartel que se enciende.
///
/// Esto se envuelve alrededor de un hijo y ya está.
///
/// CUÁNDO **NO** USARLO: en un `ListView.builder` con muchos elementos. Cada
/// uno se traería su propio `AnimationController`, y un controlador por fila
/// visible es un reloj por fila. Para eso está `listSlot`.
class MotionItem extends StatefulWidget {
  const MotionItem({
    super.key,
    required this.index,
    required this.child,
    this.stepMs = 45,
    this.maxSteps = 6,
  });

  /// Su sitio en la lista. Marca cuánto espera antes de entrar.
  final int index;
  final Widget child;
  final int stepMs;

  /// A partir de aquí, todos entran a la vez. Sin tope, el elemento número
  /// treinta empezaría a moverse casi un segundo y medio después del primero
  /// — y quien tiene treinta elementos es justo quien más usa la pantalla.
  final int maxSteps;

  @override
  State<MotionItem> createState() => _MotionItemState();
}

class _MotionItemState extends State<MotionItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppAnimation.standard,
  );
  bool _launched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El `MediaQuery` no existe en `initState`, así que la decisión de
    // arrancar —o de no hacerlo— se toma aquí, y una sola vez.
    if (_launched) return;
    _launched = true;

    if (AppMotion.reduced(context)) {
      _c.value = 1.0;
      return;
    }

    final Duration espera = AppAnimation.stagger(
      widget.index,
      base: Duration.zero,
      stepMs: widget.stepMs,
      maxSteps: widget.maxSteps,
    );

    if (espera == Duration.zero) {
      _c.forward();
    } else {
      // `mounted` después de esperar: una hoja se puede cerrar antes de que
      // le toque entrar al último elemento, y llamar a `forward()` sobre un
      // controlador ya liberado revienta.
      Future<void>.delayed(espera, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppMotion.listItem(_c, widget.child);
}

/// Una columna cuyos hijos se van colocando de arriba abajo.
///
/// Existe para que una hoja entera pase a entrar escalonada **cambiando una
/// palabra**: donde ponía `Column` ahora pone `MotionColumn`. Sin esto, cada
/// hoja de la app tendría que envolver sus bloques uno a uno en
/// [MotionItem], y lo que pasa cuando algo cuesta ese trabajo es que no se
/// hace: por eso las hojas de esta app —las reglas del juego, el podio, el
/// resumen de la partida— se encendían enteras de golpe.
///
/// El orden importa más de lo que parece. Una hoja que aparece de una pieza
/// obliga a buscar por dónde empezar; una que se coloca de arriba abajo ya
/// ha dicho por dónde empezar antes de que termine de entrar.
class MotionColumn extends StatelessWidget {
  const MotionColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.startAt = 0,
    this.stepMs = 45,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  /// Desde qué escalón empieza a contar. Para encadenar dos columnas sin que
  /// la segunda vuelva a empezar por cero.
  final int startAt;

  final int stepMs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: <Widget>[
        for (int i = 0; i < children.length; i++)
          // ── UN `Expanded` NO SE PUEDE ENVOLVER ──
          //
          // `Expanded`, `Flexible` y `Spacer` no son widgets normales: son
          // `ParentDataWidget`, y hablan directamente con el `Column` que los
          // contiene para decirle cuánto sitio quieren. Si se mete algo en
          // medio —aquí, el `MotionItem`— dejan de ser hijos directos y
          // Flutter revienta en ejecución con "Incorrect use of
          // ParentDataWidget". No lo caza el analizador: se ve al abrir la
          // pantalla, y solo esa pantalla.
          //
          // Así que se dejan pasar tal cual. Pierden la entrada escalonada,
          // que es lo correcto: un `Spacer` es un hueco, no tiene nada que
          // entrar. Y así `MotionColumn` se puede poner en cualquier columna
          // de la app sin ir a comprobar antes qué lleva dentro.
          if (children[i] is Flexible || children[i] is Spacer)
            children[i]
          else
            MotionItem(
              index: i + startAt,
              stepMs: stepMs,
              child: children[i],
            ),
      ],
    );
  }
}

/// Lo que hace un botón cuando lo aprietas, para lo que no es un botón.
///
/// POR QUÉ. La app tiene su lenguaje de pulsación —la superficie se hunde
/// hasta tapar su propia sombra— y vive en [NeoPressable]. Pero hay sitios
/// donde no cabe un `NeoPressable`: una chincheta del mapa, el cuadro de la
/// foto del formulario, la caja del GPS. Eran `GestureDetector` pelados:
/// registran el toque y **no contestan nada**. Tocas, no pasa nada visible,
/// y durante un instante no sabes si te ha oído.
///
/// Esto es la versión mínima de esa misma idea: un encogimiento de un 4 %
/// mientras el dedo está apoyado. Un 4 % es poco a propósito — lo justo para
/// que se lea como "te he oído" y no como un rebote.
///
/// Responde al APOYAR el dedo, no al levantarlo: esperar a soltar es lo que
/// hace que una interfaz se sienta muerta aunque tarde lo mismo.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onTap == null || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: AppMotion.dur(context, AppAnimation.press),
        curve: AppAnimation.enter,
        child: widget.child,
      ),
    );
  }
}
