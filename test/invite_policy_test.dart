import 'package:flutter_test/flutter_test.dart';
import 'package:palito_3_0/core/data/invite_policy.dart';

void main() {
  final DateTime now = DateTime(2026, 9, 16, 12);

  InviteLife invite({
    String code = 'K7M4PQR2',
    int usesLeft = 9,
    Duration expiresIn = const Duration(days: 6),
  }) {
    return InviteLife(
      code: code,
      usesLeft: usesLeft,
      expiresAt: now.add(expiresIn),
    );
  }

  group('reutilizar una invitación', () {
    test('una invitación con usos y vida por delante se reutiliza', () {
      expect(InvitePolicy.isReusable(invite(), now), isTrue);
    });

    test('una invitación sin usos no se reutiliza', () {
      expect(InvitePolicy.isReusable(invite(usesLeft: 0), now), isFalse);
    });

    test('una invitación que caduca esta tarde no se reutiliza', () {
      // El mensaje se envía hoy y se abre mañana: enseñar un código con dos
      // horas de vida es peor que dar uno nuevo.
      expect(
        InvitePolicy.isReusable(
          invite(expiresIn: const Duration(hours: 2)),
          now,
        ),
        isFalse,
      );
    });

    test('elige la que más usos le quedan, no la más nueva', () {
      final InviteLife pocos = invite(
        code: 'AAAAAAAA',
        usesLeft: 2,
        expiresIn: const Duration(days: 7),
      );
      final InviteLife muchos = invite(
        code: 'BBBBBBBB',
        usesLeft: 8,
        expiresIn: const Duration(days: 3),
      );

      expect(
        InvitePolicy.pickReusable(<InviteLife>[pocos, muchos], now)?.code,
        'BBBBBBBB',
      );
    });

    test('a igualdad de usos, la que más tarda en caducar', () {
      final InviteLife pronto = invite(
        code: 'AAAAAAAA',
        expiresIn: const Duration(days: 2),
      );
      final InviteLife tarde = invite(
        code: 'BBBBBBBB',
        expiresIn: const Duration(days: 6),
      );

      expect(
        InvitePolicy.pickReusable(<InviteLife>[pronto, tarde], now)?.code,
        'BBBBBBBB',
      );
    });

    test('sin ninguna reutilizable devuelve null', () {
      expect(
        InvitePolicy.pickReusable(
          <InviteLife>[invite(usesLeft: 0), invite(expiresIn: Duration.zero)],
          now,
        ),
        isNull,
      );
    });
  });

  group('cómo se lee en pantalla', () {
    test('plural y singular de las personas', () {
      expect(
        InvitePolicy.describe(invite(usesLeft: 1), now),
        startsWith('Vale para 1 persona más'),
      );
      expect(
        InvitePolicy.describe(invite(usesLeft: 4), now),
        startsWith('Vale para 4 personas más'),
      );
    });

    test('un día se dice "mañana", no "en 1 días"', () {
      expect(
        InvitePolicy.describe(invite(expiresIn: const Duration(days: 1)), now),
        endsWith('caduca mañana'),
      );
    });

    test('un código recién creado de 7 días no dice 6', () {
      // `Duration.inDays` trunca: 6 días, 23 h y 59 min daban "6 días".
      // Es el caso REAL —un código que se acaba de generar— y no lo cogía
      // ninguna prueba porque todas usaban duraciones exactas.
      expect(
        InvitePolicy.describe(
          invite(expiresIn: const Duration(days: 7) - const Duration(minutes: 1)),
          now,
        ),
        endsWith('caduca en 7 días'),
      );
    });

    test('menos de un día se cuenta en horas', () {
      expect(
        InvitePolicy.describe(invite(expiresIn: const Duration(hours: 5)), now),
        endsWith('caduca en 5 horas'),
      );
    });
  });

  group('pegar un código', () {
    test('el portapapeles es exactamente el código', () {
      expect(InvitePolicy.codeFromSharedText('K7M4PQR2'), 'K7M4PQR2');
    });

    test('se acepta en minúsculas y con espacios alrededor', () {
      expect(InvitePolicy.codeFromSharedText('  k7m4pqr2 \n'), 'K7M4PQR2');
    });

    test('se rescata del mensaje de invitación completo', () {
      // Copia del mensaje real de `invite_partner_page.dart`. Si allí cambia
      // la redacción, esta copia se queda vieja sin que nada avise: el
      // parser seguiría pasando el test con un mensaje que ya nadie envía.
      // Por eso se actualiza a mano cada vez que cambia el original — y por
      // eso lo que el parser ancla es la palabra "código", no la frase.
      const String mensaje =
          'Te invito a mi diario en Palito de Sabores 🍽️\n\n'
          'Código: K7M4PQR2\n\n'
          'Descarga la app, inicia sesión con Apple y ve a la pestaña Perfil.';

      expect(InvitePolicy.codeFromSharedText(mensaje), 'K7M4PQR2');
    });

    test(
      'no confunde una palabra de ocho letras del propio mensaje con el código',
      () {
        // "DESCARGA" tiene ocho caracteres y todos están en el alfabeto: sin
        // el ancla "código" el botón Pegar la daría por buena. Esta es la
        // razón de que el ancla exista.
        expect(InvitePolicy.isWellFormedCode('DESCARGA'), isTrue);

        const String sinCodigo =
            'Descarga la app e inicia sesión con Apple para verlo.';

        expect(InvitePolicy.codeFromSharedText(sinCodigo), isNull);
      },
    );

    test('vale "código" sin dos puntos', () {
      expect(
        InvitePolicy.codeFromSharedText('mi codigo es K7M4PQR2, úsalo'),
        'K7M4PQR2',
      );
    });

    test('un código con letras prohibidas no es válido', () {
      // O, 0, I y 1 no existen en el alfabeto.
      expect(InvitePolicy.isWellFormedCode('K7M4PQRO'), isFalse);
      expect(InvitePolicy.isWellFormedCode('K7M4PQR1'), isFalse);
    });

    test('portapapeles vacío o nulo', () {
      expect(InvitePolicy.codeFromSharedText(null), isNull);
      expect(InvitePolicy.codeFromSharedText('   '), isNull);
    });
  });
}
