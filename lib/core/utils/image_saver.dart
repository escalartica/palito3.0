import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class ImageSaver {
  /// Guarda una imagen temporal en el almacenamiento permanente de la app (Documents Directory).
  /// Devuelve el NOMBRE del archivo para asegurar persistencia entre reinicios.
  static Future<String> saveImagePermanently(String tempPath) async {
    // CAMBIO: Usamos getApplicationDocumentsDirectory() para garantizar persistencia real en iOS
    final directory = await getApplicationDocumentsDirectory();
    
    // Aseguramos la existencia del directorio
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    // Generamos un nombre único
    final fileExtension = path.extension(tempPath);
    final fileName = const Uuid().v4() + fileExtension;
    final String fullPath = path.join(directory.path, fileName);
    
    // Copiamos el archivo al directorio de documentos
    final file = File(tempPath);
    await file.copy(fullPath);
    
    // VERIFICACIÓN CRÍTICA
    final savedFile = File(fullPath);
    if (await savedFile.exists()) {
      debugPrint("Imagen guardada exitosamente en: $fullPath");
      return fileName;
    } else {
      throw Exception("Error: El archivo no se ha podido persistir en disco.");
    }
  }

  /// Borra un archivo de imagen del almacenamiento mediante su nombre de archivo.
  static Future<void> deleteImage(String fileName) async {
    try {
      // CAMBIO: Debemos buscar en la misma carpeta donde guardamos (Documents)
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
        debugPrint("Imagen borrada correctamente: $fileName");
      }
    } catch (e) {
      debugPrint("Error al intentar borrar la imagen: $e");
    }
  }
}