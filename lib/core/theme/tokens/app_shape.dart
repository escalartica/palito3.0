import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Radios de esquina de la marca.
///
/// La app tenía **18 radios distintos** repartidos por las pantallas: 2, 4, 6,
/// 8, 9, 10, 11, 12, 14, 16, 18, 20, 21, 22, 24, 28, 32 y 999. Ninguno estaba
/// mal por sí solo; el problema es que juntos no forman un sistema, y esa
/// aleatoriedad es exactamente lo que hace que una interfaz "no parezca
/// terminada" aunque cada pantalla por separado esté bien resuelta.
///
/// Cinco pasos. Si hace falta un sexto, es que el diseño está pidiendo otra
/// cosa.
abstract final class AppRadius {
  /// Chips, insignias pequeñas, sellos.
  static const double xs = 8;

  /// Campos de formulario, botones pequeños, cajas de icono.
  static const double sm = 12;

  /// El radio por defecto: botones y tarjetas pequeñas.
  static const double md = 16;

  /// Tarjetas y paneles.
  static const double lg = 20;

  /// Hojas inferiores y superficies grandes.
  static const double xl = 24;

  /// Pastilla completa.
  static const double pill = 999;
}

/// Sombras "sticker": macizas, sin difuminar, desplazadas.
///
/// Había **16 desplazamientos distintos**, mezclando además dos lenguajes
/// incompatibles: sombras duras del neobrutalismo (4,4 / 3,3 / 2,2) y sombras
/// difuminadas de Material (0,2 con blur). Dos idiomas en la misma frase.
///
/// Tres pesos y nada más. El desplazamiento SIEMPRE es en diagonal y hacia
/// abajo-derecha, porque la luz de este lenguaje viene de arriba-izquierda y
/// tiene que venir del mismo sitio en toda la app.
abstract final class AppShadow {
  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(
      color: AppColors.textPrimary,
      offset: Offset(2, 2),
      blurRadius: 0,
    ),
  ];

  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(
      color: AppColors.textPrimary,
      offset: Offset(3, 3),
      blurRadius: 0,
    ),
  ];

  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(
      color: AppColors.textPrimary,
      offset: Offset(4, 4),
      blurRadius: 0,
    ),
  ];

  /// Sin sombra: el estado "pulsado", cuando la superficie se ha hundido
  /// hasta taparla.
  static const List<BoxShadow> none = <BoxShadow>[];
}

/// Grosores de borde. Eran cuatro (1,5 / 2 / 2,5 / 3); son dos.
abstract final class AppBorder {
  /// Separadores y bordes interiores.
  static const double thin = 1.5;

  /// El borde de marca.
  static const double normal = 2;
}

/// ===========================================================================
/// RECORTADO A MANO
/// ===========================================================================
///
/// Los cuatro radios de una esquina, distintos entre sí.
///
/// Una fila de pastillas con el mismo radio en las cuatro esquinas se lee
/// como lo que es: un molde repetido. Basta con que cada etiqueta tenga su
/// propia combinación de esquinas para que la fila entera pase a leerse como
/// algo recortado con tijeras — que es justo el idioma del logo de Palito,
/// una pegatina dibujada a mano.
///
/// DOS REGLAS QUE HACEN QUE ESTO FUNCIONE Y NO PAREZCA UN FALLO:
///
///   1. **La forma depende del texto, no del azar.** Si saliera de un
///      `Random`, la chip cambiaría de silueta en cada reconstrucción y eso
///      no se lee como artesanía, se lee como un error de dibujado.
///      "Croquetas" tendrá siempre exactamente las mismas esquinas.
///
///   2. **Las combinaciones están elegidas a mano, no generadas.** Seis
///      cuartetos, todos comprobados. Con valores al azar tarde o temprano
///      sale uno con las cuatro esquinas casi iguales —que parece un radio
///      mal puesto— o uno tan deforme que parece un glifo roto.
abstract final class AppHandCut {
  /// Seis siluetas. (arriba-izq, arriba-der, abajo-der, abajo-izq).
  static const List<List<double>> _shapes = <List<double>>[
    <double>[20, 10, 20, 10], // hoja
    <double>[10, 20, 10, 20], // hoja al revés
    <double>[22, 14, 10, 18],
    <double>[12, 22, 16, 10],
    <double>[18, 10, 22, 12],
    <double>[10, 18, 12, 22],
  ];

  /// La silueta que le toca a este texto. Siempre la misma.
  static BorderRadius of(String seed) {
    int hash = 0;
    for (int i = 0; i < seed.length; i++) {
      hash = (hash + seed.codeUnitAt(i) * (i + 3)) & 0x7fffffff;
    }
    final List<double> s = _shapes[hash % _shapes.length];
    return BorderRadius.only(
      topLeft: Radius.circular(s[0]),
      topRight: Radius.circular(s[1]),
      bottomRight: Radius.circular(s[2]),
      bottomLeft: Radius.circular(s[3]),
    );
  }
}
