/// ===========================================================================
/// CÓMO SE LLAMA CADA CAMPO CUANDO LO LEES
/// ===========================================================================
///
/// La ficha del recuerdo NO enseñaba estas etiquetas: **se las inventaba a
/// partir de la clave con la que el campo se guarda en la base de datos**.
/// `key.replaceAll('_', ' ')` y la primera en mayúscula, y a correr.
///
/// El resultado, visto en el simulador sobre un recuerdo real:
///
///     Tecnica            en vez de   Técnica aplicada
///     Coccion                        Punto de cocción
///     Tamano                         Tamaño o porción
///     Harias por volver              ¿Qué harías por volver?
///     Tipo plato                     Tipo de plato
///     Ultima cucharada               Última cucharada
///
/// **Setenta y cinco de ochenta campos** salían así. Sin tildes —porque una
/// clave de base de datos no las lleva— y con el nombre técnico en lugar de
/// la pregunta que la persona respondió al rellenarlo. Y pasa justamente en
/// la pantalla donde alguien relee sus propios recuerdos.
///
/// POR QUÉ NO SE REUTILIZA EL RÓTULO DEL FORMULARIO TAL CUAL. Porque allí
/// muchos llevan delante el nombre de su sección —"El Cierre: Última
/// cucharada", "Técnica y Equilibrio: Técnica aplicada"— que tiene sentido
/// mientras rellenas un bloque y no en una fila de dos columnas. Aquí está
/// la versión corta de cada uno.
///
/// ── SI AÑADES UN CAMPO NUEVO ──
///
/// Añádelo también aquí. Si no, la ficha volverá a inventarse el nombre a
/// partir de la clave — que es exactamente de donde venimos. El respaldo
/// sigue existiendo para que nada se quede en blanco, no para usarlo.
const Map<String, String> kFieldLabels = <String, String>{
  'al_cortar': '¿Qué pasó al cortarla?',
  'banda_sonora': 'Banda sonora',
  'banos': 'Estado de los baños',
  'bechamel': 'La bechamel',
  'calidad_atun': 'Calidad del atún',
  'cantidad_mayo': 'Cantidad de mayonesa',
  'coccion': 'Punto de cocción',
  'coherencia': '¿Coherente?',
  'conocimiento': 'Dominio de carta',
  'corte_patata': 'Corte de la patata',
  'creatividad': 'Creatividad en la presentación',
  'demasiado_de': 'Demasiada presencia de',
  'despedida': 'Despedida',
  'destaca_demasiado': '¿Qué le falta?',
  'detalle': '¿Cuánta atención al detalle hay?',
  'disponibilidad': 'Disponibilidad del equipo',
  'emocion': 'Emoción predominante',
  'equilibrio': 'Equilibrio de sabores',
  'espera': 'Tiempo de espera',
  'estado_final': 'Estado final',
  'estado_patata': 'Consistencia de la patata',
  'estilo': 'Estilo',
  'evolucion': 'Evolución de los platos',
  'extras': 'Ingredientes extra',
  'frase_recordada': 'Frase memorable',
  'harias_por_volver': '¿Qué harías por volver?',
  'ingredientes': 'Ingredientes',
  'integracion_huevo': 'Integración del huevo',
  'intensidad': 'Intensidad principal',
  'interior': '¿Cómo estaba el interior?',
  'limpieza': 'Limpieza',
  'luz': 'Iluminación',
  'mejor_parte': '¿Qué destacó más?',
  'mejoras': 'Áreas de mejora sugeridas',
  'momento_especial': 'Momento más especial',
  'momento_estrella': 'Momento estrella',
  'nombre_menu': 'Nombre del menú',
  'nombre_plato': 'Nombre del plato',
  'nombre_postre': 'Nombre del postre',
  'nombre_staff': 'Quién te atendió',
  'nota_atencion': 'Nota de la atención',
  'nota_espacio': 'Nota del espacio',
  'olor': 'Aroma del local',
  'otra_tecnica': 'Otra técnica',
  'otra_vista_exterior': 'Describe la vista',
  'otro_equilibrio': 'Otro equilibrio de sabores',
  'otro_sabor': 'Sabor adicional',
  'otro_tipo_plato': 'Otro tipo de plato',
  'pan_detector': 'Repetición de pan',
  'pelea_plato': 'Dinámica en la mesa',
  'pelicula': 'Película',
  'perfil_sabor': 'Perfil de sabor',
  'personaje_staff': 'Qué personaje era',
  'personalidad': 'Personalidad',
  'precio': 'Precio',
  'precio_menu': 'Precio',
  'premio': 'Premio Palito',
  'premio_servicio': 'Premios Palito',
  'presencia_huevo': 'Presencia de huevo',
  'primer_bocado': 'Primera cucharada',
  'rebozado': 'El rebozado',
  'recomendaciones': 'Calidad de las recomendaciones',
  'recuerdo': 'Memoria a largo plazo',
  'ritmo': 'Ritmo del servicio',
  'ruido': 'Nivel de ruido',
  'sabor': '¿Qué ingredientes llevan?',
  'sensacion_mayo': 'Sensaciones de la mayonesa',
  'sensaciones': 'Sensaciones',
  'tamano': 'Tamaño o porción',
  'tecnica': 'Técnica aplicada',
  'temperatura': 'Temperatura',
  'textura': 'Texturas',
  'tiempo_espera': 'Tiempo tras comer',
  'tipo_mayonesa': 'Tipo de mayonesa',
  'tipo_menu': 'Tipo de menú',
  'tipo_pan': 'Descripción del pan',
  'tipo_plato': 'Tipo de plato',
  'titular': 'El titular',
  'ubicacion_mesa': '¿Dónde estamos sentados?',
  'ultima_cucharada': 'Última cucharada',
  'ultimo_bocado': 'Sensación en el último bocado',
  'vistas_exterior': 'Vistas al exterior',
};
