# MARKET_OPPORTUNITIES.md — Mapa de oportunidades (Fase 5-6)

> Metodología de puntuación: cada oportunidad se puntúa 1-10 en 12 criterios, con la evidencia de `COMPETITIVE_ANALYSIS.md` y `USER_NEEDS.md` como base. Donde la puntuación es una estimación sin dato de mercado directo (p. ej. demanda de un concepto que aún no existe), se indica **(est.)**. Esto no es una encuesta a usuarios reales — es una lectura razonada de la evidencia recopilada, a validar con datos propios tras el lanzamiento.

---

## 1. Oportunidades saturadas

| Oportunidad | Demanda | Competencia | Dif. técnica | Dif. adquisición | Viralidad | Retención | Monetización | Dep. contenido | Dep. comunidad | Escalabilidad | Riesgo | Velocidad |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Descubrimiento genérico de restaurantes (tipo Yelp/TripAdvisor) | 9 | 10 | 6 | 10 | 3 | 4 | 6 | 8 | 9 | 7 | 9 | 3 |
| Reservas de restaurante (tipo TheFork/OpenTable/Resy) | 8 | 10 | 7 | 10 | 2 | 5 | 8 | 7 | 3 | 6 | 9 | 2 |
| Delivery | 9 | 10 | 9 | 10 | 2 | 6 | 9 | 5 | 2 | 5 | 10 | 1 |
| Tracking nutricional/calorías genérico (tipo MyFitnessPal) | 7 | 9 | 5 | 8 | 2 | 5 | 6 | 6 | 3 | 6 | 8 | 4 |

**Lectura:** son los cuatro mercados donde ya compiten jugadores con cientos de millones de usuarios, presupuestos de marketing y, en el caso de delivery/reservas, infraestructura logística u operativa que Palito no tiene ni debería intentar construir. Entrar aquí de frente es la forma más rápida de fracasar por recursos, no por mala idea.

---

## 2. Oportunidades competitivas (hay competencia, cabe diferenciación)

| Oportunidad | Demanda | Competencia | Dif. técnica | Dif. adquisición | Viralidad | Retención | Monetización | Dep. contenido | Dep. comunidad | Escalabilidad | Riesgo | Velocidad |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Diario social de restaurantes tipo Beli | 7 | 6 | 5 | 6 | 7 | 6 | 5 | 5 | 8 | 7 | 6 | 5 |
| Apps de decisión de grupo (swipe: Cobble/Tonight's Bite/Velada) | 6 | 5 | 4 | 6 | 7 | 4 | 4 | 3 | 6 | 6 | 6 | 6 |

**Lectura:** Palito ya se parece más a esto que a la categoría anterior, pero competir de frente contra Beli (crecimiento validado, 25-30M reviews/año) en su propio terreno (ranking social de restaurantes) sería jugar el juego de otro. La categoría de "decisión de grupo por swipe" (Cobble, Tonight's Bite, Velada) tiene varios jugadores nuevos 2024-2026 — valida demanda del problema, pero ninguno combina la decisión con un diario persistente (ver siguiente bloque).

---

## 3. Oportunidades poco explotadas

| Oportunidad | Demanda | Competencia | Dif. técnica | Dif. adquisición | Viralidad | Retención | Monetización | Dep. contenido | Dep. comunidad | Escalabilidad | Riesgo | Velocidad |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Registro/ranking a nivel de **plato específico** (no restaurante) | 6 (est.) | 1 | 4 | 6 | 5 | 7 | 5 | 6 | 5 | 7 | 5 | **9** *(ya construido)* |
| Diario gastronómico para pareja/grupo cerrado pequeño | 6 (est.) | 2 | 4 | 5 | 6 | 7 | 6 | 4 | 6 | 6 | 5 | 7 |
| Mercado hispanohablante con categorías gastronómicas locales (croquetas, tortilla, ensaladilla) | 5 (est.) | 2 | 3 | 5 | 4 | 5 | 4 | 4 | 4 | 5 | 5 | 8 |

**Lectura:** este es el bloque más importante del informe. Ninguna de las 35 apps de gastronomía analizadas resuelve el registro a nivel de plato ni está diseñada específicamente para grupos cerrados pequeños con relación previa. Palito **ya tiene construida** la infraestructura de datos para la primera fila (factories de `croquetas_fields.dart`, `tortilla_fields.dart`, etc.) — de ahí la puntuación de velocidad 9: no es una funcionalidad a construir, es una a **comunicar y potenciar**.

---

## 4. Blue Ocean / oportunidades emergentes

| Oportunidad | Demanda | Competencia | Dif. técnica | Dif. adquisición | Viralidad | Retención | Monetización | Dep. contenido | Dep. comunidad | Escalabilidad | Riesgo | Velocidad |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Juego social de decisión con memoria persistente** (ruleta + puntos/racha + grupo cerrado que ya se conoce) | 7 (est.) | **1** | 5 | 5 | **9** | 7 | 6 | 3 | 7 | 8 | 6 | **8** *(base ya construida)* |
| Producto B2B de datos agregados por plato/zona geográfica | NO VERIFICADO | 2 | 8 | 7 | 1 | 1 | 8 (potencial) | 9 | 3 | 9 | 9 | 2 |

**Lectura de la primera fila (la más importante de todo el informe):** es la combinación exacta que `COMPETITIVE_ANALYSIS.md` documenta como sin competidor directo identificado — existen ruletas de decisión (sin memoria ni puntos), diarios gamificados (Untappd, Beli — sin mecánica de azar ni reto entre comensales) y gamificación real vinculada a comida (Zomato Premier League: +40% pedidos, +15% retención D7 — pero en contexto transaccional de delivery, no de diario social). Nadie une las tres piezas. La demanda del *problema* (decidir en grupo qué comer) está validada por la existencia de múltiples competidores de baja calidad resolviéndolo de forma incompleta (Restaurant Roulette Decider: 2.4★/9 reviews); la demanda de *esta solución concreta* no está validada con datos propios todavía — de ahí el "(est.)".

La fila del producto B2B es especulativa y de largo plazo (v3+): requiere volumen de datos que hoy no existe. Se incluye por completitud, no como prioridad cercana.

---

## 5. Fase 6 — Exploración de combinaciones gastronomía + X

| Combinación | Evidencia encontrada | Veredicto |
|---|---|---|
| Gastronomía + juego | Zomato Premier League (+40% pedidos, +15% retención D7), Overcooked (vínculo cooperativo) | **Con evidencia real, aplicable** |
| Gastronomía + competición | Beli (ranking social, crecimiento validado), Duolingo Leagues (patrón transferible) | **Con evidencia, pero saturándose en restaurant-ranking (Beli ya lo ocupa)** |
| Gastronomía + coleccionismo | Concepto "food passport"/sellos — encaja de forma natural con el diario ya existente de Palito | **Con lógica de producto sólida, sin competidor directo evaluado en profundidad — extensión barata sobre datos ya capturados** |
| Gastronomía + rankings | Google Local Guides (niveles/badges sostenibles con utilidad real), Beli | **Con evidencia, replicar el patrón de "atado a utilidad real", no puntos vacíos (lección Foursquare)** |
| Gastronomía + retos | Zomato Premier League, retos cooperativos tipo Overcooked | **Con evidencia, poco explotado en formato cooperativo (no competitivo) para grupos cerrados** |
| Gastronomía + amigos | Beli (80%+ crecimiento orgánico vía referidos), Dropbox/Splitwise (virilidad estructural) | **Con evidencia fuerte — es el mecanismo de crecimiento mejor documentado de todo el informe** |
| Gastronomía + IA | No investigado en profundidad en esta fase | **NO VERIFICADO — pendiente de investigación dedicada si se prioriza** |
| Gastronomía + realidad (AR/cámara) | Vivino (reconocimiento de foto como atajo de registro, 70M+ descargas) | **Con evidencia limitada pero positiva como reductor de fricción, no como pilar de producto** |
| Gastronomía + geolocalización | Ya presente en Palito (mapa, clustering); estándar en toda la categoría (TheFork, Zomato, Yelp) | **Tabla stakes, no diferenciador — hacerlo bien es necesario, no suficiente** |
| Gastronomía + viajes | TasteAtlas (enfoque cultural/regional), Guía Repsol (rutas) | **Con evidencia moderada, nicho adyacente más que core** |
| Gastronomía + contenido generado por usuarios | Foodie/SNOW (25M+ descargas solo por filtros de foto de comida) | **Con evidencia — la fotografía tiene demanda propia, potencial gancho de adquisición adicional** |
| Gastronomía + economía virtual | Cooking Fever, World Chef (gemas, monedas) — **con quejas documentadas de "pay to win"** | **Evidencia negativa para un diario real (no un juego F2P) — evitar réplica directa** |
| Gastronomía + recompensas | Swiggy Streaks (descuentos escalonados), Duolingo Gems | **Con evidencia, pero requiere recompensa real (dinero/producto) que Palito hoy no tiene infraestructura para dar — aplicable en fase de monetización posterior, no en V2.0** |
| Gastronomía + progresión | Beli (unlock de comparativas tras 10 restaurantes rankeados), Google Local Guides (niveles) | **Con evidencia fuerte y barata de implementar** |
| Gastronomía + comunidad | Casi toda la categoría (Beli, Untappd, HappyCow) | **Saturado si es comunidad abierta; poco explotado si es comunidad cerrada pequeña (ver Bloque 3)** |
| Gastronomía + eventos | Burpple (deals), patrocinios de marca en gaming (retos patrocinados) | **Con evidencia, viable a partir de v3 con volumen** |
| Gastronomía + discovery | Saturadísimo (Yelp, TripAdvisor, Zomato, TikTok) | **Evitar competir aquí de frente — ver Bloque 1** |
| Gastronomía + predicciones | Zomato Premier League (predicción deportiva) | **Con evidencia, pero con riesgo regulatorio documentado (avisos de Google por parecido a apuestas) si se liga a premio económico real** |
| Gastronomía + competición global | Ninguna evidencia de que funcione bien para grupos pequeños — Foursquare (leaderboard masivo) es advertencia, no ejemplo a seguir | **Evitar en V2 — el riesgo (desmotivación de quien no está arriba) supera el beneficio documentado a esta escala** |

### Conclusión de la Fase 6

La combinación con mejor respaldo de evidencia y menor competencia simultáneamente es **gastronomía + juego + amigos/grupo cerrado + progresión**, con **coleccionismo** (food passport) como extensión natural de bajo coste sobre datos ya capturados. **Gastronomía + economía virtual** y **gastronomía + competición global (leaderboards masivos)** son las combinaciones con evidencia real de que salen mal si se aplican sin cuidado — no se recomiendan para V2.

---

**Siguiente documento**: `MONETIZATION_ANALYSIS.md` (Fase 9).
