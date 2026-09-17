import 'package:flutter_test/flutter_test.dart';

import 'package:palito_3_0/core/theme/components/group_switcher.dart';
import 'package:palito_3_0/features/onboarding/invite_partner_page.dart';

/// ===========================================================================
/// EL MENSAJE QUE SE PEGA EN WHATSAPP
/// ===========================================================================
///
/// Es el texto de la app que más gente lee y el único que nadie vuelve a
/// mirar: lo lee cada persona a la que invitan, en el momento en que se está
/// estrenando la app y no sabe dónde está nada.
///
/// Y se fue de la realidad. Decía «toca "Ver tus diarios y quién está en cada
/// uno"», un rótulo del Perfil que se mejoró hace tiempo y que ya no existe.
/// Había un comentario en el código avisando de que ese texto tenía que
/// coincidir «PALABRA POR PALABRA» con la pantalla, y no sirvió: un
/// comentario le pide cuidado a quien edita, y quien renombró el botón no
/// abrió ese fichero.
///
/// Esta prueba no pide cuidado. Comprueba.
void main() {
  test('el mensaje de invitación nombra rótulos que existen de verdad', () {
    final String camino = kComoCanjear;

    expect(
      camino,
      contains(kSeccionTusDiarios),
      reason:
          'El mensaje de invitación tiene que nombrar el titular real de la '
          'sección del Perfil.',
    );
    expect(
      camino,
      contains(kEntrarConCodigo),
      reason:
          'El mensaje de invitación tiene que nombrar la acción real de la '
          'hoja de diarios.',
    );

    // El rótulo viejo, por su nombre: si alguien lo vuelve a escribir a mano,
    // que se entere aquí y no el invitado.
    expect(
      camino.contains('Ver tus diarios'),
      isFalse,
      reason: 'Ese rótulo del Perfil ya no existe.',
    );

    // Y el rótulo del botón NO se puede nombrar: cambia según cuántos diarios
    // tengas, así que quien acaba de instalar la app lee otra cosa.
    for (final String variable in <String>[
      'Solo tienes tu diario privado',
      'Tu diario y uno compartido',
      'compartidos',
    ]) {
      expect(
        camino.contains(variable),
        isFalse,
        reason:
            'El mensaje no puede nombrar el rótulo del botón: cambia según '
            'cuántos diarios tenga cada persona.',
      );
    }
  });
}
