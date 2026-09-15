import 'package:latlong2/latlong.dart';

/// Encuadre geográfico: el centro al que ir y cuánto mundo hay que abarcar.
///
/// Existe en vez de `LatLngBounds` porque el ancho ([longitudeSpan]) puede
/// cruzar el antimeridiano, y unos límites este/oeste no saben expresar eso:
/// «de 139 a -118» son dos trozos de mundo distintos según por dónde se vaya.
class GeoFit {
  const GeoFit({
    required this.center,
    required this.longitudeSpan,
    required this.north,
    required this.south,
  });

  final LatLng center;

  /// Grados de longitud que hay que abarcar, siempre por el camino corto.
  final double longitudeSpan;

  final double north;
  final double south;
}

/// Encuadre que contiene todos los puntos, **por el camino corto**.
///
/// `LatLngBounds.fromPoints` toma la longitud mínima y la máxima y las une
/// tal cual. Con todos los platos en España eso da el resultado correcto.
/// Con un plato en Tokio (139° Este) y otro en Los Ángeles (118° Oeste) da un
/// ancho de 257 grados y un centro en algún punto de Asia Central: la cámara
/// se va a Kazajistán y los dos marcadores quedan en bordes opuestos de la
/// pantalla, o fuera. El camino corto entre esos dos puntos son 103 grados
/// cruzando el Pacífico, no 257 cruzando el resto del planeta.
///
/// El método: se ordenan las longitudes y se busca el **hueco más grande**
/// entre dos consecutivas, contando también el que va de la última a la
/// primera dando la vuelta por el antimeridiano. Ese hueco es el trozo de
/// mundo donde no hay nada, así que el encuadre es todo lo demás: 360 menos
/// el hueco. El centro es el punto medio del arco ocupado.
///
/// Para un diario entero en España el hueco más grande es justamente el que
/// da la vuelta al planeta, y el resultado coincide con el de toda la vida.
/// Solo cambia cuando hace falta.
///
/// Vive fuera de `map_page.dart` porque es aritmética pura sobre una lista de
/// coordenadas —sin widgets, sin cámara, sin Firestore— y por tanto es la
/// única parte del mapa que se puede probar de verdad. Ver
/// `test/map_fit_test.dart`.
GeoFit computeGeoFit(List<LatLng> points) {
  if (points.isEmpty) {
    return const GeoFit(
      center: LatLng(0, 0),
      longitudeSpan: 360,
      north: 0,
      south: 0,
    );
  }

  double north = points.first.latitude;
  double south = points.first.latitude;

  for (final LatLng p in points) {
    if (p.latitude > north) north = p.latitude;
    if (p.latitude < south) south = p.latitude;
  }

  final List<double> lons = points.map((LatLng p) => p.longitude).toList()
    ..sort();

  double largestGap = -1;
  double gapStart = lons.last;

  for (int i = 0; i < lons.length; i++) {
    final double a = lons[i];
    final double b = i == lons.length - 1 ? lons.first + 360 : lons[i + 1];
    final double gap = b - a;

    if (gap > largestGap) {
      largestGap = gap;
      gapStart = a;
    }
  }

  // El arco ocupado empieza donde acaba el hueco y mide lo que no es hueco.
  final double span = 360 - largestGap;
  final double arcStart = gapStart + largestGap;

  double centerLon = arcStart + span / 2;
  while (centerLon > 180) {
    centerLon -= 360;
  }
  while (centerLon < -180) {
    centerLon += 360;
  }

  return GeoFit(
    center: LatLng((north + south) / 2, centerLon),
    longitudeSpan: span,
    north: north,
    south: south,
  );
}
