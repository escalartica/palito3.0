import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';

/// Sube fotos a Cloudinary (gratis, sin tarjeta) en vez de al almacenamiento
/// local del dispositivo, para que sean visibles en todos los móviles del
/// grupo y en la PWA. Usa siempre bytes (Uint8List), nunca rutas de archivo —
/// es lo único verdaderamente multiplataforma (funciona igual en iOS, Android
/// y Flutter Web, donde no existe `dart:io`).
///
/// NOTA DE SEGURIDAD PENDIENTE: el `upload_preset` es de tipo *unsigned* y va
/// en claro dentro del binario, así que cualquiera que lo extraiga puede subir
/// archivos a la cuenta. Mientras no haya una Cloud Function que firme las
/// subidas, el preset debe estar restringido en el panel de Cloudinary
/// (formatos permitidos, tamaño máximo, carpeta fija, transformaciones
/// estrictas). Ver docs/SEGURIDAD.md.
class StorageImageService {
  /// Ninguna subida se queda colgada para siempre: en una wifi de bar sin
  /// salida real, `request.send()` no devolvía nunca y el botón se quedaba en
  /// "Guardando…" hasta que el usuario mataba la app.
  static const Duration _timeout = Duration(seconds: 45);

  /// 8 MB. Un original de iPhone puede pasar de 12 MB; subirlo entero gasta
  /// los datos del usuario y la cuota de Cloudinary para nada.
  static const int maxBytes = 8 * 1024 * 1024;

  static Uri get _uploadUri => Uri.parse(
    'https://api.cloudinary.com/v1_1/'
    '${CloudinaryConfig.cloudName}/image/upload',
  );

  static Future<String> _uploadToCloudinary(
    Uint8List bytes,
    String fileName,
  ) async {
    if (bytes.isEmpty) {
      throw Exception('La imagen está vacía.');
    }

    if (bytes.length > maxBytes) {
      throw Exception(
        'La foto pesa demasiado (${(bytes.length / 1048576).toStringAsFixed(1)} MB). '
        'Prueba con una más ligera.',
      );
    }

    final http.MultipartRequest request =
        http.MultipartRequest('POST', _uploadUri)
          ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: fileName),
          );

    final http.StreamedResponse streamedResponse = await request.send().timeout(
      _timeout,
      onTimeout: () => throw TimeoutException(
        'La subida está tardando demasiado. Comprueba tu conexión.',
      ),
    );

    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'No se pudo subir la foto (error ${response.statusCode}).',
      );
    }

    Map<String, dynamic> data;
    try {
      // Un portal cautivo puede devolver HTML con estado 200; sin este
      // try/catch, `jsonDecode` lanzaba un `FormatException` sin controlar.
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'La respuesta del servidor de fotos no es válida. '
        '¿Estás en una wifi que pide iniciar sesión?',
      );
    }

    final String? url = data['secure_url'] as String?;

    if (url == null || url.isEmpty) {
      throw Exception('El servidor de fotos no devolvió una URL válida.');
    }

    return url;
  }

  /// Sube la foto de un recuerdo y devuelve su URL pública.
  static Future<String> uploadMemoryImage({
    required String memoryId,
    required Uint8List bytes,
  }) {
    final String fileName =
        'memory_${memoryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    return _uploadToCloudinary(bytes, fileName);
  }

  /// Sube TU foto de perfil y guarda su URL en `groups/{groupId}`, campo
  /// `profileImages`, indexado por uid.
  ///
  /// El uid ya no se recibe por parámetro: se toma siempre de la sesión. Con
  /// el parámetro, bastaba con llamar al servicio con el uid de otra persona
  /// para cambiarle la foto de perfil a todo el grupo.
  static Future<String> uploadProfileImage({
    required String groupId,
    required Uint8List bytes,
  }) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('Tu sesión ha caducado. Vuelve a iniciar sesión.');
    }

    final String url = await _uploadToCloudinary(bytes, 'profile_$uid.jpg');

    await FirebaseFirestore.instance.collection('groups').doc(groupId).set(
      <String, dynamic>{
        'profileImages': <String, dynamic>{uid: url},
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return url;
  }

  /// Devuelve la URL de la foto de perfil de [uid] si existe.
  ///
  /// Solo para casos sueltos: las pantallas que ya observan el documento del
  /// grupo deben leer `profileImages` de ahí (ver
  /// `activeGroupProfileImagesProvider`) en vez de hacer una lectura completa
  /// del documento por cada miembro.
  static Future<String?> getProfileImageUrl(String groupId, String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('groups')
        .doc(groupId)
        .get();

    final Map<String, dynamic>? data = doc.data();
    if (data == null) return null;

    final Object? profileImages = data['profileImages'];
    if (profileImages is! Map) return null;

    final Object? url = profileImages[uid];
    return url is String && url.isNotEmpty ? url : null;
  }
}
