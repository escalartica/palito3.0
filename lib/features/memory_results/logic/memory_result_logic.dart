class MemoryResultLogic {
  final Map<String, dynamic> data;

  MemoryResultLogic(this.data);

  /// Calcula el promedio de una lista de claves numéricas (Scores)
  double getAverageScore(List<String> keys) {
    double total = 0;
    int count = 0;
    
    for (var key in keys) {
      // Verificamos que la clave existe y es un número
      if (data.containsKey(key) && data[key] is num) {
        total += (data[key] as num).toDouble();
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  /// Motor de Premios (Insignias automáticas)
  /// Esta es la lógica "emocional" de Palito
  List<String> getAwardBadges() {
    List<String> awards = [];
    
    // Premios basados en la experiencia de Espacio/Ambiente
    if (data['limpieza'] == 'Excelente' && (data['detalle'] ?? 0) >= 9) {
      awards.add('Lugar Inmaculado');
    }
    
    // Premios basados en la Atención
    if (data['espera'] == 'Inmediato' && (data['nota_atencion'] ?? 0) >= 9) {
      awards.add('Servicio Relámpago');
    }
    
    // Premios basados en el Poder de Permanencia
    if (data['tiempo_espera'] == 'Podría vivir aquí') {
      awards.add('Oasis Urbano');
    }

    return awards;
  }
}