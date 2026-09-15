import 'package:flutter/material.dart';

/// ===========================================================================
/// EL VOCABULARIO DEL MOVIMIENTO
/// ===========================================================================
///
/// Este fichero existía ya, pero solo a medias: definía cuatro tiempos y nadie
/// los usaba. Al contarlos seguían vivos **74 números sueltos** repartidos por
/// la app (de 80 ms a 1200 ms) y **62 curvas** elegidas a ojo. Un lenguaje con
/// setenta y cuatro palabras para decir "rápido" no es un lenguaje.
///
/// Dos decisiones gobiernan todo lo de abajo.
///
/// ── 1. NADA DE CURVAS DE SERIE ──
///
/// `Curves.easeOutCubic` y compañía son correctas y son sosas: frenan
/// demasiado pronto y el movimiento se queda sin carácter. Las curvas de aquí
/// son las que usa la gente que se dedica a esto. Salen disparadas y frenan al
/// final, que es donde el ojo mira.
///
/// ── 2. NUNCA `ease-in` EN LA INTERFAZ ──
///
/// `ease-in` empieza despacio. El instante en que el usuario más está mirando
/// es justo el primero, y ahí no pasa nada: la interfaz se siente lenta aunque
/// el cronómetro diga lo mismo. Una salida no se arregla con una curva que
/// arranca mal, se arregla **acortándola**. Por eso `exit` usa la misma curva
/// que `enter` y lo que cambia es el tiempo.
///
/// Regla de oro que ordena la tabla de duraciones: **por debajo de 300 ms**
/// todo lo que sea interfaz. Lo que pasa de ahí es una coreografía completa,
/// un recorrido largo o algo que solo se ve una vez.
/// ===========================================================================
abstract final class AppAnimation {
  // ───────────────────────────────────────────────────────── DURACIONES ──

  /// Respuesta al tacto: el hundimiento de un botón. Tiene que ser
  /// imperceptible como animación y perfectamente perceptible como respuesta.
  static const Duration press = Duration(milliseconds: 90);

  /// Cambios pequeños en sitio: un chip que se marca, un icono que cambia,
  /// un color que vira.
  static const Duration fast = Duration(milliseconds: 160);

  /// El tiempo por defecto: aparecer, desaparecer, desplegar, plegar.
  static const Duration standard = Duration(milliseconds: 240);

  /// Recorridos: una hoja que sube, una pantalla que entra, una foto que se
  /// coloca. El techo de la interfaz.
  static const Duration slow = Duration(milliseconds: 340);

  /// Las salidas son más rápidas que las entradas. Entrar es una presentación
  /// y merece tiempo; salir es quitarse de en medio y cuanto antes mejor.
  /// Que una hoja tarde lo mismo en irse que en venir es de las cosas que se
  /// notan sin saber qué se está notando.
  static const Duration exitFast = Duration(milliseconds: 180);

  /// La coreografía de entrada de una pantalla **entera**, escalonada de
  /// arriba abajo. No es el tiempo de un elemento: es el de todos.
  ///
  /// Estaba en 1100 ms en Inicio y 900 ms en Perfil, en el Detalle y en el
  /// formulario. Eso es más de un segundo montándose la pantalla delante de
  /// alguien que abre la app veinte veces al día. Cada elemento sigue
  /// entrando escalonado —el escalón es lo que hace que se lea como una
  /// pantalla y no como cinco cosas sueltas— pero el conjunto cabe ahora en
  /// medio segundo.
  static const Duration entry = Duration(milliseconds: 520);

  /// Un dato que se dibuja solo: una barra que se llena, un número que sube.
  /// Aquí el tiempo *es* la información, así que puede pasar de 300 ms.
  static const Duration reveal = Duration(milliseconds: 520);

  /// Vuelta completa de un indicador de carga. Un indicador rápido hace que
  /// la espera se perciba más corta aunque dure exactamente lo mismo.
  static const Duration spinner = Duration(milliseconds: 700);

  /// Latido de ida y vuelta de algo que está esperando atención.
  static const Duration pulse = Duration(milliseconds: 1200);

  /// Vuelo de la cámara del mapa. Es un desplazamiento real sobre un
  /// territorio, no un elemento de interfaz: si va rápido se pierde el
  /// sentido de a dónde se ha ido.
  static const Duration camera = Duration(milliseconds: 750);

  // ────────────────────────────────────────────────────────── ESCALONADO ──

  /// Retardo escalonado **con tope**.
  ///
  /// Había cuatro sitios con la misma fórmula y el mismo fallo:
  /// `Duration(milliseconds: 350 + index * 45)`. Sin techo. Con quince
  /// platos en la lista, el último tardaba **un segundo entero** en
  /// aparecer, y quien tiene quince platos es justo quien más usa la app.
  ///
  /// El escalón sirve para que la lista se lea como una lista y no como un
  /// bloque. Para eso bastan los primeros; a partir del sexto, el ojo ya ha
  /// entendido el gesto y lo único que queda es la espera. Así que se corta
  /// ahí y todo lo demás entra a la vez.
  static Duration stagger(
    int index, {
    Duration base = standard,
    int stepMs = 45,
    int maxSteps = 6,
  }) => Duration(
    milliseconds:
        base.inMilliseconds + stepMs * (index < maxSteps ? index : maxSteps),
  );

  // ───────────────────────────────────────────────────────────── CURVAS ──

  /// Entrada. `cubic-bezier(0.23, 1, 0.32, 1)`.
  ///
  /// Sale disparada y frena largo. Es la curva por defecto de la app: en el
  /// 90 % de los casos, esta.
  static const Curve enter = Cubic(0.23, 1.00, 0.32, 1.00);

  /// Salida. La misma que la entrada, a propósito (ver la cabecera). Lo que
  /// distingue una salida es que dura [exitFast], no que frene distinto.
  static const Curve exit = enter;

  /// Para lo que empieza y termina **dentro** de la pantalla: algo que se
  /// desplaza de un sitio a otro sin entrar ni salir.
  /// `cubic-bezier(0.77, 0, 0.175, 1)`.
  static const Curve inOut = Cubic(0.77, 0.00, 0.175, 1.00);

  /// Hojas y cajones. La curva del propio iOS: arranca decidida y aterriza
  /// sin rebote, como algo que pesa.
  /// `cubic-bezier(0.32, 0.72, 0, 1)`.
  static const Curve sheet = Cubic(0.32, 0.72, 0.00, 1.00);

  /// Aparición con un punto de chulería: se pasa un poco de largo y vuelve.
  ///
  /// Sustituye a `Curves.easeOutBack`, que se pasa un **27 %** — a tamaño de
  /// chip eso no se lee como energía, se lee como un error de cálculo. Este
  /// se pasa un 14 %.
  static const Curve pop = Cubic(0.175, 0.885, 0.32, 1.14);

  /// El premio. Solo para el momento en que la ruleta canta un nombre: algo
  /// que pasa poco y que la gente quiere que se celebre.
  ///
  /// Sustituye a `Curves.elasticOut`, que oscila cuatro veces antes de
  /// pararse. Un rebote está bien; cuatro es un muelle roto.
  static const Curve celebrate = Cubic(0.175, 0.885, 0.32, 1.45);

  /// Cambios de color y de opacidad al pasar por encima. Simétrica a
  /// propósito: no entra ni sale nada, solo vira.
  static const Curve tint = Curves.ease;
}
