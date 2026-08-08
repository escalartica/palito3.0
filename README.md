# 🥢 Palito de Sabores

> Diario gastronómico privado, compartido en tiempo real entre dispositivos — construido con Flutter, Firebase y una arquitectura pensada deliberadamente para funcionar con presupuesto **cero**.

Aplicación multiplataforma (iOS + Web/PWA) para registrar experiencias gastronómicas — restaurante, plato, puntuación, fotos y ubicación — con un sistema de "juicio" gamificado para decidir qué pedir o quién elige. Pensada desde el primer commit para que **dos personas** usen la misma cuenta desde dispositivos distintos y vean siempre los mismos datos.

<p align="center">
  <img src="docs/screenshots/gamer.png" width="220" alt="Zona Gamer: ruleta de decisiones" />
  <img src="docs/screenshots/achievements.png" width="220" alt="Insignias y logros de la mesa" />
  <img src="docs/screenshots/map.png" width="220" alt="Mapa de recuerdos" />
  <img src="docs/screenshots/profile.png" width="220" alt="Perfil y estadísticas" />
</p>

---

## Índice

- [Características](#características)
- [Stack técnico](#stack-técnico)
- [Decisiones de arquitectura](#decisiones-de-arquitectura)
- [Seguridad](#seguridad)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Cómo ejecutarlo](#cómo-ejecutarlo)
- [Estado actual (checkpoint v3.0 → v4.0)](#estado-actual-checkpoint-v30--v40)
- [Roadmap](#roadmap)

---

## Características

- **Registro de recuerdos**: restaurante, categoría, puntuación, ¿volverías?, foto y ubicación geolocalizada.
- **Formularios dinámicos por categoría**: croquetas, tortilla, ensaladilla, menú del día, plato estrella, postre, ambiente y atención tienen sus propios campos específicos, generados por una factory (`DynamicFieldFactory`).
- **Mapa interactivo** con clustering de recuerdos cercanos y selector cuando hay varios en el mismo punto (evita el problema clásico de "no puedo elegir cuál de los dos ver").
- **Zona Gamer**: ruleta de decisiones, seguimiento de puntos y racha por comensal, logros desbloqueables.
- **Perfil compartido** con estadísticas agregadas (recuerdos totales, nota media, índice de retorno, categorías más visitadas).
- **Sincronización en tiempo real** entre todos los dispositivos del hogar vía Cloud Firestore.
- **Fotos compartidas** entre dispositivos (alojadas en Cloudinary, no en el almacenamiento local del teléfono).
- **Distribución como PWA instalable**: sin App Store, sin coste, sin caducidad de certificado.
- Diseño **neobrutalista** consistente (bordes duros, sombras sólidas, sin degradados) con animaciones de entrada escalonadas en toda la app.

## Stack técnico

| Área | Tecnología |
|---|---|
| Framework | Flutter (Dart), objetivo iOS + Web |
| Gestión de estado | Riverpod |
| Navegación | go_router |
| Base de datos | Cloud Firestore (tiempo real) |
| Autenticación | Firebase Auth (anónima) |
| Almacenamiento de imágenes | Cloudinary (subida sin firmar, capa gratuita) |
| Hosting de la PWA | Firebase Hosting |
| Mapas | flutter_map + geolocator + geocoding |

## Decisiones de arquitectura

Esta sección documenta el *por qué*, no solo el *qué* — son las decisiones que probablemente más interese repasar en una entrevista.

### 1. Modelo de "hogar compartido" en Firestore

El primer diseño autenticaba cada dispositivo con una sesión anónima de Firebase y particionaba los datos por `uid` (`users/{uid}/memories`). Funcionaba perfectamente... hasta que se instalaba en un segundo teléfono: cada dispositivo genera un `uid` anónimo distinto, así que cada uno veía datos completamente distintos — el bug era invisible con un solo dispositivo de pruebas.

**Solución**: todas las rutas de Firestore se redirigen a un identificador fijo (`kHouseholdId`, ver [`lib/core/config/household_config.dart`](lib/core/config/household_config.dart)) en vez del `uid` de sesión. La autenticación anónima se conserva únicamente como puerta de seguridad (`request.auth != null` en las reglas), no como clave de partición de datos. Un servicio de migración de un solo uso ([`household_migration_service.dart`](lib/core/services/household_migration_service.dart)) reubica automáticamente, la primera vez que arranca la app tras la actualización, los datos que ya existían bajo el `uid` antiguo — para no perder el histórico ya registrado.

### 2. Fotos en Cloudinary, no en Firebase Storage

Firebase Storage exige plan de pago (Blaze) desde finales de 2024, incluso para uso dentro de la capa gratuita. Como el objetivo explícito del proyecto es coste cero, las fotos se suben a Cloudinary vía su API de subida sin firmar (`upload_preset` en modo *unsigned*, sin necesidad de exponer ninguna clave secreta en el cliente). Ver [`lib/core/services/storage_image_service.dart`](lib/core/services/storage_image_service.dart). Las implicaciones de seguridad de esta decisión están detalladas en la sección [Seguridad](#seguridad).

Las fotos y perfiles que ya existían guardados solo en el almacenamiento local del primer dispositivo se migran a Cloudinary con [`legacy_photo_migration_io.dart`](lib/core/services/legacy_photo_migration_io.dart) — implementado con **exportación condicional** (`if (dart.library.io)`) para que ese código, que depende de `dart:io`, no rompa la compilación para Web (donde `dart:io` no existe).

### 3. Distribución: PWA en vez de firma ad-hoc

Sin cuenta de pago de Apple Developer, una instalación nativa firmada con Apple ID gratuito caduca cada 7 días. La solución gratuita y permanente es servir la app como **PWA instalable** ("Añadir a pantalla de inicio"), sin pasar por App Store ni por ningún certificado que caduque.

El primer despliegue de la PWA resultó lento porque Firebase Hosting servía los activos pesados (el motor de renderizado, ~7&nbsp;MB) con solo 1 hora de caché HTTP — cada apertura pasada esa hora volvía a descargarlo todo. Se corrigió con cabeceras de caché de larga duración para los activos versionados (`Cache-Control: immutable, max-age=31536000`) y caché corta solo para `index.html` y el *service worker*, que son los que deben revisarse en cada visita para detectar actualizaciones (ver `firebase.json`).

## Seguridad

Esta versión prioriza deliberadamente **velocidad de entrega y coste cero** sobre un endurecimiento de seguridad exhaustivo. Es una decisión consciente para un proyecto personal de 2 usuarios de confianza, no un descuido — pero queda documentada aquí explícitamente para que no se pierda de vista, y como lista de partida para la auditoría de seguridad ya planificada de cara a la v4.0.

**Puntos conocidos, pendientes de revisión:**

- **Upload preset de Cloudinary público.** El modo *unsigned* expone el nombre del preset en el código cliente por diseño — es lo que permite subir fotos sin backend propio. Cualquiera que lo encuentre en este repositorio podría, en teoría, subir archivos a la cuenta de Cloudinary del proyecto. *Mitigación pendiente*: limitar formato y tamaño máximo, y activar moderación de subidas en el panel de Cloudinary.
- **Reglas de Firestore permisivas dentro del hogar.** Cualquier dispositivo autenticado (incluida una simple sesión anónima) puede leer y escribir cualquier documento bajo `users/{kHouseholdId}/**` (ver [`firestore.rules`](firestore.rules)). Es correcto para 2 usuarios de confianza que comparten todo; no sería válido si el proyecto creciera a usuarios sin relación entre sí.
- **Autenticación puramente anónima.** No hay verificación de identidad real. `kHouseholdId` no se expone en ningún endpoint público, pero tampoco es un secreto criptográfico — no es la barrera de seguridad, solo de conveniencia.

**Próximo paso explícito, antes o durante la v4.0**: auditoría de seguridad completa (reglas de Firestore, preset de Cloudinary, y evaluación de si migrar a autenticación real) — tratado como compromiso en el roadmap, no como tarea informal.

## Estructura del proyecto

```
lib/
├── core/
│   ├── config/          # Constantes compartidas (hogar, Cloudinary)
│   ├── data/             # Categorías, datos de ejemplo, StorageService (caché local)
│   ├── models/           # MemoryModel, UserModel
│   ├── providers/        # Riverpod: memorias, gamer, mapa, dock
│   ├── services/         # Firestore, migraciones, Cloudinary
│   └── theme/             # Tokens de diseño y componentes reutilizables
├── features/
│   ├── home/              # Inicio, detalle y formulario de recuerdos
│   ├── memory_form/       # Factories de campos dinámicos por categoría
│   ├── gamer/              # Zona Gamer
│   ├── map/                 # Mapa interactivo
│   └── profile/            # Perfil y estadísticas
└── main.dart               # Bootstrap: Firebase, Auth, migraciones, router
```

## Cómo ejecutarlo

```bash
flutter pub get

# iOS (requiere Xcode y un dispositivo o simulador)
flutter run -d ios

# Web / PWA
flutter run -d chrome
```

Necesitarás tu propio proyecto de Firebase (`flutterfire configure`) y una cuenta gratuita de [Cloudinary](https://cloudinary.com) con un *upload preset* en modo *unsigned*, configurados en:

- `lib/firebase_options.dart` (generado por FlutterFire CLI)
- `lib/core/config/cloudinary_config.dart`
- `lib/core/config/household_config.dart`

## Estado actual (checkpoint v3.0 → v4.0)

Este repositorio representa la **primera versión estable y de uso real** de Palito. Sirve como punto de partida documentado para la reescritura/mejora hacia la v4.0, de forma que quede constancia clara de qué se resolvió y por qué antes de iterar sobre ello.

Completado en esta versión:

- [x] CRUD completo de recuerdos con formularios dinámicos por categoría
- [x] Sincronización multi-dispositivo real (no solo multi-usuario) vía Firestore
- [x] Migración automática de datos y fotos heredadas de la arquitectura anterior
- [x] Fotos compartidas entre dispositivos vía Cloudinary
- [x] Mapa con clustering y selector de recuerdos superpuestos
- [x] Zona Gamer con persistencia de puntuaciones por comensal
- [x] Rediseño visual neobrutalista consistente + animaciones en toda la app
- [x] Icono de app personalizado (iOS + Web)
- [x] Distribución gratuita y permanente como PWA

## Roadmap

Ideas para la v4.0, sin comprometer el objetivo de coste cero:

- [ ] **Auditoría de seguridad completa** — ver [Seguridad](#seguridad); primer punto antes de crecer el proyecto
- [ ] Autenticación real (no solo anónima) si el proyecto crece más allá de un hogar
- [ ] Soporte Android nativo (el proyecto ya está preparado a nivel de Firebase)
- [ ] Tests automatizados (unitarios para providers, widget tests para las pantallas clave)
- [ ] Explorar monetización vía descargas (App Store / Play Store) manteniendo el núcleo gratuito

---

<p align="center">Proyecto personal — construido de forma iterativa, con foco en resolver problemas reales de uso diario.</p>
