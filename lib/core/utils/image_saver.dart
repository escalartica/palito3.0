import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class ImageSaver {
  /// Guarda una imagen temporal en el almacenamiento permanente de la app
  /// usando un nombre único para evitar colisiones.
  static Future<String> saveImagePermanently(String tempPath) async {
    final directory = await getApplicationDocumentsDirectory();
    
    // Generamos un nombre único
    final fileExtension = path.extension(tempPath);
    final fileName = const Uuid().v4() + fileExtension;
    
    // Realizamos la copia directamente sin asignar a una variable innecesaria
    await File(tempPath).copy('${directory.path}/$fileName');
    
    // Devolvemos solo el nombre del archivo
    return fileName;
  }

  /// Borra un archivo de imagen del almacenamiento si existe.
  static Future<void> deleteImage(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Error al intentar borrar la imagen: $e");
    }
  }
}