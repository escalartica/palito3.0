/// ===========================================================================
/// LO QUE CABE EN CADA CAMPO
/// ===========================================================================
///
/// POR QUÉ ESTO ES UN FICHERO Y NO UN NÚMERO SUELTO EN CADA `TextField`.
///
/// Algunos de estos topes no son una decisión de diseño: son **la misma cifra
/// que exige el servidor**. `firestore.rules` rechaza el documento entero si
/// el título de un recuerdo pasa de 200 caracteres:
///
/// ```
/// request.resource.data.title.size() <= 200
/// ```
///
/// Cuando el campo no conocía ese número, se podía escribir un título más
/// largo, rellenar el formulario entero, subir la foto, darle a guardar… y
/// recibir un «no se pudo guardar» sin ninguna pista de qué arreglar. El
/// límite existía; lo que faltaba era que la app lo supiera antes de pedirle
/// el trabajo al usuario.
///
/// `test/limites_campos_test.dart` lee `firestore.rules` y comprueba que
/// [tituloRecuerdo] y [nombreDiario] siguen coincidiendo con lo que el
/// servidor acepta. Si alguien cambia la regla y no el cliente —o al
/// revés— la prueba lo dice.
abstract final class FieldLimits {
  /// Título del recuerdo. **Atado a `firestore.rules`.**
  static const int tituloRecuerdo = 200;

  /// Nombre de un diario compartido. **Atado a `firestore.rules`**
  /// (`validName()`), y ya recortado también en `renameGroup`.
  static const int nombreDiario = 60;

  /// Nombre del restaurante o del sitio. No lo limita el servidor: lo limita
  /// el hueco donde se pinta —cabecera de la ficha, tarjeta de la lista y
  /// globo del mapa, tres sitios estrechos—.
  static const int nombreSitio = 120;

  /// Nombre de un comensal de la ruleta. Se canta a 34 puntos y se mete en
  /// una ficha de 74.
  static const int nombreComensal = 24;

  /// Un reto del juicio picante: se lee en voz alta, así que es una o dos
  /// frases.
  static const int retoPicante = 120;

  /// Un sabor escrito a mano en el surtido de croquetas.
  static const int saborCroqueta = 30;
}
