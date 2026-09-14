import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/household_service.dart';
import 'auth_provider.dart';

/// ===========================================================================
/// GROUP PROVIDERS
/// ===========================================================================
///
/// Cadena que resuelve "a qué grupos pertenece el usuario actual, y cuál está
/// viendo ahora mismo":
///
/// sesión (uid) -> users/{uid} -> groupIds -> [groups/{groupId}, ...]
///                              -> personalGroupId (grupo propio, por defecto)
///
/// Todo el mundo tiene siempre un grupo personal (su diario privado, creado
/// en su primer inicio de sesión — ver `AuthService`) y opcionalmente otros
/// grupos compartidos. El "grupo activo" es qué grupo se está viendo/usando
/// ahora mismo en Home/Mapa/Gamer/Perfil — estado de la sesión en curso, no
/// del servidor, así que un usuario puede cambiar de grupo sin que eso
/// afecte a sus otros dispositivos.
///
/// Cada servicio de datos (memorias, mapa, Gamer) observa
/// [activeGroupIdProvider] en vez de importar un identificador fijo, de modo
/// que sus lecturas/escrituras se redirigen automáticamente al grupo que el
/// usuario esté viendo.
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

/// Todos los grupos a los que pertenece el usuario actual (empezando por su
/// grupo personal) — vacío si no ha iniciado sesión o su documento todavía
/// no existe.
final userGroupIdsProvider = Provider<List<String>>((ref) {
  final Map<String, dynamic>? userDoc = ref
      .watch(currentUserDocProvider)
      .valueOrNull;

  final dynamic groupIds = userDoc?['groupIds'];

  if (groupIds is! List) {
    return const <String>[];
  }

  return groupIds.whereType<String>().toList();
});

/// El nombre que el usuario ha elegido, o `null` si todavía no tiene ninguno.
///
/// Nunca se deriva del correo: si Apple no dio el nombre (solo lo da en la
/// PRIMERA autorización de cada Apple ID), este provider devuelve `null` y la
/// app se lo pide. Antes se usaba el prefijo del email, que con "Ocultar mi
/// correo" producía nombres como `gdvcgp2gdt` imposibles de corregir.
final currentDisplayNameProvider = Provider<String?>((ref) {
  final Map<String, dynamic>? userDoc = ref
      .watch(currentUserDocProvider)
      .valueOrNull;

  final dynamic name = userDoc?['displayName'];

  return name is String && name.trim().isNotEmpty ? name.trim() : null;
});

/// `true` cuando ya sabemos quién es el usuario pero todavía no tenemos su
/// nombre — lo que dispara la pantalla "¿Cómo te llamas?".
final needsDisplayNameProvider = Provider<bool>((ref) {
  final AsyncValue<Map<String, dynamic>?> userDoc = ref.watch(
    currentUserDocProvider,
  );

  if (ref.watch(currentUidProvider) == null) return false;
  if (!userDoc.hasValue) return false;
  if (userDoc.value == null) return false;

  return ref.watch(currentDisplayNameProvider) == null;
});

/// Fotos de perfil del grupo activo, indexadas por uid. Se leen del documento
/// del grupo que ya estamos observando, en vez de hacer una lectura completa
/// por cada miembro como hacía `ProfilePage._loadProfileImages`.
final activeGroupProfileImagesProvider = Provider<Map<String, String>>((ref) {
  final Map<String, dynamic>? group = ref
      .watch(activeGroupDocProvider)
      .valueOrNull;

  final dynamic images = group?['profileImages'];

  if (images is! Map) return const <String, String>{};

  final Map<String, String> result = <String, String>{};
  images.forEach((dynamic key, dynamic value) {
    if (key is String && value is String && value.isNotEmpty) {
      result[key] = value;
    }
  });

  return result;
});

/// Nombres de los miembros del grupo activo, indexados por uid.
final activeGroupMemberNamesProvider = Provider<Map<String, String>>((ref) {
  final Map<String, dynamic>? group = ref
      .watch(activeGroupDocProvider)
      .valueOrNull;

  final dynamic profiles = group?['memberProfiles'];

  if (profiles is! Map) return const <String, String>{};

  final Map<String, String> result = <String, String>{};
  profiles.forEach((dynamic key, dynamic value) {
    if (key is! String || value is! Map) return;
    final dynamic name = value['displayName'];
    if (name is String && name.trim().isNotEmpty) {
      result[key] = name.trim();
    }
  });

  return result;
});

/// Quién creó el grupo activo — quien puede expulsar a otros miembros.
final activeGroupCreatedByProvider = Provider<String?>((ref) {
  final Map<String, dynamic>? group = ref
      .watch(activeGroupDocProvider)
      .valueOrNull;

  final dynamic createdBy = group?['createdBy'];

  return createdBy is String && createdBy.isNotEmpty ? createdBy : null;
});

/// El id del grupo personal del usuario actual — su diario privado. `null`
/// mientras no se conozca (sin sesión, o documento todavía no escrito).
final personalGroupIdProvider = Provider<String?>((ref) {
  final Map<String, dynamic>? userDoc = ref
      .watch(currentUserDocProvider)
      .valueOrNull;

  final dynamic personalGroupId = userDoc?['personalGroupId'];

  return personalGroupId is String && personalGroupId.isNotEmpty
      ? personalGroupId
      : null;
});

/// Override en memoria del grupo que el usuario ha elegido ver ahora mismo
/// (p. ej. desde el selector de grupo) — deliberadamente NO persistido: no
/// hace falta sincronizar "última pestaña vista" entre dispositivos ni entre
/// reinicios de la app, siempre se puede volver a elegir.
final activeGroupIdOverrideProvider = StateProvider<String?>((ref) => null);

/// El grupo activo: el que ha elegido explícitamente el usuario en esta
/// sesión, o su grupo personal por defecto.
final activeGroupIdProvider = Provider<String?>((ref) {
  final String? override = ref.watch(activeGroupIdOverrideProvider);
  if (override != null) return override;

  return ref.watch(personalGroupIdProvider);
});

/// Documento `groups/{groupId}` del grupo activo — `null` si todavía no se
/// conoce ninguno.
final activeGroupDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final String? groupId = ref.watch(activeGroupIdProvider);

  if (groupId == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .map((snapshot) => snapshot.data());
});

/// La lista de uids miembros del grupo activo (vacía si no hay grupo activo
/// todavía).
final activeGroupMembersProvider = Provider<List<String>>((ref) {
  final Map<String, dynamic>? group = ref
      .watch(activeGroupDocProvider)
      .valueOrNull;

  final dynamic members = group?['members'];

  if (members is! List) {
    return const <String>[];
  }

  return members.whereType<String>().toList();
});
