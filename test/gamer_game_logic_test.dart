import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:palito_3_0/features/gamer/gamer_game_logic.dart';

void main() {
  group('GamerGameLogic.computeSpinOutcome', () {
    test('modo 0 (Ruleta Pro) otorga 5 puntos, sin medalla ni reto', () {
      final outcome = GamerGameLogic.computeSpinOutcome(
        selectedMode: 0,
        challenges: const ['reto único'],
        random: Random(),
      );

      expect(outcome.pointsAwarded, 5);
      expect(outcome.awardsMedal, isFalse);
      expect(outcome.eventDetail, 'Ruleta Pro: Elección de Plato');
      expect(outcome.historyDetail, '🍽️ ¡Le toca elegir plato!');
      expect(outcome.challenge, isNull);
    });

    test('cualquier modo distinto de 0 (Juicio Picante) otorga 10 puntos, '
        'medalla, y elige un reto de la lista', () {
      final outcome = GamerGameLogic.computeSpinOutcome(
        selectedMode: 1,
        challenges: const ['único reto disponible'],
        random: Random(),
      );

      expect(outcome.pointsAwarded, 10);
      expect(outcome.awardsMedal, isTrue);
      expect(outcome.eventDetail, 'Juicio Picante');
      expect(outcome.historyDetail, '🔥 Juicio Picante asignado');
      expect(outcome.challenge, 'único reto disponible');
    });

    test('el reto elegido en Juicio Picante siempre pertenece a la lista '
        'recibida', () {
      const challenges = ['a', 'b', 'c', 'd', 'e'];
      final random = Random(42);

      for (var i = 0; i < 20; i++) {
        final outcome = GamerGameLogic.computeSpinOutcome(
          selectedMode: 1,
          challenges: challenges,
          random: random,
        );

        expect(challenges, contains(outcome.challenge));
      }
    });
  });

  group('GamerGameLogic.achievementProgress / isAchievementMet', () {
    bool met(
      String id, {
      int maxPoints = 0,
      int decisionsCount = 0,
      int playerCount = 0,
      int playersWithPoints = 0,
      int maxMedals = 0,
    }) {
      return GamerGameLogic.isAchievementMet(
        achievementId: id,
        maxPoints: maxPoints,
        decisionsCount: decisionsCount,
        playerCount: playerCount,
        playersWithPoints: playersWithPoints,
        maxMedals: maxMedals,
      );
    }

    test('king_flavor se cumple a partir de 40 puntos, no antes', () {
      expect(met('king_flavor', maxPoints: 39), isFalse);
      expect(met('king_flavor', maxPoints: 40), isTrue);
    });

    test('spicy_streak se cumple a las 10 decisiones, no antes', () {
      expect(met('spicy_streak', decisionsCount: 9), isFalse);
      expect(met('spicy_streak', decisionsCount: 10), isTrue);
    });

    test('first_spin se cumple con la primera tirada', () {
      expect(met('first_spin'), isFalse);
      expect(met('first_spin', decisionsCount: 1), isTrue);
    });

    test('marathon pide 25 decisiones', () {
      expect(met('marathon', decisionsCount: 24), isFalse);
      expect(met('marathon', decisionsCount: 25), isTrue);
    });

    test('full_table pide cinco comensales', () {
      expect(met('full_table', playerCount: 4), isFalse);
      expect(met('full_table', playerCount: 5), isTrue);
    });

    test('medal_hunter pide cinco medallas de una misma persona', () {
      expect(met('medal_hunter', maxMedals: 4), isFalse);
      expect(met('medal_hunter', maxMedals: 5), isTrue);
    });

    // La regresión que motivó el cambio: estaba implementado como
    // "cinco decisiones", así que cinco tiradas seguidas a la misma persona
    // lo desbloqueaban aunque nadie más hubiera salido nunca.
    test('soul_table exige que le toque a TODOS, no un número de tiradas', () {
      expect(
        met(
          'soul_table',
          decisionsCount: 50,
          playerCount: 3,
          playersWithPoints: 1,
        ),
        isFalse,
      );

      expect(
        met(
          'soul_table',
          decisionsCount: 3,
          playerCount: 3,
          playersWithPoints: 3,
        ),
        isTrue,
      );
    });

    test('soul_table no se regala en una mesa de una sola persona', () {
      expect(
        met('soul_table', playerCount: 1, playersWithPoints: 1),
        isFalse,
      );
    });

    test('un ID de logro desconocido nunca se da por cumplido', () {
      expect(
        met(
          'logro_que_no_existe',
          maxPoints: 999999,
          decisionsCount: 999999,
          playerCount: 999999,
          playersWithPoints: 999999,
          maxMedals: 999999,
        ),
        isFalse,
      );
    });

    test('un ID vacío nunca se da por cumplido', () {
      expect(
        met(
          '',
          maxPoints: 999999,
          decisionsCount: 999999,
          playerCount: 999999,
          playersWithPoints: 999999,
          maxMedals: 999999,
        ),
        isFalse,
      );
    });

    test('el progreso de un ID desconocido es cero sobre cero', () {
      final p = GamerGameLogic.achievementProgress(
        achievementId: 'nada',
        maxPoints: 1,
        decisionsCount: 1,
        playerCount: 1,
        playersWithPoints: 1,
        maxMedals: 1,
      );
      expect(p.goal, 0);
      expect(p.current, 0);
    });
  });
}
