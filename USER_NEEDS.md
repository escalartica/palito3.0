# USER_NEEDS.md — Análisis de reviews y necesidades de usuario (Fase 4)

> Basado en la investigación real de `COMPETITIVE_ANALYSIS.md`. El objetivo de este documento no es listar features de competidores, sino identificar frases del tipo *"los usuarios piden X y nadie lo resuelve bien"* — oportunidades estratégicas, no listas de deseos.

---

## Qué les gusta (patrones positivos repetidos)

- **Confianza social sobre confianza anónima.** Beli crece por referidos porque comparar con amigos reales se siente más fiable que estrellas de desconocidos (Yelp, TripAdvisor).
- **Verificación de "estuviste ahí realmente".** TheFork solo permite opinar a quien reservó — se percibe como más fiable que un review abierto.
- **Monetización no agresiva.** Good Pizza, Great Pizza (4.7★/319K) con ads mayormente opcionales sostiene una valoración alta frente a juegos del mismo género con monetización agresiva.
- **El diario como espacio propio.** En foros sobre Untappd, una parte relevante de usuarios valora la app ante todo como registro personal privado, no como fuente pública — coincide con el patrón de Beli protegiendo la calidad del dato vía invite-only.
- **Vínculo cooperativo en grupos cerrados.** Overcooked (91% reseñas positivas) es descrito reiteradamente como generador de conexión real entre quienes ya se conocen.

## Qué les molesta (quejas repetidas y documentadas)

- **Reviews falsas / no fiables a escala:** Yelp (~16% estimado falso, Fortune), denuncias de pago por visibilidad; comparaciones peyorativas de Untappd con TripAdvisor en foros.
- **Paywall de funciones que se sentían "propias":** MyFitnessPal (barcode scanning ahora de pago tras ser gratis), generando percepción de que la empresa prioriza monetización sobre el usuario.
- **Fricción operativa pese a buen rating público:** TheFork acumula quejas consistentes de reservas duplicadas y soporte que no responde en canales no controlados por la empresa (Trustpilot, foros), pese a 4.9★ en App Store.
- **Recursos "imposibles de conseguir sin pagar":** patrón repetido en Cooking Fever, Cooking Mama, World Chef, Diner Dash Adventures — gemas escasas, ads no-skippeable, sensación de "robo" de recompensas ya ganadas.
- **Servicio poco fiable en delivery:** Glovo (1.1★ Trustpilot), HelloFresh (1.8★ PissedConsumer) — quejas de servicio más que de producto, pero dañan la categoría completa.

## Qué funcionalidades piden (implícito en el diseño de quien sí lo resuelve)

- Comparación social con gente conocida, no ranking anónimo abierto (resuelto parcialmente por Beli).
- Registro rápido con fricción mínima — Vivino usa reconocimiento de foto como atajo de entrada.
- Un "resultado" tangible y compartible de la actividad (patrón Wordle/Strava, ver `GROWTH_ASO_ANALYSIS.md`) — **ninguna app gastronómica de las 35 analizadas lo ofrece hoy**.
- Forma de unirse a una decisión de grupo sin fricción de cuenta (Movie Matchup, VoteFlix, Restaurant Roulette) — validado en apps de decisión pero no conectado a un diario persistente en ninguna.

## Qué consideran inútil / genera fatiga

- **Badges/puntos sin utilidad funcional detrás.** Foursquare Swarm es el caso de estudio: adopción inicial fuerte, luego irrelevancia — Foursquare terminó dando de baja su producto consumer principal.
- **Gamificación de volumen de consumo.** Ver sección siguiente — es más que "inútil", es potencialmente dañina.

## Qué provoca abandono

- Percepción de que la app cobra por algo que antes era gratis o se sentía "básico" (MyFitnessPal).
- Fallos operativos repetidos sin solución (TheFork: reservas perdidas, soporte ausente).
- Gamificación que deja de tener sentido cuando el círculo social relevante no está ahí (Foursquare: sin masa crítica de amigos, las alcaldías pierden todo atractivo).

## Qué provoca retención/"adicción" (uso de forma neutral, no necesariamente positiva)

- Rachas con aversión a la pérdida (Duolingo).
- Validación social recurrente por actividad compartida (Strava Kudos: 14.000M interacciones/año en 2025).
- Ligas/rankings dentro de un grupo de comparación relevante y pequeño (Beli, Duolingo Leagues).
- **Advertencia ética documentada — caso Untappd:** un análisis académico (arXiv, 2025-26) identifica insignias que premian directamente el consumo excesivo ("Sky's the Limit" por ABV alto, "Drinking Your Paycheck" por 5 bebidas en una tarde, "Take It Easy" por 12 cervezas/día). El paper concluye que la app *"reencuadra el consumo de alcohol como logro y maestría"* y que, pese a años de crítica pública, apenas ha cambiado el diseño. **Esta es la advertencia más importante de todo el informe para el diseño de la Zona Gamer**: cualquier racha/punto en Palito debe premiar el acto de registrar y jugar, nunca la cantidad de comida o el gasto — el riesgo no es solo de producto, es de responsabilidad hacia el usuario.

## Qué provoca recomendación a amigos / crecimiento

- Producto que **requiere** invitar a otros para funcionar (Dropbox, Splitwise) — virilidad estructural, no opcional.
- Contenido de resultado compartible sin fricción (Wordle: de 90 a 300.000 jugadores en 2 meses sin marketing pagado).
- Programas de invitación con recompensa mutua útil, no solo dinero (Dropbox: +500MB para ambos).

## Qué provoca malas valoraciones

- Discrepancia entre experiencia real y rating público inflado por incentivo puntual (TheFork: rating alto post-reserva exitosa, quejas dispersas en foros no controlados).
- Monetización percibida como extractiva más que como intercambio de valor (Cooking Fever, Cooking Mama — "uno de los juegos más tacaños").
- Servicio poco fiable en categorías de alta expectativa operativa (delivery: Glovo, HelloFresh).

## Qué usuarios están desatendidos

1. **Grupos cerrados pequeños (pareja, familia, 2-4 amigos) que ya se conocen bien.** Casi toda la investigación (Beli, Yelp, TripAdvisor) está optimizada para redes sociales amplias de conocidos/desconocidos, no para el caso de "las mismas 2-3 personas, siempre". Overcooked es la única evidencia clara de que las mecánicas cooperativas (no competitivas) funcionan mejor en este segmento — y ningún competidor gastronómico lo aplica.
2. **Usuarios que quieren registrar el plato, no el restaurante.** Ninguna de las 35 apps de `COMPETITIVE_ANALYSIS.md` estructura datos a nivel de plato específico entre restaurantes distintos.
3. **Usuarios que quieren decidir qué pedir dentro del menú, no dónde ir.** Ninguna app resuelve la "parálisis de elección en mesa" — todas optimizan la decisión de restaurante, ninguna la de plato.
4. **Mercado hispanohablante con categorías gastronómicas locales propias.** España tiene agregadores fuertes (Gastroranking, Guía Repsol, TheFork/ElTenedor) pero ninguno con lógica de diario social competitivo tipo Beli/Burpple, y ninguno con categorías tipo "croquetas/tortilla/ensaladilla" ya construidas.

---

## Síntesis: la frase estratégica

> **"Los usuarios llevan años pidiendo (implícitamente, en cómo abandonan o eligen apps) un sitio de confianza social real para decidir qué comer en grupo y recordar lo que ya probaron — y nadie lo ha construido a nivel de plato, para grupos cerrados pequeños, sin convertirlo en una competición pública ni en un embudo de monetización agresiva."**

Esto no es una idea genérica: es la intersección exacta de 4 patrones documentados con fuente (fatiga de reviews anónimas + demanda de registro a nivel de plato + preferencia por mecánicas cooperativas en grupos cerrados + rechazo documentado a monetización agresiva del registro básico) que ningún competidor investigado cubre simultáneamente.

---

**Siguiente documento**: `MARKET_OPPORTUNITIES.md` (Fase 5, mapa de oportunidades puntuado).
