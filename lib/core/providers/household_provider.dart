import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/household_service.dart';
import 'auth_provider.dart';

/// ===========================================================================
/// HOUSEHOLD PROVIDERS
/// ===========================================================================
///
/// Cadena que resuelve "a qué hogar pertenece el usuario actual", en
/// sustitución de la constante fija `kHouseholdId`:
///
/// sesión (uid) -> users/{uid} -> householdId -> households/{householdId}
///
/// Cada servicio de datos (memorias, mapa, Gamer) observa
/// [currentHouseholdIdProvider] en vez de importar un identificador fijo,
/// de modo que sus lecturas/escrituras se redirigen automáticamente al
/// hogar correcto de cada usuario.
/// ===========================================================================

final householdServiceProvider = Provider<HouseholdService>((ref) {
  return HouseholdService();
});

/// Documento `users/{uid}` del usuario actual — `null` mientras no haya
/// sesión iniciada, o si el documento todavía no existe (recién creada la
/// cuenta, antes de que la app termine de escribirlo).
final currentUserDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final String? uid = ref.watch(currentUidProvider);

  if (uid == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snapshot) => snapshot.data());
});

/// El `householdId` del usuario actual, o `null` si ha iniciado sesión pero
/// todavía no pertenece a ningún hogar (o si no ha iniciado sesión).
final currentHouseholdIdProvider = Provider<String?>((ref) {
  final Map<String, dynamic>? userDoc =
      ref.watch(currentUserDocProvider).valueOrNull;

  final dynamic householdId = userDoc?['householdId'];

  return householdId is String && householdId.isNotEmpty
      ? householdId
      : null;
});

/// Documento `households/{householdId}` del hogar actual — `null` si el
/// usuario no pertenece a ninguno todavía.
final currentHouseholdDocProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  final String? householdId = ref.watch(currentHouseholdIdProvider);

  if (householdId == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('households')
      .doc(householdId)
      .snapshots()
      .map((snapshot) => snapshot.data());
});

/// La lista de uids miembros del hogar actual (vacía si no hay hogar).
final householdMembersProvider = Provider<List<String>>((ref) {
  final Map<String, dynamic>? household =
      ref.watch(currentHouseholdDocProvider).valueOrNull;

  final dynamic members = household?['members'];

  if (members is! List) {
    return const <String>[];
  }

  return members.whereType<String>().toList();
});
