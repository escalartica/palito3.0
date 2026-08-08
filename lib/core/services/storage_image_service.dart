import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';
import '../config/household_config.dart';

/// Sube fotos a Cloudinary (gratis, sin tarjeta) en vez de al almacenamiento
/// local del dispositivo, para que sean visibles en todos los móviles del
/// hogar y en la PWA. Usa siempre bytes (Uint8List), nunca rutas de
/// archivo — es lo único verdaderamente multiplataforma (funciona igual en
/// iOS, Android y Flutter Web, donde no existe `dart:io`).
class StorageImageService {
  static Uri get _uploadUri => Uri.parse(
    'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload',
  );

  static Future<String> _uploadToCloudinary(
    Uint8List bytes,
    String fileName,
  ) async {
    final request = http.MultipartRequest('POST', _uploadUri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Error subiendo imagen a Cloudinary '
        '(${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['secure_url'] as String?;

    if (url == null || url.isEmpty) {
      throw Exception(
        'Cloudinary no devolvió una URL válida: ${response.body}',
      );
    }

    return url;
  }

  /// Sube la foto de un recuerdo y devuelve su URL pública.
  static Future<String> uploadMemoryImage({
    required String memoryId,
    required Uint8List bytes,
  }) async {
    final fileName =
        'memory_${memoryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    return _uploadToCloudinary(bytes, fileName);
  }

  /// Sube la foto de perfil de un comensal (índice 0, 1 o 2), guarda su
  /// URL en Firestore (households/{hogar}, campo profileImages) para que
  /// sea la misma en todos los dispositivos, y la devuelve.
  static Future<String> uploadProfileImage({
    required int profileIndex,
    required Uint8List bytes,
  }) async {
    final url = await _uploadToCloudinary(bytes, 'profile_$profileIndex.jpg');

    await FirebaseFirestore.instance
        .collection('users')
        .doc(kHouseholdId)
        .set(
          {
            'profileImages': {'$profileIndex': url},
          },
          SetOptions(merge: true),
        );

    return url;
  }

  /// Devuelve la URL de la foto de perfil de [profileIndex] si existe, o
  /// `null` si ese comensal todavía no tiene foto.
  static Future<String?> getProfileImageUrl(int profileIndex) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(kHouseholdId)
        .get();

    final data = doc.data();
    if (data == null) return null;

    final profileImages = data['profileImages'];
    if (profileImages is! Map) return null;

    final url = profileImages['$profileIndex'];
    return url is String && url.isNotEmpty ? url : null;
  }
}
