class MemoryResultLogic {
  final Map<String, dynamic> data;

  MemoryResultLogic(this.data);

  // 1. Calcula el Score promedio para una categoría específica
  double getAverageScore(List<String> keys) {
    double total = 0;
    int count = 0;
    for (var key in keys) {
      if (data.containsKey(key) && data[key] is num) {
        total += data[key] as num;
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  // 2. Motor de Premios (Insignias automáticas)
  List<String> getAwardBadges() {
    List<String> awards = [];
    
    // Ejemplo de lógica emocional:
    if (data['limpieza'] == 'Excelente' && (data['detalle'] ?? 0) >= 9) {
      awards.add('Lugar Inmaculado');
    }
    if (data['tiempo_espera'] == 'Inmediato' && (data['nota_atencion'] ?? 0) >= 9) {
      awards.add('Servicio Relámpago');
    }
    if (data['tiempo_espera'] == 'Podría vivir aquí') {
      awards.add('Oasis Urbano');
    }
    
    return awards;
  }
}