import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:palito_3_0/main.dart';

void main() {
testWidgets(
'La aplicación Palito de Sabores se construye correctamente',
(WidgetTester tester) async {
// Construimos la aplicación dentro de ProviderScope,
// igual que en la función main() de la aplicación.
await tester.pumpWidget(
const ProviderScope(
child: PalitoDeSaboresApp(),
),
);


  // Esperamos a que se completen las animaciones y
  // las construcciones iniciales de los widgets.
  await tester.pumpAndSettle();

  // Verificamos que la aplicación se ha construido
  // correctamente comprobando su título.
  expect(
    find.text('Palito de Sabores'),
    findsOneWidget,
  );
},


);
}
