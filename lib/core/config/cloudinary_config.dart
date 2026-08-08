/// Configuración de Cloudinary — almacenamiento de fotos gratuito (sin
/// tarjeta de crédito) que sustituye a Firebase Storage.
///
/// Cómo obtener estos valores:
/// 1. Crea una cuenta gratis en https://cloudinary.com
/// 2. `cloudName`: aparece en la parte superior del Dashboard.
/// 3. `uploadPreset`: Settings -> Upload -> Upload presets -> Add upload
///    preset -> Signing Mode: "Unsigned" -> Save. Usa el nombre del preset.
class CloudinaryConfig {
  static const String cloudName = 'utpoimts';
  static const String uploadPreset = 'palito_fotos';
}
