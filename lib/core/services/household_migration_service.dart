import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/household_config.dart';

/// Migración única: copia los datos del UID anónimo antiguo de este
/// dispositivo (bajo el que se guardaron los primeros recuerdos, antes de
/// que la app compartiera datos entre teléfonos) a [kHouseholdId].
///
/// Es segura de ejecutar en cualquier dispositivo, incluidos los que
/// nunca tuvieron datos propios: si no encuentra nada que migrar, no hace
/// nada. Se marca como completada en SharedPreferences para no repetirla
/// en cada arranque.
Future<void> migrateLegacyUserDataToHousehold() async {
  const prefsKey = 'household_migration_v1_done';

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(prefsKey) == true) {
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return;
  }

  final legacyUid = user.uid;

  if (legacyUid == kHouseholdId) {
    await prefs.setBool(prefsKey, true);
    return;
  }

  final firestore = FirebaseFirestore.instance;
  final legacyRef = firestore.collection('users').doc(legacyUid);
  final householdRef = firestore.collection('users').doc(kHouseholdId);

  try {
    final batch = firestore.batch();
    int migratedCount = 0;

    final memoriesSnap = await legacyRef.collection('memories').get();
    for (final doc in memoriesSnap.docs) {
      batch.set(
        householdRef.collection('memories').doc(doc.id),
        doc.data(),
        SetOptions(merge: true),
      );
      migratedCount++;
    }

    final locationsSnap = await legacyRef.collection('locations').get();
    for (final doc in locationsSnap.docs) {
      batch.set(
        householdRef.collection('locations').doc(doc.id),
        doc.data(),
        SetOptions(merge: true),
      );
    }

    final gamerStatsDoc = await legacyRef
        .collection('gamer_stats')
        .doc('main_stats')
        .get();
    if (gamerStatsDoc.exists) {
      batch.set(
        householdRef.collection('gamer_stats').doc('main_stats'),
        gamerStatsDoc.data()!,
        SetOptions(merge: true),
      );
    }

    final historySnap = await legacyRef.collection('game_history').get();
    for (final doc in historySnap.docs) {
      batch.set(
        householdRef.collection('game_history').doc(doc.id),
        doc.data(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    await prefs.setBool(prefsKey, true);

    debugPrint(
      '✅ Migración a hogar compartido completada: '
      '$migratedCount recuerdos desde uid=$legacyUid -> $kHouseholdId',
    );
  } catch (e, stack) {
    // No marcamos como completada: se reintentará en el próximo arranque.
    debugPrint('❌ Error migrando datos al hogar compartido: $e');
    debugPrintStack(stackTrace: stack);
  }
}
