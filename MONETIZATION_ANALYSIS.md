# MONETIZATION_ANALYSIS.md — Fase 9

> Fuente: investigación real vía WebSearch/WebFetch (agosto 2026). Cifras con fuente citada; lo no verificable se marca **NO VERIFICADO**. Principio rector explícito del encargo: *más engagement debe significar más valor para el usuario y más ingresos, no un trade-off* — cada recomendación se filtra por ese criterio.

---

## 1. Modelos de monetización investigados, con ejemplos reales

| Modelo | Ejemplo | Datos concretos | Fuente |
|---|---|---|---|
| Suscripción freemium (diario social, comparable directo) | **Beli** | Gratis sin ads; IAP $0.99-$74.99; "Supper Club" $74.99/año | [App Store](https://apps.apple.com/us/app/beli/id1478375386), [Ivey Business Review](https://www.iveybusinessreview.ca/magazine/articles/beli) |
| Suscripción freemium (diario gamificado, mismo patrón) | **Untappd** | Free + Insider ~$5-6/mes — precio exacto **NO VERIFICADO** (fuentes divergen) | BeerMenus, App Store |
| Suscripción + marketplace | **Vivino** | Premium ~$4.99/mes; además empuja compra de vino | [Vivino](https://www.vivino.com/en/wine-news/the-complete-guide-to-the-vivino-experience) |
| Suscripción por tiers (diario social UGC) | **Letterboxd** | Patron $49/año; tier base **NO VERIFICADO** | Letterboxd Pro, X oficial |
| Comisión B2B2C (reservas) | **TheFork** | Gratis para el comensal; comisión a restaurantes; 80.000+ restaurantes, 28M reservas/año (2023) | Vizologi, Caramel |
| Suscripción compartida en pareja (**el más análogo al ángulo de Palito**) | **Paired** | $14.99/mes o ~$70-84/año; **si un miembro paga, el otro se desbloquea gratis** | App Store, Sensor Tower |
| Ads in-feed + brand takeovers (pivote reciente de app social) | **BeReal** | Lanzó ads abril 2025, 200+ anunciantes; ingreso anual estimado **NO VERIFICADO** (cifras muy dispares entre fuentes) | Social Discovery Insights, FourWeekMBA |
| Moneda virtual cosmético-funcional (no pay-to-win) | **Duolingo Gems** | Se ganan gratis con uso, también comprables; &lt;5% de usuarios convierte, pero relevante a escala 100M+ MAU | AppMakersLA, duolingoguides.com |
| Freemium por límite de *uso* (no de feature) | **Splitwise** | Pro ~$4.99/mes; desbloquea tope de 3 gastos/día, quita ads | areweeven.com, splittyapp.com |
| Suscripción "anti-ads" como propuesta de valor | **World of Mouth** | €9.90/mes o ~€3.90/mes anual; posicionamiento explícito *"No ads. No sponsored lists."* | Web oficial |
| Afiliación de reservas (API partner) | **OpenTable Affiliate** | Comisión por comensal sentado; % **NO VERIFICADO** | howtojoinaffiliateprograms.com |
| Patrocinio/partnership de marca | Prácticas del sector (genérico) | Comida gratis por contenido, fee fijo, códigos de descuento — costes **NO VERIFICADOS** | ionhospitality.com |
| Rewarded/interstitial ads (benchmark general) | Estándar de industria 2025-2026 | Rewarded: $15-30 eCPM Tier 1, $8-18 promedio global. Interstitial: $5-8 Tier 1, $2.50-5 global. Rewarded &gt; interstitial (opt-in) | AdReact, Playwire |
| Freemium en apps de decisión de pareja/grupo (competencia directa del "juego") | **Tonight's Bite** | Swipe gratis; premium desbloquea filtros avanzados; precio **NO VERIFICADO** | tonightsbite.app |
| Revenue-share aspiracional | **Cobble** | Hoy gratis; modelo declarado a futuro (reservas, partnerships) — **NO VERIFICADO si ya está implementado** | AlleyWatch |
| Benchmark de conversión freemium (industria) | RevenueCat State of Subscription Apps 2025 | Conversión mediana descarga→pago: **2.18%**; Social & Lifestyle: 43.6% sin trial, 39.4% híbrido; rango típico 1-5%, top performers 10%+ | RevenueCat |

---

## 2. Qué modelos son compatibles con Palito (y cuáles no)

**Filtro aplicado:** los comparables que mejor protegen la experiencia (Beli, World of Mouth) mantienen el núcleo social/de contenido 100% libre de ads y monetizan por suscripción opcional o límite de *uso*, no de *funcionalidad esencial*. Los que peor lo hacen (Splitwise según quejas de usuarios recientes, MyFitnessPal — ver `USER_NEEDS.md`) generan fricción documentada. BeReal es la alerta central: pivotó de "sin ads, auténtico" a ads in-feed — justo el trade-off que Palito quiere evitar.

### Compatible — recomendado
- **Suscripción freemium por límite de "mirar atrás", no de registro básico.** El diario (crear/ver recuerdos propios) permanece siempre gratis e ilimitado. Se cobra por profundidad analítica: recap anual/mensual, comparativas cruzadas por tipo de plato (dato único que Palito ya captura y ningún competidor investigado ofrece), exportación/backup.
- **Suscripción compartida estilo Paired.** Coherente con que Palito es fundamentalmente un producto de pareja/grupo pequeño: si un miembro paga, el resto del hogar se desbloquea gratis. Convierte la monetización en argumento de venta, no en barrera.
- **Afiliación de reservas (TheFork/OpenTable), en fase posterior.** Cuando un usuario marca un sitio como "quiero probar", enlace de reserva con comisión por reserva confirmada — monetiza la intención sin interrumpir el uso.
- **Moneda virtual cosmética dentro de Zona Gamer (no pay-to-win).** Skins de tarjeta de resultado, protección de racha compartida — nunca ventaja competitiva comprable.

### Compatible con condiciones — solo en fase posterior, con volumen real
- **Rewarded ads, exclusivamente dentro de Zona Gamer, nunca en el diario.** Solo tiene sentido económico a partir de decenas de miles de DAU (eCPM relevante a escala); antes de eso, el daño a la experiencia íntima supera el ingreso.
- **Patrocinios de marca en retos** — requiere DAU real que atraiga a marcas; prematuro antes de v3.

### No compatible / evitar explícitamente
- **Paywall de funciones "core" del registro básico** (patrón MyFitnessPal/HelloFresh, ver `USER_NEEDS.md`) — es la causa de resentimiento documentada más repetida en toda la investigación.
- **Interstitials forzadas** en cualquier parte del diario.
- **Gemas/loot boxes tipo pay-to-win** (Cooking Fever, Cooking Mama, World Chef) — el patrón de queja más repetido de todo el bloque de gaming investigado ("gemas imposibles de conseguir sin pagar", sensación de "robo" de recompensas).
- **Venta de datos personales identificables.** Ninguno de los comparables exitosos lo hace abiertamente.
- **Premios económicos reales ligados al azar de la ruleta** — riesgo regulatorio real y documentado (Google emitió avisos a Zomato/Swiggy por parecido a apuestas deportivas).

---

## 3. Modelo por fases recomendado

**Fase 0 — ahora (pre-lanzamiento):** ningún cobro. Publicar, instrumentar analítica básica (Firebase Analytics + Crashlytics) antes de fijar precios reales. Hoy cualquier cifra de precio sería un número inventado sin datos de disposición a pagar propios.

**Fase 1 — lanzamiento (0-12 meses):**
- Diario siempre gratis e ilimitado.
- Suscripción de estadísticas avanzadas / recap, con desbloqueo compartido estilo Paired.
- Precio de entrada por debajo de la banda de comparables (Vivino $4.99/mes, Splitwise ~$4.99/mes, Wanderlog ~$3-4/mes): orientativamente **2,99€/mes o ~24,99€/año** — subir precio después es más fácil que bajarlo.
- Cero ads en el diario.

**Fase 2 — con DAU/retención reales (6-18 meses):**
- Rewarded ads opcionales solo en Zona Gamer.
- Moneda virtual cosmética del juego.
- Afiliación de reservas.

**Fase 3 — escala (18+ meses):**
- Patrocinios/partnerships de marca en retos.
- Producto B2B de datos agregados por plato/zona — el ángulo más diferenciado a largo plazo (ni Beli ni TheFork capturan este dato hoy), pero depende de volumen que no existe todavía. Ver `MARKET_OPPORTUNITIES.md`, Bloque 4.

---

**Siguiente documento**: `GROWTH_ASO_ANALYSIS.md` (Fases 7, 8 y 10).
