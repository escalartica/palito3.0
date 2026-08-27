# V1_AUDIT.md — Auditoría técnica y de producto de Palito (v1.0)

> Metodología: todo lo marcado **[HECHO]** se ha verificado leyendo el código fuente directamente (rutas citadas). Todo lo marcado **[INFERENCIA]** es una deducción razonable a partir de esos hechos. Todo lo marcado **[HIPÓTESIS]** es una suposición sin evidencia directa en el código — útil para orientar la investigación de mercado, pero a validar con datos reales de uso.

---

## A. Qué hace actualmente la aplicación

**[HECHO]** Palito es una app privada de diario gastronómico para **dos personas fijas** ("Eme" y "CeH", más una vista agregada "Team"), con las siguientes capacidades:

- Registrar una "experiencia gastronómica": restaurante, ubicación (GPS + geocodificación inversa), categoría de plato, puntuación 0–10, "¿volverías?", una foto, y un conjunto de **campos específicos por categoría** muy detallados (ver sección D).
- Editar y borrar (swipe-to-dismiss) recuerdos ya guardados.
- Ver el listado en Inicio, con filtro por categoría y ordenación por puntuación.
- Ver el detalle de un recuerdo con foto a pantalla completa (transición Hero).
- Ver todos los recuerdos en un mapa, con clustering y selector cuando coinciden varios en el mismo punto.
- "Zona Gamer": una ruleta que decide aleatoriamente quién elige el próximo plato o quién debe hacer un "juicio picante" (reto), con puntos y racha de decisiones por comensal, y unas pocas insignias/logros.
- Un perfil por comensal (Eme / CeH / Team) con foto y estadísticas agregadas (nº de recuerdos, nota media, % de retorno, categorías más visitadas).

**[HECHO]** Los datos (texto y fotos) se sincronizan en tiempo real entre todos los dispositivos que abran la app, porque **no existe un sistema de cuentas real**: toda la app apunta a un único identificador fijo compartido (`kHouseholdId`, ver [`lib/core/config/household_config.dart`](lib/core/config/household_config.dart)). La autenticación de Firebase es anónima y solo sirve como puerta de acceso técnica, no como sistema de usuarios.

## B. Propuesta de valor actual

**[INFERENCIA]** "Un diario gastronómico compartido con tu pareja/grupo cercano, con un componente de juego para decidir qué pedir o quién paga/elige" — no es una app de descubrimiento de restaurantes nuevos (no hay contenido de terceros, no hay red social, no hay recomendaciones), es un **registro privado retrospectivo** de sitios ya visitados, con una capa de entretenimiento encima.

## C. Usuario objetivo que parece estar intentando captar

**[INFERENCIA]** No un usuario individual anónimo, sino **una pareja o grupo pequeño y estable** que come fuera con frecuencia y quiere llevar un registro compartido con tono desenfadado. El copy, la mascota ("Palito"), el humor de los campos del formulario ("Cemento armado" como opción de textura de bechamel) y la app en sí están escritos pensando en un grupo concreto conocido — no en un público masivo. Esto es coherente con el hecho de que los perfiles "Eme"/"CeH" están literalmente hardcodeados en el código, no son cuentas creadas por el usuario.

## D. Principales funcionalidades

**[HECHO]**

| Funcionalidad | Detalle |
|---|---|
| Registro de recuerdos | 8 categorías con formularios dinámicos propios: ambiente, atención, croquetas, ensaladilla, menú del día, plato estrella, postre, tortilla ([`lib/features/memory_form/factories/`](lib/features/memory_form/factories/)) |
| Una foto por recuerdo | `finalImagePaths` es siempre una lista de longitud 1 ([`memory_form_page.dart:1282`](lib/features/home/memory_form_page.dart)) — **no hay galería multi-foto** |
| Mapa | flutter_map + clustering + selector de recuerdos superpuestos ([`lib/features/map/map_page.dart`](lib/features/map/map_page.dart), ~3.100 líneas) |
| Zona Gamer | Ruleta de decisión, 2 modos ("Ruleta Pro" / "Juicio Picante"), puntos y racha por comensal, 3 logros fijos, historial de sesión ([`lib/features/gamer/gamer_page.dart`](lib/features/gamer/gamer_page.dart), ~2.100 líneas) |
| Perfil | 3 pestañas fijas (Eme/CeH/Team), foto de perfil, estadísticas agregadas ([`lib/features/profile/profile_page.dart`](lib/features/profile/profile_page.dart)) |
| Sincronización | Cloud Firestore en tiempo real, caché local con SharedPreferences para carga instantánea offline-first |
| Fotos | Cloudinary (subida sin firmar) — no hay servidor propio |
| Distribución | PWA (Firebase Hosting) + build nativa iOS ad-hoc (Apple ID gratuito, caduca a los 7 días) |

## E. Fortalezas

**[HECHO/INFERENCIA]**

1. **Modelo de datos por categoría muy rico y específico** — los campos de "croquetas" preguntan por crujiente, tipo de bechamel, relleno; los de "tortilla" por punto de cuajado. Esto es un contenido mucho más granular que una review genérica de 5 estrellas, y es un activo diferenciador real si se investiga bien qué falta en el mercado (ver `MARKET_OPPORTUNITIES.md`).
2. **Identidad visual propia y consistente** (neobrutalismo: bordes duros, sombras sólidas, sin degradados), no un tema Material genérico — con animaciones de entrada cuidadas en toda la app.
3. **Concepto de gamificación diferenciado**: no son puntos por check-in genéricos, es una mecánica social real de "quién decide/quién paga" pensada para comer en grupo — encaja con el momento de uso real (mesa, decidiendo qué pedir).
4. **Arquitectura de coste cero validada en producción real** (Firestore + Cloudinary, sin servidor propio) — buena base de eficiencia de capital para una fase temprana.
5. Sincronización multi-dispositivo en tiempo real ya funcionando de forma fiable (validado esta sesión con datos reales).

## F. Debilidades

**[HECHO/INFERENCIA]**

1. **No existe sistema de usuarios.** Los 3 perfiles están hardcodeados en el código fuente ([`profile_page.dart`](lib/features/profile/profile_page.dart), constante `_profiles`). La app, tal cual está, **no puede tener un segundo grupo de usuarios** sin modificar y redesplegar código. Esto no es una limitación de producto menor: es la razón por la que hoy la app no puede crecer más allá de 1 instalación compartida.
2. **No hay onboarding.** La app abre directamente en un Home con datos ya existentes; un usuario nuevo llegaría a una pantalla vacía sin ninguna explicación de qué hacer, por qué, o qué es "Zona Gamer".
3. **No hay ninguna capa social ni de descubrimiento.** No se puede ver lo que otros usuarios (fuera del hogar) han registrado, no hay perfiles públicos, no hay compartir a redes, no hay contenido de terceros.
4. **No hay analítica de ningún tipo.** `pubspec.yaml` no incluye Firebase Analytics, Crashlytics ni ningún SDK de medición — el equipo no tiene visibilidad de uso real, retención ni errores en producción.
5. **No hay notificaciones** (push ni locales) — nada trae de vuelta a un usuario que deja de abrir la app.
6. **No hay monetización de ningún tipo** (ni ads, ni IAP, ni suscripción) — cero validado en `pubspec.yaml`.
7. **No está publicada en ninguna tienda de apps.** Solo distribución PWA + ad-hoc iOS. Sin ficha de App Store/Play Store no hay ASO, ni descubrimiento orgánico de tienda, ni credibilidad de "app real" para un usuario nuevo.
8. Una sola foto por recuerdo (sin galería).

## G. Problemas de UX

**[HECHO/INFERENCIA]**

- Formularios de categoría muy largos (algunos con 8-10 bloques de chips) — potencial fricción de abandono en el registro de un recuerdo, sobre todo la primera vez.
- Sin onboarding, el significado de "Zona Gamer" y sus mecánicas no se explica en ningún punto de la app.
- El botón "Guardar Cambios" del perfil no persiste nada explícito más allá de lo que ya es reactivo (foto/pestaña) — puede generar la falsa sensación de que "hay que guardar" cuando en realidad ya se guardó solo.
- Todo el copy está en español y con tono muy local/interno (referencias a "Eme"/"CeH" como personas reales) — una barrera directa para cualquier usuario fuera de ese círculo.

## H. Problemas de producto

**[INFERENCIA/HIPÓTESIS]**

- El "por qué volver" hoy depende casi enteramente de que los dos usuarios sigan comiendo fuera y queriendo registrarlo — no hay ningún mecanismo de la propia app que **genere** ganas de volver (sin notificaciones, sin contenido nuevo que descubrir, sin desafíos programados).
- No hay ningún lazo de crecimiento: nadie puede invitar a nadie, no hay nada que compartir fuera de la app, no hay ningún artefacto (tarjeta de resultado, ranking, reto) diseñado para salir de la app y volver con más gente.
- El "juego" (Zona Gamer) está desacoplado del "diario" (recuerdos): jugar a la ruleta no alimenta ni se alimenta del histórico de recuerdos guardados. Son dos productos dentro de la misma app más que un único sistema coherente.

## I. Problemas técnicos relevantes para escalar

**[HECHO]**

1. **Reglas de Firestore permisivas por diseño**: cualquier dispositivo autenticado (incluso anónimo) puede leer/escribir cualquier documento bajo `users/{kHouseholdId}/**` ([`firestore.rules`](firestore.rules)). Correcto para 2 usuarios de confianza; **inválido tal cual para un producto multi-usuario**.
2. **Modelo de datos de partición única** (`kHouseholdId` fijo): pasar de "1 hogar" a "N hogares/usuarios" no es una feature más, es una **reescritura de la capa de datos** (rutas Firestore, reglas de seguridad, providers de Riverpod que hoy asumen un único árbol de datos).
3. **Cloudinary en capa gratuita** (uno de los criterios de diseño explícitos de esta versión): 25 GB de almacenamiento / tráfico gratuitos no sostienen cientos de miles de usuarios subiendo fotos — necesitaría plan de pago o arquitectura de imágenes distinta a partir de cierto volumen.
4. **Sin backend propio**: toda la lógica vive en el cliente hablando directo con Firestore/Cloudinary. Sin capa de servidor, funciones como moderación de contenido, límites de abuso, lógica de negocio compleja (rankings globales, matching, notificaciones push activadas por eventos) son mucho más difíciles de construir de forma segura.
5. **Archivos muy grandes**: [`map_page.dart`](lib/features/map/map_page.dart) (~3.100 líneas) y [`memory_form_page.dart`](lib/features/home/memory_form_page.dart) (~1.500 líneas) concentran demasiada responsabilidad — fricción de mantenimiento a medida que el equipo o el alcance crezcan.
6. **Código muerto en el repositorio**: pantallas completas sin usar y no enrutadas (`explore_page.dart`, `dashboard_page.dart`, `home_screen.dart`, `result_screen.dart` y sus widgets, `menu_page.dart`, `category_list_page.dart`, `capture_fab.dart`, `category_card.dart`) — limpiar antes de escalar el equipo o el código se volverá confuso para cualquier persona nueva.
7. **Sin Android probado en dispositivo real** pese a que Firebase ya tiene una app Android registrada.
8. **Sin analítica ni crash reporting** — bloqueante para cualquier decisión de producto basada en datos reales (ver F.4).

## J. Oportunidades evidentes de mejora

**[INFERENCIA]** (desarrolladas en detalle en `MARKET_OPPORTUNITIES.md` y `V2_FEATURE_MATRIX.md`)

- Sistema de cuentas real (aunque sea ligero) es el prerrequisito técnico para cualquier crecimiento más allá del hogar actual.
- Analítica básica (Firebase Analytics + Crashlytics) es barata de añadir y desbloquea decisiones informadas para todo lo demás.
- El contenido granular por categoría (punto E.1) es un activo que hoy es privado — podría ser la base de una función de descubrimiento o comparación si se decide abrir la app a más de un hogar.
- La mecánica de "Zona Gamer" tiene potencial viral/social sin explotar (decidir en grupo, retos, resultados compartibles) si se conecta mejor con el resto de la app y se le añade un lazo de invitación.

## K. Hipótesis sobre por qué un usuario descargaría la aplicación

**[HIPÓTESIS — sin validar]**

- Quiere un diario gastronómico privado compartido con su pareja/grupo, más personal que dejar reviews públicas en Google/TripAdvisor.
- Le atrae la mecánica de juego para resolver "¿dónde comemos / quién decide?" — un problema real y recurrente en parejas y grupos.
- Busca algo con más carácter/diseño que una nota en el móvil o una hoja de cálculo compartida.

## L. Hipótesis sobre por qué volvería a utilizarla

**[HIPÓTESIS — sin validar]**

- Sigue comiendo fuera con la misma persona/grupo y quiere mantener el registro al día.
- Disfruta jugar a la ruleta como parte del ritual de elegir restaurante/plato.
- Quiere consultar el histórico antes de repetir o decidir dónde volver.

*(Nótese que ninguna de estas tres razones depende de un mecanismo activo de la propia app — hoy la retención depende 100% de la motivación externa del usuario, no de ningún gancho diseñado. Ver H.)*

## M. Hipótesis sobre por qué pagaría

**[HIPÓTESIS — sin validar, no hay monetización implementada]**

- Por más espacio/fotos por recuerdo (galería en vez de una sola foto).
- Por desbloquear más modos de juego, retos o personalización en Zona Gamer.
- Por invitar a más de 2 personas / crear más de un "hogar" (p. ej. familia + amigos, como espacios separados).
- Por funciones de exportación/backup avanzado (PDF del año gastronómico, etc.).

---

**Siguiente documento**: `COMPETITIVE_ANALYSIS.md` (Fase 2-3, investigación real de mercado).
