# Seguridad — acciones que solo puedes hacer tú

El código ya está corregido (ver `docs/AUDITORIA_2026-09.md`). Esto es lo que
queda fuera del repositorio y hay que hacer en las consolas.

Por orden de urgencia.

---

## 1. Desplegar las reglas de Firestore — AHORA

Mientras no se desplieguen, la base de datos sigue con las reglas antiguas y
los cuatro agujeros críticos siguen abiertos, aunque la app esté corregida.

```bash
cd "/Volumes/DISCO DURO/PALITO DE SABORES/palito_3_0"
firebase deploy --only firestore:rules
```

La app **1.1.0+7 que hay publicada no deja de funcionar** con las reglas
nuevas: el flujo de unirse con código ya escribía `usedBy` antes de entrar en
el grupo. Lo único que cambia es que ahora se comprueba en el servidor.

> Una excepción: la versión antigua escribe el grupo **sin** `lastJoinCode`,
> así que un usuario de la 1.1.0 que intente unirse a un grupo nuevo verá un
> error de permisos. Es el comportamiento correcto (es justo el agujero que se
> cierra), pero conviene forzar la actualización pronto.

## 2. Cloudinary: restringir el preset

`cloudName: utpoimts`, `uploadPreset: palito_fotos`, sin firmar y en claro
dentro del IPA. Cualquiera que lo extraiga con `strings` puede subir archivos
ilimitados a tu cuenta: agota el plan gratuito (la app deja de poder subir
fotos) y aloja contenido arbitrario bajo tu `cloudName`.

En **Settings → Upload → Upload presets → `palito_fotos`**:

- [ ] **Allowed formats**: `jpg, png, webp` (solo imágenes).
- [ ] **Max file size**: 8 MB (la app ya rechaza más, pero el servidor debe
      hacerlo también).
- [ ] **Folder**: `palito/` y **Unique filename** activado.
- [ ] **Strict transformations** activado.
- [ ] **Allowed upload origins**: limitar al dominio del PWA.

A medio plazo: rotar el preset (crear uno nuevo y borrar `palito_fotos`, que
ya está publicado en la App Store) y pasar a subida firmada con una Cloud
Function que devuelva `signature` + `timestamp`.

## 3. El grupo `palito-hogar`

`scripts/migrate_household.mjs` creó un grupo con el id fijo `palito-hogar`.
Un id de grupo adivinable era, con las reglas antiguas, acceso directo a todo
su contenido. Con las reglas nuevas ya no basta con conocerlo, pero conviene
no dejarlo:

- [ ] Comprobar en la consola de Firestore si `groups/palito-hogar` todavía
      tiene datos reales.
- [ ] Si los tiene, copiarlos a un grupo con id aleatorio y actualizar el
      `groupIds`/`personalGroupId` de las dos cuentas implicadas.
- [ ] Borrar el árbol antiguo, que sigue ahí desde la migración y contiene
      datos personales reales:
      `firebase firestore:delete --recursive users/palito-hogar`

## 4. Claves de API de Firebase

No son secretas (son identificadores públicos por diseño; el control real son
las reglas), pero conviene restringirlas:

- [ ] Google Cloud Console → APIs & Services → Credentials → para cada clave,
      **Application restrictions** (bundle id de iOS, SHA-1 de Android,
      referrers HTTP para web) y **API restrictions**.

## 5. Firebase Storage

El proyecto declara `storageBucket: palito-de-sabores.firebasestorage.app`
pero no hay `storage.rules` en el repositorio ni referencia en
`firebase.json`: si el bucket está activo, sus reglas no están versionadas ni
se revisan en cada despliegue, y pueden ser las permisivas de una fase
anterior (antes de migrar a Cloudinary).

- [ ] Comprobar en la consola si el bucket existe y tiene objetos.
- [ ] Si no se usa, dejarlo cerrado: crear `storage.rules` con
      `allow read, write: if false;` y añadir
      `"storage": { "rules": "storage.rules" }` a `firebase.json`.

## 6. Política de privacidad

`web/privacy.html` tiene dos afirmaciones que hoy no se corresponden con el
comportamiento real:

- [ ] Dice que el contenido de una cuenta borrada "queda archivado — no
      accesible por nadie". Con las reglas nuevas y el borrado de grupos vacíos
      ya es casi cierto, pero el texto debería describir lo que pasa de verdad:
      los grupos donde queda más gente **sí** conservan el contenido.
- [ ] No advierte de que las fotos alojadas en Cloudinary quedan en **URLs
      públicas**, accesibles sin autenticación para quien tenga el enlace, y
      que hoy **no se borran** al eliminar la cuenta.
- [ ] Faltan la base legal y el plazo de retención (RGPD). Y el correo de
      contacto es una cuenta personal de Gmail, no un canal de privacidad
      identificable.

## 7. Android, si va a Google Play

No es urgente (la app está en App Store), pero es **irreversible después de
publicar**:

- `applicationId = "com.example.palito_3_0"` — Play rechaza el prefijo
  `com.example`. Cambiarlo obliga a registrar una app Android nueva en Firebase
  con el id definitivo y sustituir `android/app/google-services.json`.
- La build de release se firma con la clave de **debug**
  (`android/app/build.gradle.kts`, `buildTypes.release`). Hay que configurar la
  firma real. El `.jks` y `key.properties` ya están ignorados en git —
  comprobar que siguen sin subirse nunca.
