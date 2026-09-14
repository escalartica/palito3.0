/// ===========================================================================
/// ESCALA DE PUNTUACIÓN — fuente única de verdad
/// ===========================================================================
///
/// La app guardaba la nota en 0–5 (el slider del formulario y
/// `MemoryModel._parseRating` recortan a 5.0) pero la ficha de detalle la
/// pintaba en 0–10: dividía entre 10 para la barra de progreso, rotulaba los
/// extremos con "0" y "10", y solo llamaba "Extraordinario" a un ≥ 9 que era
/// imposible de alcanzar.
///
/// Resultado: un 5 sobre 5 —la nota máxima— salía como "5.0" con la barra a
/// media asta y la etiqueta "Por mejorar". Todo parecía puntuado por debajo.
///
/// Además, `rating == 0` NO significa "un cero": significa "sin puntuar". La
/// versión publicada en la App Store no obligaba a poner nota, así que todos
/// los recuerdos anteriores valen 0. Por eso el mapa mostraba "0.0★" y el
/// perfil "Nota Media 0.0" aunque el recuerdo estuviera completo.
abstract final class RatingScale {
  static const double max = 5.0;

  /// `true` si el recuerdo tiene una nota de verdad.
  static bool isRated(double rating) => rating > 0;

  /// Progreso de 0 a 1 para barras y medidores.
  static double progress(double rating) =>
      (rating / max).clamp(0.0, 1.0).toDouble();

  /// Texto corto para mostrar junto a la estrella. `null` cuando no hay nota,
  /// para que quien lo pinte decida si oculta el distintivo o escribe
  /// "Sin puntuar" — nunca "0.0", que se lee como una valoración pésima.
  static String? shortLabel(double rating) =>
      isRated(rating) ? rating.toStringAsFixed(1) : null;

  /// Etiqueta cualitativa, reescalada a 0–5.
  static String qualitativeLabel(double rating) {
    if (!isRated(rating)) return 'Sin puntuar';
    if (rating >= 4.5) return 'Extraordinario';
    if (rating >= 4.0) return 'Excelente';
    if (rating >= 3.5) return 'Muy bueno';
    if (rating >= 2.5) return 'Correcto';
    return 'Por mejorar';
  }

  /// Media de una lista de notas, ignorando las que no lo son. Antes se
  /// dividía entre el total de recuerdos: con cuatro recuerdos heredados sin
  /// nota y uno de 4,5, la "Nota Media" salía 0,9.
  static double? average(Iterable<double> ratings) {
    final List<double> rated = ratings.where(isRated).toList();
    if (rated.isEmpty) return null;
    return rated.reduce((double a, double b) => a + b) / rated.length;
  }
}
