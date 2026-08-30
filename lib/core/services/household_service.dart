import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// ===========================================================================
/// HOUSEHOLD SERVICE
/// ===========================================================================
///
/// Crear grupos, generar códigos de invitación y unirse a un grupo con un
/// código — la contraparte de escritura de
/// `lib/core/providers/household_provider.dart` (que solo lee).
///
/// Cada usuario puede pertenecer a varios grupos a la vez (empezando siempre
/// por su grupo personal, creado en su primer inicio de sesión — ver
/// `AuthService`), así que crear/unirse a un grupo es siempre ADITIVO sobre
/// `users/{uid}.groupIds`, nunca lo sobrescribe.
///
/// NOTA DE SEGURIDAD: unirse a un grupo se valida aquí, en el cliente,
/// contra `firestore.rules` (ver `isJoiningGroup()`), no mediante una Cloud
/// Function server-side. Eso significa que la única barrera real contra
/// unirse a un grupo ajeno sin invitación es que su `groupId` (un ID de
/// Firestore de ~20 caracteres aleatorios) no es adivinable ni enumerable —
/// el mismo modelo de confianza que ya usan los códigos de invitación
/// (legibles solo por ID exacto, nunca listables). Proporcional al tamaño
/// actual de la app; si crece, este es el punto a sustituir por una Cloud
/// Function que valide el código server-side antes de escribir.
/// ===========================================================================

class HouseholdService {
  HouseholdService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _codeAlphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin O/0/I/1, ambiguos al leerlos

  /// Crea un grupo nuevo con [uid] como único miembro inicial, y añade su id
  /// a `users/{uid}.groupIds` (sin tocar los demás grupos a los que ya
  /// pertenezca). Devuelve el ID del grupo creado.
  ///
  /// [isPersonal] marca el diario privado que se crea automáticamente en el
  /// primer inicio de sesión de cada usuario — nunca se puede invitar a
  /// nadie a él (ver [createInvite]) ni aparece como "grupo" elegible para
  /// otra persona.
  Future<String> createHousehold({
    required String uid,
    required String displayName,
    String? photoUrl,
    required String name,
    bool isPersonal = false,
  }) async {
    final DocumentReference<Map<String, dynamic>> groupRef =
        _firestore.collection('groups').doc();

    await groupRef.set(<String, dynamic>{
      'name': name,
      'isPersonal': isPersonal,
      'members': <String>[uid],
      'memberProfiles': <String, dynamic>{
        uid: <String, dynamic>{
          'displayName': displayName,
          'photoUrl': photoUrl,
          'joinedAt': FieldValue.serverTimestamp(),
        },
      },
      'profileImages': <String, dynamic>{},
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // set(merge: true) en vez de update(): si el documento del usuario
    // por lo que sea todavía no existe (p. ej. se está reparando una
    // sesión de Auth cuyo perfil nunca llegó a escribirse — ver
    // AuthService.ensureUserDocument), update() lanzaría `not-found`.
    await _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'groupIds': FieldValue.arrayUnion(<String>[groupRef.id]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint(
      '✅ HouseholdService: grupo creado ${groupRef.id} por $uid '
      '(isPersonal=$isPersonal).',
    );

    return groupRef.id;
  }

  /// Genera un código de invitación de un solo uso (por defecto) para
  /// [groupId], válido durante [validFor]. Lanza [StateError] si [groupId]
  /// es el grupo personal de alguien — no es compartible.
  Future<String> createInvite({
    required String groupId,
    required String createdBy,
    int maxUses = 1,
    Duration validFor = const Duration(days: 7),
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> groupSnap =
        await _firestore.collection('groups').doc(groupId).get();

    if (groupSnap.data()?['isPersonal'] == true) {
      throw StateError('Tu diario personal no se puede compartir.');
    }

    final String code = _generateCode();

    await _firestore.collection('invites').doc(code).set(<String, dynamic>{
      'groupId': groupId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(validFor)),
      'usedBy': null,
      'usedAt': null,
      'maxUses': maxUses,
      'useCount': 0,
    });

    return code;
  }

  /// Une a [uid] al grupo asociado al código [code], añadiéndolo a sus
  /// `groupIds` (sin tocar los demás grupos a los que ya pertenezca). Lanza
  /// [StateError] con un mensaje legible si el código no existe, ya se
  /// agotó o caducó.
  Future<void> joinHouseholdWithCode({
    required String code,
    required String uid,
    required String displayName,
    String? photoUrl,
  }) async {
    final String normalizedCode = code.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      throw StateError('Introduce un código.');
    }

    final DocumentReference<Map<String, dynamic>> inviteRef =
        _firestore.collection('invites').doc(normalizedCode);

    final DocumentSnapshot<Map<String, dynamic>> inviteSnap =
        await inviteRef.get();

    if (!inviteSnap.exists) {
      throw StateError('Ese código no existe.');
    }

    final Map<String, dynamic> invite =
        inviteSnap.data() ?? <String, dynamic>{};

    final String? groupId = invite['groupId'] as String?;
    final int maxUses = (invite['maxUses'] as num?)?.toInt() ?? 1;
    final int useCount = (invite['useCount'] as num?)?.toInt() ?? 0;
    final Timestamp? expiresAt = invite['expiresAt'] as Timestamp?;

    if (groupId == null || groupId.isEmpty) {
      throw StateError('Ese código no es válido.');
    }

    if (useCount >= maxUses) {
      throw StateError('Ese código ya se ha usado.');
    }

    if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
      throw StateError('Ese código ha caducado.');
    }

    // Sin lectura previa del documento del grupo: request.resource.data
    // (el estado tras aplicar arrayUnion) es lo que evalúan las reglas,
    // así que no hace falta — y unirse a un grupo del que todavía no se
    // es miembro no está permitido leerlo primero de todos modos.
    await _firestore.collection('groups').doc(groupId).update(<String, dynamic>{
      'members': FieldValue.arrayUnion(<String>[uid]),
      'memberProfiles.$uid': <String, dynamic>{
        'displayName': displayName,
        'photoUrl': photoUrl,
        'joinedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await inviteRef.update(<String, dynamic>{
      'usedBy': uid,
      'usedAt': FieldValue.serverTimestamp(),
      'useCount': FieldValue.increment(1),
    });

    await _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'groupIds': FieldValue.arrayUnion(<String>[groupId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('✅ HouseholdService: $uid se unió al grupo $groupId.');
  }

  /// Retira a [targetUid] de [groupId]: lo quita de `members` y borra sus
  /// entradas personales (`memberProfiles`/`profileImages`) — vale tanto
  /// para que alguien salga por su cuenta como para que el creador
  /// expulse a otro miembro.
  ///
  /// NO toca `users/{targetUid}.groupIds` — no puede: ese documento solo
  /// lo puede escribir su propio dueño (ver `firestore.rules`), y de
  /// todas formas no hace falta para la seguridad, porque el acceso a
  /// `groups/{groupId}` se decide por su `members`, no por lo que cada
  /// usuario diga de sí mismo (ver `isMemberOf`/`isGroupMember`). El
  /// único efecto de no tocarlo es cosmético — el grupo puede seguir
  /// apareciendo un instante en la lista de la persona expulsada hasta
  /// que su propio dispositivo lo detecte y se autolimpie (ver
  /// `GroupSwitcher._openSwitcher`).
  Future<void> removeMember({
    required String groupId,
    required String targetUid,
  }) async {
    await _firestore.collection('groups').doc(groupId).update(<String, dynamic>{
      'members': FieldValue.arrayRemove(<String>[targetUid]),
      'memberProfiles.$targetUid': FieldValue.delete(),
      'profileImages.$targetUid': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '✅ HouseholdService: $targetUid retirado del grupo $groupId.',
    );
  }

  /// Salir de [groupId] por cuenta propia — a diferencia de
  /// [removeMember], aquí sí se limpia también `users/{uid}.groupIds`,
  /// porque quien llama es el propio dueño de ese documento.
  Future<void> leaveGroup({
    required String groupId,
    required String uid,
  }) async {
    await removeMember(groupId: groupId, targetUid: uid);

    await _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'groupIds': FieldValue.arrayRemove(<String>[groupId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _generateCode() {
    final Random random = Random.secure();

    return List<String>.generate(
      6,
      (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
    ).join();
  }
}
