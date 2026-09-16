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
  ///
  /// OJO AL CAMBIAR LAS CIFRAS: los 5 y los 10 puntos de aquí abajo están
  /// escritos también, en palabras, en la hoja de "Cómo se juega"
  /// (`widgets/how_to_play_sheet.dart`). Si cambian aquí y no allí, la
  /// pantalla que explica las reglas pasa a mentir.
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

  /// Cuánto llevas de un logro y cuánto hace falta: `(3, 10)` = tres de
  /// diez. Devuelve `(0, 0)` para un id que no conoce.
  ///
  /// El número de logros (siete) se nombra en `how_to_play_sheet.dart`.
  ///
  /// Antes solo existía un `isAchievementMet` que devolvía sí o no, y por eso
  /// los logros bloqueados eran una lista de candados sin más: "Acumular una
  /// racha de más de 10 decisiones", con nueve ya hechas y sin forma de
  /// saberlo. Un logro que no enseña cuánto te queda no invita a seguir
  /// jugando, que es exactamente para lo que está.
  ///
  /// Conseguido y progreso salen ahora del mismo sitio, así que no pueden
  /// discrepar: [isAchievementMet] es literalmente "el progreso llegó a la
  /// meta".
  static ({int current, int goal}) achievementProgress({
    required String achievementId,
    required int maxPoints,
    required int decisionsCount,
    required int playerCount,
    required int playersWithPoints,
    required int maxMedals,
  }) {
    return switch (achievementId) {
      'first_spin' => (current: decisionsCount.clamp(0, 1), goal: 1),
      'king_flavor' => (current: maxPoints, goal: 40),
      'spicy_streak' => (current: decisionsCount, goal: 10),
      // "Interactuar con todos los comensales", ahora de verdad.
      //
      // Estaba implementado como `decisionsCount >= 5`: cinco tiradas
      // seguidas a la misma persona lo desbloqueaban y la descripción
      // mentía. Ahora cuenta a cuántos comensales ha señalado la ruleta
      // alguna vez —que es lo que dice el texto— y la meta depende de
      // cuánta gente haya en la mesa.
      'soul_table' => (
        current: playersWithPoints,
        goal: playerCount < 2 ? 2 : playerCount,
      ),
      'full_table' => (current: playerCount, goal: 5),
      'medal_hunter' => (current: maxMedals, goal: 5),
      'marathon' => (current: decisionsCount, goal: 25),
      _ => (current: 0, goal: 0),
    };
  }

  /// Comprueba si el logro [achievementId] se cumple con las estadísticas
  /// actuales de la sesión. Devuelve `false` (nunca lanza) para cualquier
  /// ID que no reconozca.
  static bool isAchievementMet({
    required String achievementId,
    required int maxPoints,
    required int decisionsCount,
    required int playerCount,
    required int playersWithPoints,
    required int maxMedals,
  }) {
    final progress = achievementProgress(
      achievementId: achievementId,
      maxPoints: maxPoints,
      decisionsCount: decisionsCount,
      playerCount: playerCount,
      playersWithPoints: playersWithPoints,
      maxMedals: maxMedals,
    );

    return progress.goal > 0 && progress.current >= progress.goal;
  }
}
