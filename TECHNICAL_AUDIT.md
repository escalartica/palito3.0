# TECHNICAL_AUDIT.md — Auditoría técnica completa de Palito 3.0 (pre-v4.0)

> Metodología: auditoría estática (lectura completa de código, no solo grep) + comportamiento real verificado (`flutter analyze`, `flutter test`, `flutter pub outdated`, inspección de `firestore.rules`, `firebase.json`, `Info.plist`, historial de git). Realizada con 4 subagentes especializados en paralelo (arquitectura/calidad, seguridad, performance/BD, frontend/UX/testing) más verificación directa. Cero cambios de código en esta fase — solo diagnóstico.
>
> Se apoya en `V1_AUDIT.md` (auditoría de producto ya existente) sin repetir su contenido; este documento cubre la capa técnica que aquel no auditaba en profundidad.

---

## 1. Resumen ejecutivo

Palito es una app Flutter + Firebase técnicamente **sólida para su propósito actual** (diario gastronómico privado de 2 personas): `flutter analyze` no arroja ningún issue, los 15 tests existentes pasan, y decisiones de arquitectura documentadas (modelo de "hogar compartido", Cloudinary en vez de Firebase Storage, PWA en vez de firma ad-hoc) están bien razonadas y funcionando en producción real.

El problema no es que el código esté mal escrito — es que **hay una duplicación estructural en la capa de datos** (dos instancias del mismo servicio Firestore, cada una con su propio listener, más una escritura triplicada al guardar) que ya cuesta rendimiento y coherencia hoy con 2 usuarios, y **una regla de seguridad de Firestore abierta a cualquier autenticado** que es aceptable para el diseño actual pero es un riesgo real y accionable si el `projectId` (no secreto) llega a manos de un tercero. Ninguno de los dos requiere reescritura — ambos son arreglables con cambios quirúrgicos.

No hay CI, no hay observabilidad (ni analítica ni crash reporting), y las dependencias de Firebase/Riverpod/go_router llevan una o más versiones major de retraso — nada urgente hoy, pero la ventana para actualizar sin dolor se va cerrando.

**Cifras clave**: 85 archivos Dart, ~25.150 líneas en `lib/`, 0 issues de analyzer, 15/15 tests pasando, 7 dependencias directas con versión major más nueva disponible, 0% de cobertura de test en la lógica de negocio más crítica (`MemoryNotifier`), 1 regla de seguridad Firestore abierta al hogar completo, 1 documento de diseño (`DESIGN_PHILOSOPHY.md`) que contradice la implementación real.

## 2. Qué es el producto actualmente

Ver `V1_AUDIT.md` para el detalle de producto. Resumen técnico: app Flutter multiplataforma (iOS + Web PWA, Android preparado pero no probado en dispositivo real) para registrar "recuerdos gastronómicos" con formularios dinámicos por categoría, mapa con clustering básico, un módulo de gamificación ("Zona Gamer") y un perfil con estadísticas agregadas. Un único "hogar" fijo (`kHouseholdId = 'palito-hogar'`) comparte todos los datos entre los dispositivos de 2 personas ("Eme" y "CeH"), autenticadas de forma anónima en Firebase Auth solo como puerta de acceso técnica, no como sistema de cuentas real.

## 3. Arquitectura actual

Arquitectura cliente-servidor sin backend propio: Flutter habla directamente con Cloud Firestore (datos) y Cloudinary (fotos, subida sin firmar). Sin capa de API intermedia.

```
lib/
├── core/
│   ├── config/     kHouseholdId, CloudinaryConfig (constantes)
│   ├── data/       StorageService (caché local SharedPreferences), categorías, datos de ejemplo
│   ├── factories/  DynamicFieldFactory (dispatcher por categoría)
│   ├── models/     MemoryModel (1.334 líneas — modelo + serialización + parsing defensivo)
│   ├── providers/  Riverpod: memoria, mapa, gamer, dock
│   ├── services/   Firestore (memory_map, gamer), migraciones, Cloudinary
│   └── theme/      Tokens + componentes reutilizables
└── features/       home, memory_form, gamer, map, profile — UI + lógica de pantalla
```

Gestión de estado: Riverpod, pero en dos patrones que conviven sin fusionarse — `StateNotifier` + caché SharedPreferences (`memoryProvider`, la ruta "principal" usada por Home/Detail/Profile) y `StreamProvider` directo sobre Firestore (`memory_map_provider`, usado solo por el Mapa). Esto no es un problema de estilo: son **dos fuentes de verdad independientes sobre la misma colección**, cada una con su propio listener en tiempo real (ver hallazgo ARCH-1 / PERF-2).

Navegación: `go_router` con `ShellRoute` para el dock inferior — implementación estándar, sin problemas encontrados.

No hay backend propio, no hay funciones serverless (`Cloud Functions` no aparece en el repo), no hay `firestore.indexes.json` (no hace falta con las queries actuales, sin `where`/`orderBy` combinados).

## 4. Tecnologías detectadas

| Área | Tecnología | Versión en uso | Última disponible |
|---|---|---|---|
| Framework | Flutter / Dart | 3.44.6 / 3.12.2 | — |
| Estado | flutter_riverpod | 2.6.1 | 3.4.2 (major) |
| Navegación | go_router | 14.8.1 | 18.0.0 (major) |
| Backend as a service | firebase_core | 3.15.2 | 4.14.0 (major) |
| Auth | firebase_auth | 5.7.0 | 6.6.0 (major) |
| Base de datos | cloud_firestore | 5.6.12 | 6.9.0 (major) |
| Mapas | flutter_map, geolocator, geocoding | 8.3.1 / 14.0.3 / 2.2.2 | geocoding 5.0.0 (major) |
| Imágenes | image_picker, cached_network_image | 1.1.2 / 3.4.1 | al día |
| Almacenamiento de fotos | Cloudinary (API REST, unsigned upload) | — | — |
| Caché local | shared_preferences | 2.3.2 | al día |
| Tipografía | google_fonts | 6.3.3 | 8.2.1 (major) |
| Lint | flutter_lints | 6.0.0 | al día |
| Testing | flutter_test | SDK | — |
| Distribución | Firebase Hosting (PWA) + iOS ad-hoc; Android sin publicar | — | — |
| CI/CD | **ninguno detectado** | — | — |

## 5. Fortalezas

- **`flutter analyze` limpio y `flutter test` en verde (15/15)** — el código base está en buen estado de higiene básica, no es deuda acumulada sin control.
- **Migración de hogar (`household_migration_service.dart`) e idempotencia**: bien diseñada, con flag de control y reintento seguro si falla — el mejor ejemplo de "código hecho a medida del problema real" del repo.
- **Transacciones de Firestore donde realmente hacen falta**: `gamer_firestore_service.dart` usa `runTransaction` para las actualizaciones de puntuación concurrente (2 personas jugando a la vez) — es exactamente el único punto donde la concurrencia es un riesgo real, y está bien resuelto.
- **`MemoryNotifier` inyectable por constructor** — testeable pese a no tener tests propios (ver P1 de testing).
- **Decisiones de coste-cero bien razonadas y documentadas**: Cloudinary en vez de Firebase Storage, PWA en vez de certificado ad-hoc caduco — con la justificación por escrito en README, algo poco común y valioso.
- **Sin vectores de XSS/inyección HTML**: no hay ningún renderizador HTML/WebView en el proyecto, así que el texto libre de los formularios no es explotable ni en la build Web.
- **Secretos gestionados correctamente**: `key.properties`/`*.jks` fuera de git y verificados; no se encontró ninguna filtración adicional en el historial completo de git.
- **`web/manifest.json` e `index.html`**: PWA bien configurada (iconos maskable, theme-color, cache headers de larga duración para assets versionados) — nada que corregir ahí.
- **Auto-crítica ya presente en el propio repo**: el README documenta explícitamente sus propios riesgos de seguridad conocidos como "pendientes de revisión" — señal de un proceso de trabajo maduro, no de negación.

## 6. Problemas críticos (P0)

| ID | Problema | Ubicación | Impacto |
|---|---|---|---|
| SEC-1 | Firestore rules permiten leer/escribir cualquier documento del hogar a **cualquier** sesión autenticada (incluida anónima creada por un tercero) | `firestore.rules:12-18` | Quien conozca el `projectId` (`palito-de-sabores`, no secreto — visible en el bundle) puede autenticarse anónimo y leer/borrar/modificar todos los recuerdos, fotos de perfil y estadísticas del hogar, sin exploit, solo conociendo el proyecto |
| ARCH-1 | Doble instancia de `MemoryMapFirestoreService` con listener propio cada una (`memory_provider.dart` vs `memory_map_provider.dart`) + escritura triplicada al guardar un recuerdo (`memory_save_controller.dart:251-285`) | `lib/core/providers/memory_provider.dart:31-34`, `lib/core/providers/memory_map_provider.dart:11-14`, `lib/features/memory_form/controllers/memory_save_controller.dart:251-285` | 2 escrituras a `memories` + 3 a `locations` por cada guardado; 2 listeners permanentes sobre la misma colección duplicando lecturas/parseo/coste desde el primer uso del Mapa |
| PERF-1 | Fotos de Cloudinary servidas siempre a resolución original, sin transformación de tamaño ni compresión previa | `lib/features/memory_form/widgets/smart_image.dart:31-44`, `lib/core/services/storage_image_service.dart:20-50` | Cada miniatura en lista/mapa descarga la foto completa; el crédito gratuito mensual de Cloudinary (~25 GB) se agota con pocas decenas de visualizaciones repetidas |
| PERF-2 | 3 listeners `snapshots()` sin `.limit()`, sin `autoDispose`, activos de forma permanente tras la primera visita al Mapa | `memory_provider.dart`, `memory_map_provider.dart:21-89` | Triplica CPU/memoria/coste de lectura en cada escritura; a medida que crece el histórico, degrada tiempo de arranque y consumo |
| PERF-3 | Reserialización completa de la colección a SharedPreferences en cada alta/edición individual | `memory_provider.dart:199-208`, `storage_service.dart:348-394` | Cada guardado decodifica+codifica el JSON completo de todos los recuerdos en el hilo principal — no escala más allá de un histórico moderado y SharedPreferences no está pensado para blobs grandes |

## 7. Problemas importantes (P1)

| ID | Problema | Ubicación | Impacto |
|---|---|---|---|
| SEC-2 | Sin validación de tamaño/tipo de archivo antes de subir a Cloudinary (unsigned preset, sin límites del lado del cliente) | `storage_image_service.dart:20-50`, `photo_section.dart` | Combinado con el preset público, cualquiera con `cloudName`+`uploadPreset` puede subir archivos arbitrarios directamente a la cuenta de Cloudinary sin pasar por la app |
| ARCH-2 | `saveMemory` lee y escribe sin transacción | `memory_map_firestore_service.dart:1002-1417` | Condición de carrera real entre los 2 dispositivos del hogar editando a la vez |
| ARCH-3 | ~1.000 líneas duplicadas entre las 8 factories de formulario por categoría | `lib/features/memory_form/factories/*.dart` | Cualquier cambio de UI en un campo común (chip, slider, text field) hay que replicarlo 8 veces |
| PERF-4 | Sin clustering geográfico real, solo agrupación de coordenadas idénticas | `map_page.dart:1142-1177` | Con más recuerdos en direcciones distintas se crearán cientos/miles de marcadores simultáneos sin agregación por proximidad ni descarte fuera de viewport |
| PERF-5 | Recalculo O(n log n) sin memoización en cada `build()` (orden/filtro en Home, marcadores y firma de geocoding en Mapa) | `home_page.dart:196-231`, `map_page.dart:1131-1315`, `memory_geocoding_service.dart:57-98` | Cualquier rebuild trivial repite trabajo sobre toda la lista |
| PERF-6 | Geocodificación secuencial N+1, resultado nunca persistido de vuelta | `memory_geocoding_service.dart:325-632` | Se repite en cada arranque para las mismas direcciones sin coordenadas |
| UX-1 | Sin estado de error visible si falla el stream de Firestore; posible pantalla de carga infinita | `memory_provider.dart:222-235`, `home_page.dart:473-476` | El usuario no tiene forma de saber que algo falló ni de reintentar (el Mapa sí lo resuelve bien — inconsistencia entre pantallas) |
| UX-2 | Ejecución inconsistente del sistema neobrutalista: sombras Material suaves conviviendo con sombras duras de marca en las mismas pantallas | `home_page.dart:894-1020,521-567`, diálogo de logro en `gamer_page.dart` | Rompe la identidad visual justo en pantallas de alto tráfico (estado vacío/FAB) y en el momento de mayor impacto emocional (logro desbloqueado) |
| UX-3 | Sin `LayoutBuilder`/ancho máximo en pantallas principales; tarjetas de ancho fijo pensadas solo para móvil | `home_page.dart`, `memory_card.dart:177` | En la PWA de escritorio (uno de los 2 canales de distribución reales) el feed se estira o queda descentrado |
| TEST-1 | `MemoryNotifier` (CRUD + deduplicación, la lógica de negocio más crítica) sin ningún test pese a ser puro e inyectable | `memory_provider.dart:254-456` | Cualquier regresión en la sincronización local↔remoto pasaría inadvertida hasta producción |
| TEST-2 | Resolución de ubicación en el guardado sin test, con historial documentado de bug de geocoding | `memory_save_controller.dart:100-166` | Alto riesgo de reintroducir el mismo bug ya sufrido una vez |

## 8. Seguridad

Ver detalle completo en las tablas de las secciones 6-7 (SEC-1, SEC-2) y la sección 9 (P2/P3) más abajo. Resumen cualitativo: la superficie de ataque real es pequeña (app cliente sin backend, sin renderizado HTML, secretos gestionados correctamente), pero la **única barrera de acceso a los datos privados hoy es "estar autenticado con cualquier sesión, incluso anónima"** — eso es aceptable si el proyecto sigue siendo privado y desconocido, pero es la primera cosa a cerrar antes de cualquier publicación más visible (tienda de apps, repositorio público, etc.), y es barata de arreglar (no requiere sistema de cuentas nuevo, solo una whitelist de UIDs o claim en las reglas).

**Confirmado explícitamente que NO es un problema real** (para que no se gaste esfuerzo ahí): las API keys de Firebase en `firebase_options.dart`/`google-services.json`/`GoogleService-Info.plist` son públicas por diseño de Google; `key.properties`/`*.jks` están correctamente fuera de git; no hay vector de XSS al no existir renderizado HTML de contenido de usuario.

## 9. Performance

Ver P0/P1 en secciones 6-7 (PERF-1 a PERF-6). Adicionales de menor severidad:

| ID | Problema | Severidad |
|---|---|---|
| PERF-7 | Colección secundaria `locations` duplica datos de `memories` en cada guardado (2 `.get()` + batch) | P2 |
| PERF-8 | `debugPrint` por cada documento en cada snapshot recibido | P2 |
| PERF-9 | Migración de fotos legacy relee la colección completa en cada arranque hasta tener éxito una vez | P2 |
| PERF-10 | `saveMemory` hace 2 `.get()` secuenciales antes de cada escritura (latencia fija, no escala con volumen) | P3 |
| PERF-11 | Sin `firestore.indexes.json` — no es un problema hoy, mencionado porque cualquier futura paginación server-side lo requerirá | P3 (informativo) |

**Proyección de escalabilidad del modelo actual** (partición única de hogar): a ~10.000 recuerdos acumulados en el mismo hogar, la app dejaría de sentirse rápida: Home/Perfil recalculan agregados sobre toda la lista en cada rebuild, el Mapa crearía miles de marcadores sin descarte por viewport, y cada guardado reserializaría un JSON de varios MB a SharedPreferences. Esto **no** es un escenario de "1.000/10.000/100.000 usuarios" en el sentido clásico (el modelo actual es de un único hogar fijo, no multi-tenant), pero sí es el techo real de crecimiento del histórico de datos dentro del hogar actual, y conviene resolverlo antes de que se note en uso real.

## 10. Base de datos

Cloud Firestore, colecciones `users/{kHouseholdId}/memories`, `.../locations` (duplicada, ver PERF-7), datos del Gamer bajo el mismo árbol. No hay `where`/`orderBy` combinados en ninguna query, así que **no hacen falta índices compuestos hoy**. Sin capa de validación de esquema del lado del servidor (Firestore Rules solo controla auth, no forma de los datos) — es coherente con el tamaño del proyecto, pero significa que un documento mal formado desde el cliente puede llegar tal cual a Firestore (mitigado hoy porque solo hay una app cliente escribiendo). El único uso correcto de transacciones está en el contador de puntos del Gamer; el guardado de recuerdos (`memories`) carece de la misma protección (ARCH-2).

## 11. Frontend

Código de UI separado razonablemente de la capa de datos (ningún widget llama a Firestore directamente), pero con "God widgets" grandes (`map_page.dart` 1.802 líneas, `gamer_page.dart` 1.351, `home_page.dart` 1.234, `memory_form_page.dart` 1.061) que mezclan presentación, estado local y orquestación — no rompen nada hoy, pero dificultan cambios aislados y tests. Sistema de diseño con **tokens fantasma**: `AppTypography`/`AppShadows`/`AppRadius` están definidos pero no se usan en ningún sitio real (la UI real usa `GoogleFonts.outfit`/`.inter` y colores distintos a los declarados en esos tokens); `AppColors` se autodescribe como fuente única de verdad pero convive con colores hardcodeados en `neo_chip.dart` y `form_field_containers.dart` que hoy coinciden por casualidad, no por importación real.

## 12. UX/UI

El concepto neobrutalista está bien resuelto en los componentes principales (`memory_card.dart`, `app_dock.dart`, `neo_chip.dart`) pero se ejecuta de forma inconsistente en puntos de alto impacto: estado vacío/carga y FAB de Home usan sombras Material difusas en vez de sombra dura de marca, y el diálogo de logro desbloqueado del Gamer (el momento de mayor carga emocional de esa función) rompe también el lenguaje visual. Grosor de borde inconsistente entre componentes (2 / 2.5 / 3). Formularios: buena agrupación visual y buen feedback de guardado (spinner, avisos no bloqueantes), pero validación solo por SnackBar genérico sin resaltar el campo, y una excepción cruda del sistema se muestra directamente al usuario si falla el guardado. Accesibilidad: cero usos de `Semantics` en toda la app, solo 6 de 11 `IconButton` con tooltip. Ninguno de estos puntos cuestiona la decisión de marca (neobrutalismo) — son fallos de ejecución de esa decisión, no de concepto.

**Hallazgo adicional de documentación**: `DESIGN_PHILOSOPHY.md` describe un sistema "minimalista al estilo Apple" (tipografía serif, sombras muy sutiles, espaciado generoso) que **contradice directamente** el sistema neobrutalista documentado en README e implementado en el código real. Es casi con certeza un documento de una fase de diseño anterior que quedó desactualizado — debería actualizarse o retirarse para no confundir a quien llegue nuevo al proyecto.

## 13. Testing

`flutter test`: 15/15 en verde. Cobertura real (no trivial): `memory_model_test.dart` cubre parsing de fechas en 3 formatos, alias de campos legacy y clamping de rating; `storage_service_test.dart` cubre CRUD completo de la caché local, incluida deduplicación por ID. `widget_test.dart` es un smoke test correcto (arranca la app con un servicio Firestore falso inyectado). El hueco crítico es la ausencia total de test sobre `MemoryNotifier` (orquestación real de sincronización local↔remoto, TEST-1) y sobre la resolución de ubicación al guardar (TEST-2, con historial de bug real). La lógica de la ruleta/logros del Gamer tiene reglas de negocio genuinas pero está enterrada en un `StatefulWidget` de 1.351 líneas, por lo que no es testeable sin extraerla primero (TEST-3, P2). No hay tests de integración/E2E ni CI que ejecute nada automáticamente.

## 14. DevOps

No existe ningún pipeline de CI/CD (`.github/workflows` no existe, no hay GitLab CI, no hay Docker). Esto es la brecha DevOps más simple de cerrar: hoy mismo `flutter analyze` y `flutter test` pasan limpio, así que un workflow que los ejecute en cada push no arreglaría nada existente, pero blindaría contra regresiones futuras a coste casi cero. No hay Firebase Analytics ni Crashlytics (ya señalado en `V1_AUDIT.md` como bloqueante de producto, aquí se confirma también como brecha de observabilidad técnica: hoy no hay forma de saber si algo falla en producción salvo que un usuario lo reporte). El build de release de Android usa la firma de debug (irrelevante mientras no se publique en Play Store, pero hay que recordarlo si se decide publicar). Permisos nativos de iOS más amplios de lo necesario: `NSMicrophoneUsageDescription` (no hay funcionalidad de vídeo en la app) y `NSLocationAlwaysUsageDescription` (la app solo necesita ubicación "while in use") — generan prompts de permiso innecesarios y son un punto de fricción típico en revisión de App Store.

## 15. Escalabilidad

El límite real de escalabilidad hoy no es de usuarios (el modelo es de un hogar fijo, no multi-tenant) sino de **volumen de histórico dentro del hogar actual** — ver proyección detallada en la sección 9. Pasar de "1 hogar" a "N hogares/usuarios" (si el producto decide crecer, ver `MONETIZATION_ANALYSIS.md`/`MARKET_OPPORTUNITIES.md`) no es una función más: implica rediseñar rutas de Firestore, reglas de seguridad y los providers que hoy asumen un único árbol de datos — ya identificado como tal en `V1_AUDIT.md`, y esta auditoría lo confirma a nivel de código: no hay ninguna abstracción de "household ID dinámico" en ningún provider o servicio, todos importan la constante fija.

## 16. Deuda técnica

- Código muerto adicional no cubierto por la limpieza en curso: `mock_data.dart`, un método duplicado literal en `memory_model.dart:66-83` y una implementación de serialización muerta en `memory_model.dart:1221-1250`.
- 3 implementaciones distintas de "MemoryModel → mapa Firestore" conviviendo (una muerta, dos vivas y ligeramente distintas).
- Inversión de capas: `lib/core` (theme, factories) importa de `lib/features` en varios puntos — dirección de dependencia invertida respecto a lo esperado.
- Heurística frágil en `gamer_firestore_service.dart`: identifica a los 2 usuarios fijos por coincidencia de substring en el nombre ("eme", "ceh", "carmen") en vez de un identificador estable.
- `_parseDate` en `memory_model.dart` devuelve `DateTime.now()` silenciosamente ante una fecha ausente o inválida, enmascarando datos corruptos en vez de señalarlos.
- 312 llamadas a `debugPrint` en `lib/`, varias en rutas de autenticación imprimiendo UID/email — visibles en la consola del navegador en la build Web de producción (no es secreto, pero es ruido/huella de sesión evitable).
- Documentación desactualizada: `DESIGN_PHILOSOPHY.md` contradice el sistema de diseño real (sección 12).

## 17. Oportunidades de producto

Ya desarrolladas en profundidad en los documentos de producto existentes en este mismo repositorio — no se duplican aquí:
- `V1_AUDIT.md`: diagnóstico de producto completo (fortalezas, debilidades, ausencia de sistema de cuentas, de onboarding, de analítica, de lazo de crecimiento).
- `COMPETITIVE_ANALYSIS.md`: panorama de 35 apps de gastronomía + 18 híbridos de gaming gastronómico, con espacio en blanco detectado.
- `MARKET_OPPORTUNITIES.md`: mapa de oportunidades saturadas / competitivas / poco explotadas / blue ocean.
- `USER_NEEDS.md`: patrones de reviews reales sobre qué genera retención, abandono y recomendación.
- `MONETIZATION_ANALYSIS.md`: modelos de monetización compatibles con el proyecto y roadmap por fases.

Aportación técnica nueva de esta auditoría a esa conversación de producto: el contenido granular por categoría (activo diferenciador señalado en `V1_AUDIT.md` E.1) hoy vive en un modelo de datos (`MemoryModel`, 1.334 líneas) fuertemente acoplado a los 8 formularios fijos — cualquier evolución de producto que necesite categorías dinámicas o definidas por el usuario requeriría rediseñar el modelo, no solo añadir una pantalla.

## 18. Arquitectura objetivo

**No se recomienda ninguna reescritura.** La arquitectura actual (Flutter + Firestore + Cloudinary sin backend, Riverpod, go_router) es adecuada para el tamaño y objetivo del producto. Los cambios propuestos son quirúrgicos:

**Mantener tal cual** (no tocar): la elección de Firestore/Cloudinary/PWA, la estructura de carpetas `core`/`features`, go_router, el uso de `runTransaction` en Gamer, las 8 factories como concepto (formularios declarativos por categoría — solo extraer los widgets compartidos, no rediseñar el patrón).

**Cambiar**:
1. Un único punto de acceso a Firestore por colección, expuesto solo vía provider — elimina el listener y la escritura duplicados (ARCH-1/PERF-2). Esto es una consolidación, no una reescritura: ya existe el servicio correcto, solo hay que dejar de instanciarlo dos veces.
2. Reglas de Firestore acotadas a los UIDs reales del hogar (o un claim de autenticación equivalente) en vez de "cualquier autenticado" — sigue siendo gratis, sigue sin requerir sistema de cuentas nuevo.
3. Transacción en `saveMemory` igual que ya existe en Gamer.
4. Extraer widgets de formulario compartidos de las 8 factories (config declarativa se queda, implementación repetida se va).
5. Wiring real de los tokens de diseño (o borrar los que no se usan) para que un cambio de marca futuro toque un solo archivo.
6. CI mínimo + Crashlytics — infraestructura, no arquitectura de app.

**No introducir**: backend propio, microservicios, Clean Architecture con capas de repositorio/interfaces completas, gestor de estado nuevo, base de datos local indexada (sqflite/Hive) — ninguno está justificado por el volumen de datos ni el tamaño de equipo actuales. Si el histórico de un hogar supera varios miles de recuerdos y SharedPreferences empieza a notarse (PERF-3), ese es el único de estos puntos que merecería revisitarse, y solo entonces.

## 19. Roadmap priorizado

**FASE 1 — Seguridad y estabilidad**
- Acotar `firestore.rules` a los UIDs reales del hogar (SEC-1).
- Eliminar la instancia/listener duplicado de `MemoryMapFirestoreService` y las escrituras triplicadas al guardar (ARCH-1).
- Envolver `saveMemory` en `runTransaction` (ARCH-2).
- Configurar límites de tamaño/formato en el preset de Cloudinary desde su dashboard (SEC-2, sin cambio de código).
- Comprimir/redimensionar imágenes antes de subir y aplicar transformaciones de Cloudinary según contexto de visualización (PERF-1).

**FASE 2 — Calidad y arquitectura**
- Unificar la construcción `MemoryModel` → Firestore en un solo método, eliminando las 3 implementaciones distintas (ARCH-4).
- Extraer widgets compartidos de las 8 factories de formulario (ARCH-3).
- Corregir la inversión de capas `core`→`features` (ARCH-5).
- Corregir `_parseDate` para no enmascarar fechas corruptas (ARCH-7).
- Terminar la limpieza de código muerto ya en curso e incluir lo detectado aquí (`mock_data.dart`, duplicados en `memory_model.dart`).
- Envolver el logging de diagnóstico sensible en `kDebugMode`.

**FASE 3 — Performance**
- `autoDispose` en los `StreamProvider` del mapa; memoizar listas/marcadores recalculados en cada build (PERF-2, PERF-5).
- Persistir el resultado de geocoding para no repetirlo en cada arranque (PERF-6).
- Clustering geográfico real en el mapa (PERF-4).
- Revisar la colección `locations` duplicada (PERF-7) — evaluar si puede derivarse de `memories` en vez de mantenerse aparte.

**FASE 4 — UX/UI**
- Unificar la ejecución del neobrutalismo en los puntos detectados (estado vacío/FAB de Home, diálogo de logro del Gamer).
- Conectar los tokens de diseño reales o retirar los que no se usan; actualizar o retirar `DESIGN_PHILOSOPHY.md`.
- Estado de error visible cuando falla Firestore (hoy carga infinita silenciosa) (UX-1).
- Validación de formulario que resalte el campo afectado; no mostrar excepciones crudas al usuario (UX-6).
- Accesibilidad básica: `Semantics` en elementos clave, tooltips restantes.
- Responsive: ancho máximo/`LayoutBuilder` para la versión de escritorio de la PWA (UX-3).

**FASE 5 — Testing**
- Tests de `MemoryNotifier` (CRUD + deduplicación) (TEST-1).
- Tests de la resolución de ubicación en el guardado (TEST-2).
- Extraer la lógica de la ruleta/logros del Gamer a una clase testable, luego cubrirla (TEST-3).

**FASE 6 — DevOps/producción**
- CI mínimo (GitHub Actions): `flutter analyze` + `flutter test` en cada push.
- Firebase Crashlytics + Analytics básico.
- Cabeceras de seguridad en `firebase.json` (CSP, X-Frame-Options) — bajo coste, riesgo bajo pero no nulo.
- Retirar permisos nativos no usados en `Info.plist` (micrófono, ubicación "Always").

**FASE 7 — Escalabilidad** (condicional a una decisión de producto explícita de crecer más allá del hogar actual — no acometer sin esa decisión):
- Rediseño del modelo de datos a multi-tenant real, reglas de Firestore por usuario/hogar, sistema de cuentas.

**FASE 8 — Mejoras futuras**
- Actualización planificada de dependencias major (Riverpod 3, go_router 18, Firebase SDKs) una por una, con tests de regresión antes/después de cada salto.
- Revisitar la estrategia de caché local (SharedPreferences → alternativa indexada) solo si el volumen de datos de un hogar lo justifica en la práctica.
- Explorar las oportunidades de producto ya documentadas en `MARKET_OPPORTUNITIES.md`/`MONETIZATION_ANALYSIS.md`.

## 20. Riesgos

- **Pérdida o exposición total de datos privados**: si el `projectId` llega a conocerse (repo público, captura de red, etc.), cualquiera puede leer o borrar todo el histórico del hogar mientras las reglas de Firestore sigan abiertas a cualquier autenticado (SEC-1).
- **Agotamiento sorpresivo de cuota de Cloudinary**: el preset unsigned sin límites de tamaño/formato puede ser usado por un tercero para consumir la capa gratuita, dejando a la app sin poder subir fotos nuevas (SEC-2).
- **Regresión silenciosa**: sin CI, un cambio que rompa `flutter analyze`/`flutter test` no se detecta hasta que alguien lo nota manualmente en producción.
- **Coste creciente de posponer la actualización de dependencias**: cuanto más tiempo pase, más grande y arriesgado será el salto de major versions en Riverpod/go_router/Firebase.
- **Techo de rendimiento por volumen de histórico**: el modelo de caché local y de listeners sin límite no está preparado para un histórico de varios miles de recuerdos en el mismo hogar (secciones 6, 9, 15).

## 21. Quick wins (bajo esfuerzo, alto impacto)

1. Acotar `firestore.rules` a los UIDs reales del hogar — cambio de pocas líneas, cierra el riesgo más serio de la auditoría (SEC-1).
2. Configurar límites de tamaño/formato del preset de Cloudinary desde su dashboard — sin tocar código (SEC-2).
3. Añadir transformaciones de tamaño a las URLs de Cloudinary en miniaturas — ahorro inmediato de banda y velocidad percibida (PERF-1).
4. Retirar `NSMicrophoneUsageDescription` y `NSLocationAlwaysUsageDescription` de `Info.plist` — no se usan, generan fricción de permisos innecesaria.
5. Workflow de GitHub Actions con `flutter analyze` + `flutter test` — hoy ambos pasan limpio, así que solo blinda lo que ya funciona.
6. Envolver el `debugPrint` de datos de sesión en `kDebugMode`.
7. Actualizar o retirar `DESIGN_PHILOSOPHY.md` para que no contradiga el sistema de diseño real implementado.

## 22. Cambios de mayor impacto (más esfuerzo, cambian el techo del producto)

1. **Eliminar la duplicación de escrituras/listeners de Firestore** (ARCH-1/PERF-2) — es la raíz de varios síntomas de coste y coherencia a la vez; arreglar esto simplifica todo lo que depende de `memoryProvider`/`memoryMapService`.
2. **Extraer y testear la lógica de negocio hoy enterrada en widgets** (`MemoryNotifier`, resolución de ubicación, ruleta del Gamer) — no cambia el comportamiento visible, pero habilita refactors futuros seguros y reduce drásticamente el riesgo de regresión.
3. **Decisión de producto + rediseño de datos para sistema de cuentas real**, si se decide crecer más allá del hogar actual — el cambio más caro de todos, pero es el techo de crecimiento real ya identificado en `V1_AUDIT.md`; no acometer sin esa decisión de producto tomada primero.

## 23. Skills/agentes/MCP utilizados

- **4 agentes `general-purpose` en paralelo** (arquitectura/calidad de código, seguridad, performance/base de datos, frontend/UX/testing): permitieron lectura completa y profunda de las ~25.000 líneas de `lib/` sin saturar el contexto de coordinación; cada uno aportó hallazgos verificados con archivo:línea concretos, en vez de impresiones generales. Sin ellos, esta auditoría habría sido superficial o habría requerido muchas más rondas secuenciales.
- **Ejecución real, no solo lectura estática**: `flutter analyze` (0 issues) y `flutter test` (15/15) para verificar comportamiento real en vez de asumir que el código funciona porque parece correcto; `flutter pub outdated` para cuantificar con exactitud la deuda de dependencias.
- **Herramientas propias (Bash/Read/Grep)** para: `git status`/`log`/búsqueda de secretos en todo el historial, estructura de carpetas, contenido íntegro de `firestore.rules`, `firebase.json`, `Info.plist`, `AndroidManifest.xml`, `pubspec.yaml`, y los documentos de producto ya existentes en el repo.

**Capacidades disponibles pero NO utilizadas en esta fase, y por qué** (reservadas para la fase de implementación, tras tu aprobación):
- `firestore-rules-check` (skill del proyecto, activación automática al editar `firestore.rules`/`*_firestore_service.dart`): no se invocó porque esta fase es solo lectura, no se editó ningún archivo — se debe invocar en cuanto se implemente el cambio de reglas de FASE 1.
- MCP de Firebase (`mcp__firebase__*`): no fue necesario para auditar el repo local, pero se recomienda usarlo en la implementación para validar las nuevas reglas contra el proyecto real (`firebase_validate_security_rules`) antes de desplegarlas.
- `flutter-apply-architecture-best-practices` (skill del proyecto): orientada a reestructurar código; reservada para la FASE 2 de implementación, no se invoca en fase de solo-auditoría para no inducir cambios no aprobados.
- `ui-ux-pro-max`: reservada para la FASE 4, cuando haya cambios visuales concretos que diseñar (no había nada que diseñar en fase de auditoría).
- `security-review` (skill): pensada para revisar un diff de cambios pendientes; se recomienda ejecutarla al cerrar la FASE 1 de implementación, sobre los cambios ya hechos.
- `context7` (MCP de documentación de librerías): no fue necesario — los hallazgos son específicos del código propio, no de uso indocumentado de una API de terceros.

## 24. Recomendaciones finales

El proyecto no necesita "más ingeniería" — necesita cerrar una duplicación estructural en la capa de datos y una regla de seguridad demasiado abierta, ambas arreglables sin tocar la arquitectura de fondo. El resto de hallazgos son mejoras incrementales de higiene (dependencias, tests, observabilidad, consistencia visual) que se pueden abordar por fases sin ningún riesgo de romper lo que ya funciona en producción real. Recomiendo empezar exactamente por la FASE 1 tal como está priorizada arriba, validar que nada se rompe (`flutter analyze` + `flutter test` + prueba manual en dispositivo real), y solo entonces avanzar a la siguiente fase — sin mezclar cambios de fases distintas en el mismo commit.

Quedo a la espera de tu aprobación para empezar a implementar, fase por fase, según lo acordado.
