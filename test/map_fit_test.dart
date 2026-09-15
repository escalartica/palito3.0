import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:palito_3_0/features/map/map_fit.dart';

/// Pruebas del encuadre del mapa.
///
/// El caso que las motiva es el antimeridiano: con un plato en Tokio y otro
/// en Los Ángeles, el cálculo de toda la vida manda la cámara a Kazajistán.
/// Es un fallo que no se puede ver probando la app desde España, así que si
/// no está aquí no está en ninguna parte.
void main() {
  group('computeGeoFit', () {
    test('un diario entero en España se comporta como siempre', () {
      // Sevilla, Madrid, Zamora.
      final GeoFit fit = computeGeoFit(<LatLng>[
        const LatLng(37.39, -5.98),
        const LatLng(40.42, -3.70),
        const LatLng(41.50, -5.75),
      ]);

      expect(fit.longitudeSpan, closeTo(2.28, 0.01));
      expect(fit.center.longitude, closeTo(-4.84, 0.01));
      expect(fit.north, closeTo(41.50, 0.01));
      expect(fit.south, closeTo(37.39, 0.01));
    });

    test('Tokio y Los Ángeles se encuadran por el Pacífico, no por Asia', () {
      final GeoFit fit = computeGeoFit(<LatLng>[
        const LatLng(35.68, 139.69), // Tokio
        const LatLng(34.05, -118.24), // Los Ángeles
      ]);

      // Por el camino largo serían 257,93 grados.
      expect(fit.longitudeSpan, closeTo(102.07, 0.01));

      // Y el centro cae en mitad del Pacífico (169,28° Oeste), no en Asia
      // Central, que es donde lo ponía el cálculo anterior.
      expect(fit.center.longitude, closeTo(-169.28, 0.01));
    });

    test('un solo punto da ancho cero y se centra en él', () {
      final GeoFit fit = computeGeoFit(<LatLng>[const LatLng(19.43, -99.13)]);

      expect(fit.longitudeSpan, closeTo(0, 0.0001));
      expect(fit.center.latitude, closeTo(19.43, 0.01));
      expect(fit.center.longitude, closeTo(-99.13, 0.01));
    });

    test('dos puntos opuestos en el globo no se van fuera de rango', () {
      final GeoFit fit = computeGeoFit(<LatLng>[
        const LatLng(0, 0),
        const LatLng(0, 180),
      ]);

      expect(fit.center.longitude, inInclusiveRange(-180, 180));
      expect(fit.longitudeSpan, closeTo(180, 0.01));
    });

    test('el centro siempre queda dentro de -180 y 180', () {
      for (final List<LatLng> points in <List<LatLng>>[
        <LatLng>[const LatLng(0, 179), const LatLng(0, -179)],
        <LatLng>[const LatLng(0, -175), const LatLng(0, 170)],
        <LatLng>[const LatLng(0, 10), const LatLng(0, -170)],
      ]) {
        final GeoFit fit = computeGeoFit(points);
        expect(fit.center.longitude, inInclusiveRange(-180, 180));
        expect(fit.longitudeSpan, inInclusiveRange(0, 360));
      }
    });

    test('dos puntos a un lado y otro del antimeridiano casi se tocan', () {
      // 179° Este y 179° Oeste están a dos grados, no a 358.
      final GeoFit fit = computeGeoFit(<LatLng>[
        const LatLng(0, 179),
        const LatLng(0, -179),
      ]);

      expect(fit.longitudeSpan, closeTo(2, 0.01));
      expect(fit.center.longitude.abs(), closeTo(180, 0.01));
    });

    test('una lista vacía no revienta', () {
      final GeoFit fit = computeGeoFit(<LatLng>[]);
      expect(fit.longitudeSpan, 360);
    });
  });
}
