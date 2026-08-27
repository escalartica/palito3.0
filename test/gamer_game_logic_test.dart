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

    test(
        'cualquier modo distinto de 0 (Juicio Picante) otorga 10 puntos, '
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

  group('GamerGameLogic.isAchievementMet', () {
    test('king_flavor se cumple a partir de 40 puntos, no antes', () {
      expect(
        GamerGameLogic.isAchievementMet(
          achievementId: 'king_flavor',
          maxPoints: 39,
          streak: 0,
          decisionsCount: 0,
        ),
        isFalse,
      );

      expect(
        GamerGameLogic.isAchievementMet(
          achievementId: 'king_flavor',
          maxPoints: 40,
          streak: 0,
          decisionsCount: 0,
        ),
        isTrue,
      );
    });

    test('spicy_streak se cumple a partir de una racha de 10, no antes', () {
      expect(
        GamerGameLogic.isAchievementMet(
          achievementId: 'spicy_streak',
          maxPoints: 0,
          streak: 9,
          decisionsCount: 0,
        ),
        isFalse,
      );

      expect(
        GamerGameLogic.isAchievementMet(
          achievementId: 'spicy_streak',
          maxPoints: 0,
          streak: 10,
          decisionsCount: 0,
        ),
        isTrue,
      );
    });

    test('soul_table se cumple a partir de 5 decisiones, no antes', () {
      expect(
        GamerGameLogic.isAchievementMet(
          achievementId: 'soul_table',
          maxPoints: 0,
          streak: 0,
          decisionsCount: 4,
        ),
        isFalse,
      );

      expect(
        GamerGameLogic.isAchievementMet(
          achievementId: 'soul_table',
          maxPoints: 0,
          streak: 0,
          decisionsCount: 5,
        ),
        isTrue,
      );
    });

    test('un ID de logro desconocido nunca se da por cumplido', () {
      expect(
        GamerGameLogic.isAchievementMet(
          achievementId: 'logro_que_no_existe',
          maxPoints: 999999,
          streak: 999999,
          decisionsCount: 999999,
        ),
        isFalse,
      );
    });

    test('un ID vacío nunca se da por cumplido', () {
      expect(
        GamerGameLogic.isAchievementMet(
          achievementId: '',
          maxPoints: 999999,
          streak: 999999,
          decisionsCount: 999999,
        ),
        isFalse,
      );
    });
  });
}
