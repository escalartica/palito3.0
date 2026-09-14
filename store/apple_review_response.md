# Respuesta a Apple — Guideline 2.1 Information Needed

Pega esto en "Responder al equipo de revisión de apps" (App Store Connect →
Distribución → Envío para iOS → Mensajes). El punto 1 (grabación de
pantalla) hay que adjuntarlo como archivo aparte en esa misma conversación
una vez grabado.

```
Thank you for the request. Here is the additional information:

1. Screen recording: attached (recorded on a physical device, iOS 26.6.1,
starting from app launch and covering the flows below).

2. Devices and OS tested before submission:
- iPhone 16 Pro, iOS 26.6.1
- iPhone 17 Pro, iOS 26.6.1

3. App description and target audience:
Palito de Sabores is a food diary app. Users log restaurants and dishes
they've tried with a photo, personal notes, a star rating, and the
location on a map. It also includes a lightweight gamification layer
("Zona Gamer"): a roulette to randomly pick where to eat, unlockable
achievements, and a points ranking. The target audience is anyone who
wants to keep track of restaurants/dishes they've enjoyed, alone or
shared with a small group of their choosing (partner, friends, family).
Every user gets a private personal diary automatically on first sign-in;
sharing with others is fully optional and set up later from the Profile
screen.

4. Instructions to access the app's main features:
The app uses Sign in with Apple exclusively — there is no traditional
username/password. The reviewer can sign in with any Apple ID; a private
personal diary is created automatically on first sign-in and the entire
app is usable immediately. To test the sharing feature: Profile ->
"Compartir con alguien más" -> "Crear un grupo nuevo", which generates a
one-time invite code that another account can use to join the same
shared diary.

5. External services used:
- Firebase Authentication (Sign in with Apple session handling)
- Cloud Firestore (app data storage)
- Firebase Analytics and Crashlytics (usage analytics and crash
  reporting — no third-party advertising or tracking)
- Cloudinary (user-uploaded photo storage)
- OpenStreetMap (map tiles shown in the app's map view)

6. Regional differences:
None. The app functions identically in all regions/countries — there is
no region-locked content or region-specific feature.

7. Regulated industry / protected third-party material:
Not applicable. The app is not in a regulated industry and does not
include any protected third-party material.

Regarding user-generated content: memories (photos/notes/ratings) are
private by default and only visible within a group the user explicitly
created or was invited to via a one-time code — there is no public feed
or discovery of other users' content, so no reporting/blocking mechanism
applies.

Please let us know if any further detail is needed.
```

## Nota sobre el flujo a grabar

Recorrido sugerido para el vídeo (en orden, sin cortes):
1. Abrir la app desde cero (mostrar el icono/lanzamiento).
2. Pantalla de inicio de sesión -> Sign in with Apple -> completar login.
3. Home con el diario personal (vacío o con recuerdos).
4. Crear un recuerdo nuevo: pulsar el botón de añadir, rellenar foto,
   valoración y nota -> aceptar los permisos de fotos/ubicación cuando
   aparezcan -> guardar.
5. Ver el recuerdo en el Mapa.
6. Zona Gamer: mostrar la ruleta y el ranking de puntos.
7. Perfil -> "Compartir con alguien más" -> crear un grupo y mostrar el
   código de invitación generado.
8. Perfil -> Cuenta -> "Eliminar cuenta" -> mostrar el diálogo de
   confirmación (doble confirmación) hasta el final, completándolo con
   una cuenta de prueba (no con tu cuenta real) para que Apple vea el
   flujo completo de borrado.
