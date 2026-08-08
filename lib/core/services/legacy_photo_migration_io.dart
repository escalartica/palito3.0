import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/household_config.dart';
import 'storage_image_service.dart';

/// Sube a Firebase Storage las fotos que quedaron guardadas solo en el
/// almacenamiento local de ESTE dispositivo (de antes de que la app subiera
/// las fotos a la nube), y actualiza Firestore para que pasen a ser
/// visibles en todos los móviles del hogar y en la PWA.
///
/// Solo puede recuperar fotos que sigan existiendo en el disco de este
/// mismo teléfono — por eso debe ejecutarse en el dispositivo original
/// donde se tomaron, antes de desinstalar la versión antigua.
Future<void> migrateLegacyPhotosToStorage() async {
  const prefsKey = 'legacy_photo_migration_v1_done';

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(prefsKey) == true) {
    return;
  }

  try {
    final appDir = await getApplicationDocumentsDirectory();
    final firestore = FirebaseFirestore.instance;
    final memoriesRef = firestore
        .collection('users')
        .doc(kHouseholdId)
        .collection('memories');

    int migratedMemoryPhotos = 0;
    int migratedProfilePhotos = 0;

    // --------------------------------------------------------------------
    // FOTOS DE RECUERDOS
    // --------------------------------------------------------------------

    final memoriesSnap = await memoriesRef.get();

    for (final doc in memoriesSnap.docs) {
      final data = doc.data();
      final rawUrls = data['imageUrls'];
      if (rawUrls is! List || rawUrls.isEmpty) continue;

      final urls = List<String>.from(rawUrls.map((e) => e.toString()));
      bool changed = false;

      for (int i = 0; i < urls.length; i++) {
        final entry = urls[i];
        if (entry.startsWith('http')) continue;

        final file = File('${appDir.path}/$entry');
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        final downloadUrl = await StorageImageService.uploadMemoryImage(
          memoryId: doc.id,
          bytes: bytes,
        );

        urls[i] = downloadUrl;
        changed = true;
        migratedMemoryPhotos++;
      }

      if (changed) {
        await doc.reference.update({'imageUrls': urls});
      }
    }

    // --------------------------------------------------------------------
    // FOTOS DE PERFIL
    // --------------------------------------------------------------------

    for (int i = 0; i < 3; i++) {
      final fileName = prefs.getString('profile_image_$i');
      if (fileName == null) continue;

      final file = File('${appDir.path}/$fileName');
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      await StorageImageService.uploadProfileImage(
        profileIndex: i,
        bytes: bytes,
      );

      migratedProfilePhotos++;
    }

    await prefs.setBool(prefsKey, true);

    debugPrint(
      '✅ Migración de fotos a Storage completada: '
      '$migratedMemoryPhotos fotos de recuerdos, '
      '$migratedProfilePhotos fotos de perfil.',
    );
  } catch (e, stack) {
    debugPrint('❌ Error migrando fotos a Storage: $e');
    debugPrintStack(stackTrace: stack);
  }
}
