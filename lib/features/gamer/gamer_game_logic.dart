import 'dart:math';

/// Resultado puro de un giro de la ruleta de Zona Gamer: cuántos puntos
/// otorga, si suma una medalla (solo "Juicio Picante"), qué texto mostrar
/// y, en el modo "Juicio Picante", qué reto le tocó al ganador.
///
/// Extraído de `_GamerPageState._spinGame` para poder testear la
/// decisión de puntuación sin depender de `setState`, animaciones,
/// `BuildContext` ni Riverpod — todo eso sigue viviendo en `gamer_page.dart`,
/// que es quien aplica este resultado al estado real de la partida.
class GamerSpinOutcome {
  final int pointsAwarded;
  final bool awardsMedal;
  final String eventDetail;
  final String historyDetail;

  /// Solo tiene valor en el modo "Juicio Picante" (`selectedMode != 0`).
  final String? challenge;

  const GamerSpinOutcome({
    required this.pointsAwarded,
    required this.awardsMedal,
    required this.eventDetail,
    required this.historyDetail,
    this.challenge,
  });
}

/// Lógica de juego de Zona Gamer que no depende de widgets ni de
/// Firestore, y que por tanto se puede testear de forma aislada.
class GamerGameLogic {
  const GamerGameLogic._();

  /// [selectedMode] 0 = Ruleta Pro (elegir plato); cualquier otro valor =
  /// Juicio Picante (reto al azar de [challenges], usando [random]).
  static GamerSpinOutcome computeSpinOutcome({
    required int selectedMode,
    required List<String> challenges,
    required Random random,
  }) {
    if (selectedMode == 0) {
      return const GamerSpinOutcome(
        pointsAwarded: 5,
        awardsMedal: false,
        eventDetail: 'Ruleta Pro: Elección de Plato',
        historyDetail: '🍽️ ¡Le toca elegir plato!',
      );
    }

    final challenge = challenges[random.nextInt(challenges.length)];

    return GamerSpinOutcome(
      pointsAwarded: 10,
      awardsMedal: true,
      eventDetail: 'Juicio Picante',
      historyDetail: '🔥 Juicio Picante asignado',
      challenge: challenge,
    );
  }

  /// Comprueba si el logro [achievementId] se cumple con las
  /// estadísticas actuales de la sesión. Devuelve `false` (nunca lanza)
  /// para cualquier ID que no reconozca.
  ///
  /// Extraído de `_GamerPageState._checkAndUnlockAchievements`.
  static bool isAchievementMet({
    required String achievementId,
    required int maxPoints,
    required int streak,
    required int decisionsCount,
  }) {
    return switch (achievementId) {
      'king_flavor' => maxPoints >= 40,
      'spicy_streak' => streak >= 10,
      'soul_table' => decisionsCount >= 5,
      _ => false,
    };
  }
}
