# Auditoría y corrección — septiembre 2026

Revisión completa de Palito de Sabores sobre el estado real del disco duro
(v1.1.0+7, con commits que **no estaban** en `github.com/escalartica/palito3.0`,
que se había quedado en el 8 de agosto).

La versión corregida sale como **1.2.0+8**.

Fuentes de la auditoría: lectura completa del código, `firestore.rules`, la
configuración de iOS/Android/hosting, y una grabación de uso real en un
iPhone 16 Pro.

---

## 1. Seguridad — lo que había que cerrar antes de hacer publicidad

Todo lo de esta sección está **corregido en el código**, pero `firestore.rules`
**hay que desplegarlo** (`firebase deploy --only firestore:rules`) para que
surta efecto. Hasta entonces la base de datos sigue con las reglas antiguas.

### 1.1 Cualquiera podía entrar en cualquier grupo — CRÍTICO

Las reglas dejaban que un usuario autenticado se añadiera a `members` de
cualquier grupo con solo conocer su id. Todo el sistema de códigos era
validación del cliente, trivial de saltar desde la consola de Firebase o con
una llamada REST.

Además había un id **adivinable** publicado en el propio repositorio:
`scripts/migrate_household.mjs` fija `NEW_GROUP_ID = 'palito-hogar'`.

**Corregido**: ahora el servidor exige una invitación real. El cliente
reclama el código (`invites/{code}` → `usedBy`), y la regla del grupo
comprueba con un `get()` que esa invitación existe, apunta a ese grupo, no ha
caducado y fue reclamada por quien entra. Ver `isJoiningWithInvite()`.

**Acción tuya**: mover el grupo `palito-hogar` a un id aleatorio, o
comprobar que ya no tiene datos. Ver `docs/SEGURIDAD.md`.

### 1.2 Un código de un solo uso se podía volver eterno — CRÍTICO

La regla de `update` sobre `invites` validaba el estado *anterior* pero no el
*nuevo*: cualquiera podía escribir `useCount: 0` y `expiresAt: 2099` y
convertir un código gastado en ilimitado y permanente. Y era irrevocable,
porque no había forma de listar las invitaciones de un grupo para borrarla.

**Corregido**: el `update` solo admite tocar `usedBy`, `usedAt` y `useCount`,
`useCount` solo puede subir de uno en uno y `usedBy` tiene que ser quien
escribe. Se añade `allow list` para los miembros del grupo, y
`HouseholdService.activeInvitesFor()` / `revokeInvite()` para poder revocar.

### 1.3 Cualquier miembro podía echar a todos y quedarse el grupo — CRÍTICO

`allow update` era `isMemberOf(members)` a secas, sin validar ni un campo.
Alguien invitado a un grupo familiar podía escribir `members: [suUid]` y dejar
fuera al creador para siempre.

**Corregido**: `createdBy` e `isPersonal` son inmutables; `members` solo se
puede modificar para (a) salirte tú, (b) que el creador quite a otro, o (c)
unirse con invitación válida. Y `profileImages`/`memberProfiles` solo admiten
cambios en la entrada del propio usuario.

### 1.4 Los grupos de cuentas borradas quedaban reclamables — CRÍTICO

Al borrar la cuenta el grupo se quedaba con `members: []`, y las reglas
permitían que cualquiera se añadiera. Es decir: los recuerdos, direcciones y
fotos de alguien que había borrado su cuenta eran accesibles para quien
conociera el id. `web/privacy.html` afirma lo contrario.

**Corregido**: los grupos vacíos ya no son reclamables y ahora se **borran**
de verdad cuando sale el último miembro (antes no existía ninguna regla de
`delete` para grupos: eran indestructibles).

### 1.5 Borrar cuenta: sin revocar Apple, y con riesgo de borrado a medias — ALTA

- No se revocaba el token de Sign in with Apple. Apple lo exige desde junio de
  2022 y es motivo documentado de rechazo.
- Se borraban los datos **antes** de reautenticar: si el usuario cancelaba la
  hoja de Apple en ese momento, sus recuerdos y grupos ya no estaban, la
  cuenta seguía viva, y el mensaje que veía era "no se pudo eliminar la
  cuenta".
- Un `groupId` obsoleto en la lista (`not-found`) abortaba todo el proceso
  para siempre: el botón "Eliminar cuenta" dejaba de funcionar.

**Corregido**: se reautentica **primero**, se revoca el token con
`revokeTokenWithAuthorizationCode`, cada grupo se limpia en su propio
try/catch, y cancelar la hoja de Apple ya no borra nada ni se presenta como
un error de conexión.

### 1.6 Datos personales en los logs de producción — ALTA

`debugPrint` **no se desactiva en release**: sigue escribiendo al log del
sistema. La app estaba volcando ahí el uid, **el correo del usuario**,
coordenadas de recuerdos y —lo más grave— ids de grupo, que son la credencial
de acceso a un diario compartido.

**Corregido**: `lib/core/utils/app_log.dart` y un envoltorio `_log()` por
archivo; en release no se escribe nada. El correo se ha eliminado del log por
completo.

### 1.7 Cloudinary sin firmar — ALTA, pendiente de acción tuya

El `upload_preset` es *unsigned* y va en claro dentro del binario: cualquiera
que lo extraiga puede subir archivos ilimitados a tu cuenta y agotar el plan.
No se puede arreglar solo desde el código.

**Hecho**: timeout de 45 s, tope de 8 MB por foto, y el uid ya no se recibe
por parámetro (antes se podía cambiar la foto de perfil de otra persona).

**Acción tuya**: restringir el preset en el panel de Cloudinary. Ver
`docs/SEGURIDAD.md`.

### 1.8 Otros

- Subcolecciones de grupo: antes aceptaban documentos de cualquier nombre,
  forma y tamaño. Ahora hay límites y validación de `rating`, `title` e
  `imageUrls`.
- Hosting: añadidos `Strict-Transport-Security`, `Permissions-Policy` y
  `Content-Security-Policy`.
- Android: `allowBackup="false"` (el token de sesión entraba en la copia de
  seguridad de Google Drive) y permisos declarados explícitamente.

---

## 2. Los fallos del vídeo, con su causa

### 2.1 "0.0" por todas partes

Dos fallos distintos que se sumaban:

1. **Escala equivocada.** La nota se guarda en **0–5** (el slider y el modelo
   recortan a 5.0) pero la ficha de detalle la pintaba en **0–10**: dividía
   entre 10 para la barra, rotulaba los extremos "0" y "10", y solo llamaba
   "Extraordinario" a un ≥ 9 imposible de alcanzar. Un **5 sobre 5** salía a
   media barra y con la etiqueta **"Por mejorar"**.
2. **`0` no significa un cero, significa "sin puntuar".** La versión publicada
   no obligaba a poner nota, así que todos los recuerdos anteriores valen 0.
   El mapa los pintaba como "0.0★" y el perfil dividía la "Nota Media" entre
   *todos* los recuerdos, incluidos esos.

**Corregido** con una fuente única de verdad, `lib/core/data/rating_scale.dart`,
usada por la ficha, el mapa, las tarjetas y el perfil. Un recuerdo sin nota
muestra "Sin nota" / "—", nunca "0.0". Cubierto por `test/rating_scale_test.dart`.

### 2.2 Navegación

- El dock solo existía en **Inicio**: Mapa, Zona Gamer y Perfil eran rutas
  sueltas fuera del shell. Y el dock **no tenía pestaña de Inicio**, así que
  desde las otras pantallas no había forma evidente de volver.
- Peor: abrir un recuerdo apagaba el dock (`dockVisibleProvider = false`) y
  **no lo volvía a encender al salir**. Al volver a Inicio, la barra de
  navegación seguía oculta; solo reaparecía haciendo scroll hacia arriba, y
  si la lista era corta y no había scroll posible, hasta reiniciar la app.

**Corregido**: las cuatro pantallas están dentro del shell, el dock tiene
pestaña de Inicio, y su visibilidad depende de la ruta, no de que cada
pantalla se acuerde de reactivarlo. Cubierto por `test/navigation_test.dart`.

### 2.3 `gdvcgp2gdt`

El nombre se derivaba del prefijo del correo cuando Apple no lo daba — y Apple
solo entrega el nombre la **primera** vez que un Apple ID autoriza la app. Con
"Ocultar mi correo" el resultado es `gdvcgp2gdt@privaterelay.appleid.com` →
`gdvcgp2gdt`. Y **no había ninguna pantalla en toda la app para cambiarlo**.

**Corregido**: el nombre es un dato nuestro. Si Apple no lo da, se pide una vez
(`/tu-nombre`), y se puede cambiar desde Perfil. Al cambiarlo se propaga a la
copia que cada grupo guarda en `memberProfiles` (antes era una foto fija del
momento de entrar).

### 2.4 "Guardar Cambios" no guardaba nada

`_saveProfileChanges()` hacía exactamente dos cosas: vibrar y mostrar
"¡Cambios guardados con éxito! 🚀". No escribía en ningún sitio.

**Corregido**: botón eliminado. Cada acción guarda al instante y lo dice.

### 2.5 Podías cambiar la foto de otra persona

Desde la pestaña de otro miembro, tocar el avatar abría **tu** galería y subía
la foto a `profileImages[uidAjeno]` — y las reglas lo permitían. El tooltip
incluso decía "Cambiar foto de perfil", confirmando la acción.

**Corregido** en las dos capas: la UI solo deja editar lo tuyo, y las reglas
limitan `profileImages`/`memberProfiles` a la entrada propia.

### 2.6 Gestionar grupos era inalcanzable

`removeMember` y `leaveGroup` existían y funcionaban, con diálogos de
confirmación y todo — pero solo se llegaba a ellos desde un chip pequeño en
Inicio, cuatro niveles abajo, y **cero de ellos estaba en la pantalla llamada
"Perfil"**, que es donde se buscan.

Y si te expulsaban de un grupo, el selector **se quedaba muerto**: la lectura
de ese grupo devolvía `permission-denied`, el `Future.wait` propagaba la
excepción y el panel no volvía a abrirse nunca. La autolimpieza escrita
precisamente para ese caso era código inalcanzable.

**Corregido**: sección "Grupos" en Perfil con el grupo activo, sus miembros,
invitar y salir; cada lectura con su try/catch y autolimpieza real; salir del
grupo activo resetea el grupo en curso (antes la app se quedaba en blanco); y
si el creador se va, cualquier miembro puede moderar (antes el grupo quedaba
ingobernable), tanto en la UI como en las reglas.

### 2.7 El texto de invitación mentía

> "Pásale este código — lo introducirá al abrir la app por primera vez."

Ese sitio no existe. El invitado abre la app, ve Inicio, y no tiene dónde
meterlo: hay que ir a Perfil → Grupos → "Unirme con un código". Quien invitaba
creía haber hecho su parte y el invitado no encontraba dónde.

**Corregido**: el texto dice la ruta real, y hay un botón "Copiar invitación
completa" que copia el mensaje con las instrucciones dentro, listo para pegar
en WhatsApp. Además, al unirse se **activa** el grupo y se confirma por su
nombre (antes la pantalla se cerraba en silencio y seguías viendo tu diario:
parecía que no había funcionado).

### 2.8 "Decepcionant / e"

El número de columnas de los chips salía de un umbral fijo de caracteres
(`> 13 ? 2 : 3`) que no miraba ni el ancho de la pantalla ni el tamaño de
letra. "Decepcionante" tiene exactamente 13 caracteres, así que caía en la
rama de 3 columnas, donde no cabe.

**Corregido**: se mide de verdad con un `TextPainter` contra el ancho
disponible y el `textScaler` real. Cubierto por
`test/neo_chip_columns_test.dart`.

Hay **8 copias** del mismo widget de rejilla repartidas por los formularios
(76 % de código duplicado entre los `factories/*_fields.dart`). Es la razón de
que este defecto se arreglara ya dos veces a mano —"Enciclopedia
gastronómica", "Desintegración"— y "Decepcionante" siguiera roto. El cálculo
ya es común; unificar los 8 widgets queda pendiente (§4).

### 2.9 El hueco enorme de Zona Gamer

El panel del ganador arrancaba su animación **después** de escribir en
SharedPreferences y en Firestore. Como `Transform.scale` no colapsa el layout,
el panel dejaba de pintarse pero seguía ocupando su sitio: un hueco blanco del
tamaño exacto del panel durante cientos de ms, o segundos con mala cobertura.

**Corregido**: la animación arranca en el mismo turno que el `setState`.

### 2.10 Los puntos nunca llegaban a tu cuenta

Los comensales por defecto se llamaban **'CeH'** y **'Eme'** (los nombres de
quienes hicieron la app) y ninguno traía `uid`. La sincronización con Firestore
solo sube la fila vinculada al usuario, así que los puntos **nunca** llegaban a
la cuenta y el Perfil mostraba 0 indefinidamente. La única pista de que había
que vincular era un texto gris de 11,5 px con un contraste de 2,65:1.

**Corregido**: nombres por defecto neutros y auto-vinculación de tu fila en el
primer arranque.

---

## 3. Accesibilidad

- **Cero `Semantics` en todo el proyecto**: la barra de navegación principal
  era literalmente invisible para VoiceOver/TalkBack (tres `GestureDetector`
  con un `Icon` pelado). Añadidos en el dock, el FAB, el botón de ordenación,
  los chips, las pestañas de perfil y las imágenes.
- **Contraste**: `textSecondary` daba 3,48:1 y había `grey.shade400/500`
  repartidos con ratios de 1,88:1 y 2,68:1. Paleta corregida en
  `app_colors.dart` con los ratios documentados. `onPrimary` estaba resuelto a
  blanco sobre el amarillo de marca (**1,43:1**): ahora es explícito.
- **Objetivos táctiles**: los filtros de Inicio medían 28 px de alto, el botón
  de ordenar 32, los del dock 42, los chips 42. Todos a 44–48 px, sin cambiar
  el tamaño visual.
- **Reducir movimiento**: no se consultaba `MediaQuery.disableAnimations` en
  ningún sitio. Con esa opción activada, Inicio tardaba **más de un segundo**
  en mostrar nada. Ahora se respeta en las transiciones de página, el dock, los
  chips y las barras de puntuación.
- **Texto ampliado**: varias alturas fijas reventaban con overflow. Se han
  convertido en mínimos, y hay un techo de escalado de 1,4× mientras quede
  deuda de alturas fijas (§4).

## 4. Lo que queda pendiente (deuda, no fallos)

Ordenado por lo que más rendiría:

1. **Unificar los 8 `_buildCompactChipGroup` duplicados** de los factories en
   el `NeoChipGroup` que ya existe y no se usa. ~850 líneas → ~35, y cualquier
   corrección de chips pasa a ser de una línea.
2. **Sistema de tipografía**: `AppTypography` declara 7 estilos y ninguna
   pantalla los usa; todas llaman a `GoogleFonts` con tamaños ad-hoc (11, 11.5,
   12, 13, 14, 15, 16, 17, 18, 19, 22, 28, 32). Mientras siga así, cada arreglo
   de contraste o de escalado hay que repetirlo en 20 archivos — y por eso el
   techo de escalado sigue en 1,4×.
3. **Fuentes empaquetadas**: `google_fonts` las descarga en el primer arranque.
   Sin red, la app usa la fuente del sistema con métricas distintas y se ve un
   salto de layout. Meter los `.ttf` en `assets/fonts/`.
4. **`Cloud Function` para unirse a un grupo**: la validación actual es sólida
   (el servidor comprueba la invitación), pero una función callable que haga
   las tres escrituras en una transacción elimina la ventana en la que el
   código queda reclamado y la unión a medias.
5. **Borrar las fotos de Cloudinary al eliminar la cuenta**: hoy siguen
   accesibles por URL para siempre. Requiere guardar el `public_id` (ahora se
   descarta) y una función con el `api_secret`.
6. **`ListView.builder` en Inicio**: la lista construye todas las tarjetas de
   golpe dentro de un `Column`, y las reconstruye en cada frame de la animación
   de entrada. Con 200 recuerdos se nota.
7. **Android para Google Play**: `applicationId = "com.example.palito_3_0"` y
   firma con la clave de debug. Play rechaza ambos. Ver `docs/SEGURIDAD.md`;
   hay que registrar la app en Firebase con el id nuevo antes de cambiarlo.
8. **`lib/core/models/user_model.dart`** es código muerto que no modela el
   documento real (`UserProfile` no se usa en ningún sitio y le faltan
   `groupIds`, `personalGroupId`…). Por eso toda la app manipula
   `Map<String, dynamic>` con casts sueltos.

---

## 5. Cómo verificar

Ver `docs/PRUEBAS_ANTES_DE_SUBIR.md`. **Nada de esto se ha compilado ni
ejecutado**: la revisión y las correcciones se hicieron sin acceso al SDK de
Flutter, así que `flutter analyze` y `flutter test` son obligatorios antes de
tocar nada más.
