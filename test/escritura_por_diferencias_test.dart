import 'package:flutter_test/flutter_test.dart';
import 'package:palito_3_0/core/models/memory_model.dart';

/// ===========================================================================
/// EDITAR UN RECUERDO NO DEBE BORRAR EL DE OTRO
/// ===========================================================================
///
/// EL FALLO QUE ESTO EVITA, CONTADO COMO PASA.
///
/// María añade una foto a «Croquetas» desde su móvil. Juan abre la app con
/// mala cobertura, así que lo que ve sale de la caché de SU teléfono, donde
/// «Croquetas» todavía tiene una sola foto. Juan corrige una errata del
/// título y guarda.
///
/// Guardando el documento entero, los doce campos se escriben con los
/// valores de Juan y la foto de María desaparece. Sin conflicto, sin aviso,
/// sin forma de recuperarla. El `SetOptions(merge: true)` que hay en el
/// guardado no protege de esto: fusiona por CAMPO, y los doce campos van en
/// la escritura.
///
/// La única defensa es no mencionar lo que no se ha tocado.
///
/// POR QUÉ ESTAS PRUEBAS Y NO OTRAS. La comparación de listas y mapas es
/// donde esto se rompe de verdad: dos `List<String>` con los mismos
/// elementos son `!=` en Dart, así que una comparación por identidad
/// marcaría TODO como cambiado y el arreglo no serviría de nada — pasando
/// el analizador, pasando las demás pruebas y borrando fotos igual.
MemoryModel _recuerdo({
  String title = 'Croquetas',
  String restaurantName = 'Bar Pepe',
  List<String> imageUrls = const <String>['foto-1.jpg'],
  double rating = 4.0,
  bool wouldReturn = true,
  String category = 'Croquetas',
  Map<String, dynamic> specificFields = const <String, dynamic>{},
  LocationData? location,
}) {
  return MemoryModel(
    id: 'recuerdo-1',
    title: title,
    restaurantName: restaurantName,
    location:
        location ??
        const LocationData(address: 'Calle Feria 1', lat: 37.4, lng: -6.0),
    wouldReturn: wouldReturn,
    rating: rating,
    imageUrls: imageUrls,
    date: DateTime(2026, 9, 18),
    category: category,
    specificFields: specificFields,
    createdBy: 'uid-maria',
  );
}

void main() {
  group('Escritura por diferencias', () {
    test('sin cambios no se escribe nada más que el id', () {
      final MemoryModel base = _recuerdo();
      final Map<String, dynamic> cambios = _recuerdo().toFirestoreDiff(base);

      expect(
        cambios.keys,
        <String>['id'],
        reason:
            'Un guardado que no cambia nada no debe mencionar ningún campo: '
            'cada campo mencionado es un campo que pisa al servidor.',
      );
    });

    test('solo viaja el campo que se ha tocado', () {
      final MemoryModel base = _recuerdo();
      final Map<String, dynamic> cambios = _recuerdo(
        title: 'Croquetas de jamón',
      ).toFirestoreDiff(base);

      expect(cambios['title'], 'Croquetas de jamón');
      expect(
        cambios.containsKey('imageUrls'),
        isFalse,
        reason:
            'Este es el caso que borraba la foto de otro: cambiar el título '
            'no puede arrastrar la lista de fotos de la caché local.',
      );
      expect(cambios.containsKey('restaurantName'), isFalse);
      expect(cambios.containsKey('location'), isFalse);
    });

    test('dos listas con el mismo contenido no cuentan como cambio', () {
      // Listas distintas en memoria, mismo contenido. Comparadas por
      // identidad darían "cambiado" y arrastrarían las fotos otra vez.
      final MemoryModel base = _recuerdo(
        imageUrls: <String>['foto-1.jpg', 'foto-2.jpg'],
      );
      final Map<String, dynamic> cambios = _recuerdo(
        title: 'Otro título',
        imageUrls: <String>['foto-1.jpg', 'foto-2.jpg'],
      ).toFirestoreDiff(base);

      expect(cambios.containsKey('imageUrls'), isFalse);
    });

    test('dos mapas con el mismo contenido tampoco', () {
      final MemoryModel base = _recuerdo(
        specificFields: <String, dynamic>{'sabor': 'jamón', 'picante': false},
      );
      final Map<String, dynamic> cambios = _recuerdo(
        title: 'Otro título',
        specificFields: <String, dynamic>{'sabor': 'jamón', 'picante': false},
      ).toFirestoreDiff(base);

      expect(cambios.containsKey('specificFields'), isFalse);
    });

    test('añadir una foto sí viaja, y sola', () {
      final MemoryModel base = _recuerdo(
        imageUrls: <String>['foto-1.jpg'],
      );
      final Map<String, dynamic> cambios = _recuerdo(
        imageUrls: <String>['foto-1.jpg', 'foto-2.jpg'],
      ).toFirestoreDiff(base);

      expect(cambios['imageUrls'], <String>['foto-1.jpg', 'foto-2.jpg']);
      expect(cambios.containsKey('title'), isFalse);
    });

    test('cambiar la dirección viaja con sus coordenadas', () {
      final MemoryModel base = _recuerdo();
      final Map<String, dynamic> cambios = _recuerdo(
        location: const LocationData(
          address: 'Calle Betis 3',
          lat: 37.38,
          lng: -6.01,
        ),
      ).toFirestoreDiff(base);

      expect(cambios.containsKey('location'), isTrue);
      expect((cambios['location'] as Map<String, dynamic>)['lat'], 37.38);
    });

    test('un booleano que cambia no se confunde con uno que no', () {
      final MemoryModel base = _recuerdo(wouldReturn: true);

      expect(
        _recuerdo(wouldReturn: true).toFirestoreDiff(base).containsKey(
          'wouldReturn',
        ),
        isFalse,
      );
      expect(
        _recuerdo(wouldReturn: false).toFirestoreDiff(base)['wouldReturn'],
        isFalse,
      );
    });
  });
}
