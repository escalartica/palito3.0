# Pruebas antes de subir la 1.2.0+8

> **Importante**: las correcciones de septiembre de 2026 se escribieron sin
> acceso al SDK de Flutter, así que **nada de esto se ha compilado**. Los
> pasos 1 y 2 no son opcionales.

## 1. Compilación y análisis estático

```bash
cd "/Volumes/DISCO DURO/PALITO DE SABORES/palito_3_0"

flutter clean
flutter pub get
flutter analyze            # tiene que salir sin errores
dart format --set-exit-if-changed lib test   # opcional, pero deja el diff limpio
```

Si `flutter analyze` señala algo, corregir antes de seguir. Los puntos más
probables, por ser lo que más se ha tocado:

- `lib/main.dart` (router reestructurado)
- `lib/features/profile/profile_page.dart` (pestañas, grupos, nombre)
- `lib/core/theme/components/group_switcher.dart`
- `lib/core/services/household_service.dart` (nueva API `JoinResult`)

## 2. Pruebas automáticas

```bash
flutter test
```

Suites nuevas:

| Archivo | Qué fija |
|---|---|
| `test/rating_scale_test.dart` | La escala es 0–5, un 5/5 es "Extraordinario", la media ignora los recuerdos sin nota |
| `test/neo_chip_columns_test.dart` | "Decepcionante" no cabe en 3 columnas y baja a 2 |
| `test/navigation_test.dart` | El dock tiene 4 pestañas incluida Inicio; sin nombre, la app lo pide antes de entrar |

Las que ya existían (`memory_provider`, `memory_model`, `gamer_*`,
`widget_test`, `storage_service`) tienen que seguir en verde.

## 3. Reglas de Firestore

**Esto es lo más importante de toda la entrega.** Sin desplegarlas, los cuatro
agujeros críticos siguen abiertos aunque la app esté corregida.

```bash
# Simulación antes de tocar producción
firebase emulators:start --only firestore
# …y probar: unirse con código válido, con código gastado, con código caducado,
#    y añadirse a mano a un grupo SIN invitación (debe fallar).

firebase deploy --only firestore:rules
```

Comprobar a mano, con dos cuentas reales, **en este orden**:

1. Cuenta A crea un grupo → genera código → cuenta B se une. Debe funcionar y
   B debe ver el grupo activo con su nombre.
2. B intenta usar el mismo código otra vez → "Ese código ya se ha usado".
3. Desde la consola de Firestore, intentar añadir un uid a `members` de un
   grupo a mano **sin** invitación → debe rechazarse.
4. A quita a B del grupo → B, al abrir el selector de grupos, ya no lo ve y la
   app no se queda colgada.
5. B sale de un grupo estando dentro de él → la app vuelve a "Mi diario" sin
   pantallas en blanco.
6. Un usuario que es el único miembro borra su cuenta → el grupo desaparece de
   Firestore (antes quedaba con `members: []` y era reclamable).

## 4. Borrado de cuenta (Guideline 5.1.1(v))

Con una cuenta de prueba, no con la tuya:

- [ ] Perfil → Eliminar cuenta → **cancelar** la hoja de Apple → el mensaje
      dice "Borrado cancelado. No se ha eliminado nada." y los datos siguen ahí.
- [ ] Repetir y completar → la cuenta desaparece, la app vuelve a la pantalla
      de inicio de sesión.
- [ ] En el iPhone: Ajustes → tu Apple ID → Inicio de sesión con Apple →
      **Palito de Sabores ya no aparece**. Esto es lo que Apple comprueba.

## 5. Accesibilidad

En un iPhone físico:

- [ ] Ajustes → Accesibilidad → VoiceOver activado. Recorrer Inicio: el dock
      debe anunciarse como "Inicio, botón, seleccionado", "Mapa, botón"…
      (antes era completamente mudo).
- [ ] El botón "+" debe anunciarse como "Añadir un recuerdo nuevo".
- [ ] Ajustes → Pantalla → Tamaño del texto → al máximo. Recorrer Inicio,
      Formulario, Zona Gamer y Perfil buscando franjas amarillas y negras de
      overflow. **La app limita el escalado a 1,4×** mientras quede deuda de
      alturas fijas: si aun así aparece overflow, anotarlo.
- [ ] Ajustes → Accesibilidad → Movimiento → Reducir movimiento. Inicio debe
      aparecer **inmediatamente**, sin la entrada escalonada de 1,1 s.
- [ ] Contraste: revisar el texto gris de Zona Gamer y del detalle (antes había
      textos a 1,88:1).

## 6. Responsive

Probar en simulador, al menos:

| Dispositivo | Ancho | Qué mirar |
|---|---|---|
| iPhone SE (3ª gen) | 375 pt | Código de invitación (6→8 caracteres), fila de chips de Inicio, tarjetas de la lista |
| iPhone 16 Pro | 393 pt | El caso del vídeo |
| iPhone 17 Pro Max | 440 pt | Que el dock no se estire raro |

- [ ] La fila de filtros de Inicio: el último chip se corta con un margen que
      deja claro que hay más (antes parecía un "chip en blanco").
- [ ] El FAB "+" no pisa el chevron de la última tarjeta.
- [ ] El dock no queda debajo del indicador de inicio.
- [ ] Mapa: el contador y el botón de ubicación quedan por encima del
      indicador de inicio.

## 7. Recorrido funcional completo

- [ ] Instalar limpio → Sign in with Apple → **debe pedir el nombre** →
      entrar a Inicio.
- [ ] Crear un recuerdo con foto, ubicación y puntuación 5 → en el detalle
      debe verse **"5.0" con la barra llena y "Extraordinario"** (antes: media
      barra y "Por mejorar").
- [ ] Un recuerdo antiguo sin nota → "Sin nota" en la ficha, "—" en el mapa,
      y la Nota Media del perfil **no** debe bajar por su culpa.
- [ ] Empezar un recuerdo, hacer una foto, y pulsar atrás → **debe preguntar**
      antes de descartar.
- [ ] Denegar el permiso de Fotos y volver a intentarlo → debe salir un
      mensaje, no un silencio.
- [ ] Mapa → botón de ubicación con la ubicación desactivada → mensaje con
      acceso a Ajustes.
- [ ] Zona Gamer → girar la ruleta → **no debe haber hueco en blanco** antes
      de que aparezca el panel del ganador.
- [ ] Zona Gamer → tus puntos deben aparecer en Perfil (antes se quedaba en 0).
- [ ] Perfil → cambiar tu nombre → comprobar que el otro miembro del grupo lo
      ve actualizado.
- [ ] Perfil → pestaña de otra persona → **no** debe poder cambiarse su foto.

## 8. Build de release

```bash
flutter build ios --release
# y en Xcode: Product → Archive → Distribute
```

Antes de archivar, comprobar en Xcode:

- [ ] `CFBundleName` = "Palito de Sabores" (antes `palito_3_0`, y aparece en
      algunos diálogos del sistema).
- [ ] La versión es **1.2.0 (8)**.

### Android (si algún día va a Google Play)

**Bloqueado**, y no es cosa de esta entrega:

- `applicationId = "com.example.palito_3_0"` — Play rechaza el prefijo
  `com.example`, y **es inmutable después de publicar**. Hay que registrar una
  app Android nueva en Firebase con el id definitivo, descargar el
  `google-services.json` nuevo y cambiar los dos sitios a la vez.
- La release se firma con la clave de **debug**
  (`android/app/build.gradle.kts`). Hay que configurar la firma real; la
  `key.properties` y el `.jks` ya están correctamente ignorados en git.
