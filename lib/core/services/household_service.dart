import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:palito_3_0/core/utils/app_log.dart';

/// ===========================================================================
/// HOUSEHOLD SERVICE
/// ===========================================================================
///
/// Crear grupos, generar códigos de invitación, unirse a un grupo con un
/// código y gestionar sus miembros — la contraparte de escritura de
/// `lib/core/providers/household_provider.dart` (que solo lee).
///
/// Cada usuario puede pertenecer a varios grupos a la vez (empezando siempre
/// por su grupo personal, creado en su primer inicio de sesión — ver
/// `AuthService`), así que crear/unirse a un grupo es siempre ADITIVO sobre
/// `users/{uid}.groupIds`, nunca lo sobrescribe.
///
/// SEGURIDAD — unirse a un grupo ya NO depende solo del cliente. Desde la
/// revisión de `firestore.rules`, el servidor exige que exista una invitación
/// válida, sin caducar, cuyo `groupId` coincida y que ya haya sido reclamada
/// por quien entra. El orden de escrituras de [joinHouseholdWithCode] es por
/// tanto obligatorio y no se puede meter en un `WriteBatch`: las reglas del
/// paso 2 leen con `get()` el resultado del paso 1, y dentro de un batch todas
/// las lecturas ven el estado anterior al batch.
/// ===========================================================================

class HouseholdService {
  HouseholdService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Sin O/0/I/1, ambiguos al leerlos en voz alta o en una captura.
  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// 8 caracteres sobre un alfabeto de 32 = 32^8 ≈ 1,1·10^12 combinaciones.
  /// Con 6 eran 1,07·10^9, al alcance de una fuerza bruta paciente contra
  /// `invites/{code}` (que cualquier usuario autenticado puede resolver por id).
  static const int _codeLength = 8;

  /// Crea un grupo nuevo con [uid] como único miembro inicial, y añade su id
  /// a `users/{uid}.groupIds` (sin tocar los demás grupos a los que ya
  /// pertenezca). Devuelve el ID del grupo creado.
  ///
  /// Ambas escrituras van en un único `WriteBatch`: antes eran dos escrituras
  /// independientes y, si la segunda fallaba, quedaba un grupo huérfano que
  /// nadie podía ver ni borrar — y, en el caso del grupo personal, el arranque
  /// volvía a crear otro en cada apertura de la app.
  ///
  /// [isPersonal] marca el diario privado que se crea automáticamente en el
  /// primer inicio de sesión de cada usuario — nunca se puede invitar a nadie
  /// a él (ver [createInvite]) ni aparece como grupo elegible para otra
  /// persona.
  Future<String> createHousehold({
    required String uid,
    required String displayName,
    String? photoUrl,
    required String name,
    bool isPersonal = false,
    bool linkAsPersonal = false,
  }) async {
    final String safeName = name.trim().isEmpty
        ? (isPersonal ? 'Mi diario' : 'Mi grupo')
        : name.trim();

    final DocumentReference<Map<String, dynamic>> groupRef = _firestore
        .collection('groups')
        .doc();

    final WriteBatch batch = _firestore.batch();

    batch.set(groupRef, <String, dynamic>{
      'name': safeName.length > 60 ? safeName.substring(0, 60) : safeName,
      'isPersonal': isPersonal,
      'members': <String>[uid],
      'memberProfiles': <String, dynamic>{
        uid: <String, dynamic>{
          'displayName': displayName,
          'photoUrl': photoUrl,
          'joinedAt': Timestamp.now(),
        },
      },
      'profileImages': <String, dynamic>{},
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // set(merge: true) en vez de update(): si el documento del usuario por lo
    // que sea todavía no existe (p. ej. se está reparando una sesión de Auth
    // cuyo perfil nunca llegó a escribirse — ver
    // AuthService.ensureUserDocument), update() lanzaría `not-found`.
    batch.set(_firestore.collection('users').doc(uid), <String, dynamic>{
      'groupIds': FieldValue.arrayUnion(<String>[groupRef.id]),
      // En el MISMO batch que la creación del grupo: o quedan los dos o no
      // queda ninguno. Antes eran dos escrituras y, si fallaba la segunda,
      // el arranque volvía a crear otro grupo personal en cada apertura.
      if (linkAsPersonal) 'personalGroupId': groupRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    AppLog.i('HouseholdService: grupo creado (isPersonal=$isPersonal).');

    return groupRef.id;
  }

  /// Genera un código de invitación de un solo uso (por defecto) para
  /// [groupId], válido durante [validFor]. Lanza [StateError] si [groupId] es
  /// el grupo personal de alguien — no es compartible.
  Future<String> createInvite({
    required String groupId,
    required String createdBy,
    int maxUses = 1,
    Duration validFor = const Duration(days: 7),
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> groupSnap = await _firestore
        .collection('groups')
        .doc(groupId)
        .get();

    if (!groupSnap.exists) {
      throw StateError('Ese grupo ya no existe.');
    }

    if (groupSnap.data()?['isPersonal'] == true) {
      throw StateError('Tu diario personal no se puede compartir.');
    }

    // Las reglas exigen maxUses entre 1 y 20 y una caducidad de menos de 31
    // días; recortamos aquí para que un error de programación se vea como un
    // valor corregido y no como un `permission-denied` opaco.
    final int safeMaxUses = maxUses.clamp(1, 20).toInt();
    final Duration safeValidFor = validFor > const Duration(days: 30)
        ? const Duration(days: 30)
        : validFor;

    final String code = _generateCode();

    await _firestore.collection('invites').doc(code).set(<String, dynamic>{
      'groupId': groupId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(safeValidFor)),
      'usedBy': null,
      'usedAt': null,
      'maxUses': safeMaxUses,
      'useCount': 0,
    });

    return code;
  }

  /// Invitaciones vivas (sin gastar y sin caducar) de [groupId], para poder
  /// revocarlas desde la app. Antes no había forma de listarlas, así que un
  /// código filtrado era irrevocable.
  Future<List<InviteSummary>> activeInvitesFor(String groupId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('invites')
        .where('groupId', isEqualTo: groupId)
        .get();

    final DateTime now = DateTime.now();

    return snap.docs
        .map(InviteSummary.fromDoc)
        .where((InviteSummary i) => !i.isSpent && i.expiresAt.isAfter(now))
        .toList()
      ..sort(
        (InviteSummary a, InviteSummary b) =>
            b.expiresAt.compareTo(a.expiresAt),
      );
  }

  /// Revoca (borra) un código de invitación.
  Future<void> revokeInvite(String code) {
    return _firestore
        .collection('invites')
        .doc(code.trim().toUpperCase())
        .delete();
  }

  /// Une a [uid] al grupo asociado al código [code]. Devuelve el nombre del
  /// grupo al que se ha unido, para poder confirmárselo al usuario (antes la
  /// pantalla se cerraba sin decir nada y parecía que no había funcionado).
  ///
  /// Lanza [StateError] con un mensaje legible si el código no existe, ya se
  /// agotó, caducó o apunta a un grupo del que ya se es miembro.
  Future<JoinResult> joinHouseholdWithCode({
    required String code,
    required String uid,
    required String displayName,
    String? photoUrl,
  }) async {
    final String normalizedCode = code.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      throw StateError('Introduce un código.');
    }

    final DocumentReference<Map<String, dynamic>> inviteRef = _firestore
        .collection('invites')
        .doc(normalizedCode);

    final DocumentSnapshot<Map<String, dynamic>> inviteSnap = await inviteRef
        .get();

    if (!inviteSnap.exists) {
      throw StateError('Ese código no existe.');
    }

    final Map<String, dynamic> invite =
        inviteSnap.data() ?? <String, dynamic>{};

    final String? groupId = invite['groupId'] as String?;
    final int maxUses = (invite['maxUses'] as num?)?.toInt() ?? 1;
    final int useCount = (invite['useCount'] as num?)?.toInt() ?? 0;
    final Timestamp? expiresAt = invite['expiresAt'] as Timestamp?;
    final String? usedBy = invite['usedBy'] as String?;

    if (groupId == null || groupId.isEmpty) {
      throw StateError('Ese código no es válido.');
    }

    if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
      throw StateError('Ese código ha caducado.');
    }

    // PASO 1 — reclamar el código. Si ya lo habíamos reclamado nosotros (un
    // intento anterior que falló al escribir en el grupo), se salta este paso:
    // las reglas del paso 2 comprueban `usedBy`, no `useCount`, precisamente
    // para que reintentar no gaste otra invitación.
    final bool alreadyClaimedByMe = usedBy == uid;

    if (!alreadyClaimedByMe) {
      if (useCount >= maxUses) {
        throw StateError('Ese código ya se ha usado.');
      }

      await inviteRef.update(<String, dynamic>{
        'usedBy': uid,
        'usedAt': FieldValue.serverTimestamp(),
        'useCount': FieldValue.increment(1),
      });
    }

    // PASO 2 — entrar en el grupo. `lastJoinCode` es lo que permite al
    // servidor verificar la invitación (ver firestore.rules).
    await _firestore.collection('groups').doc(groupId).update(<String, dynamic>{
      'members': FieldValue.arrayUnion(<String>[uid]),
      'memberProfiles.$uid': <String, dynamic>{
        'displayName': displayName,
        'photoUrl': photoUrl,
        'joinedAt': Timestamp.now(),
      },
      'lastJoinCode': normalizedCode,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // PASO 3 — registrar el grupo en la lista de conveniencia del usuario.
    await _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'groupIds': FieldValue.arrayUnion(<String>[groupId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    String groupName = 'tu nuevo grupo';
    try {
      final DocumentSnapshot<Map<String, dynamic>> groupSnap = await _firestore
          .collection('groups')
          .doc(groupId)
          .get();
      final Object? name = groupSnap.data()?['name'];
      if (name is String && name.trim().isNotEmpty) {
        groupName = name.trim();
      }
    } catch (_) {
      // El nombre es solo para el mensaje de confirmación; si falla la lectura
      // no tiene sentido deshacer una unión que ya ha funcionado.
    }

    AppLog.i('HouseholdService: unión a grupo completada.');

    return JoinResult(groupId: groupId, groupName: groupName);
  }

  /// Retira a [targetUid] de [groupId]: lo quita de `members` y borra sus
  /// entradas personales (`memberProfiles`/`profileImages`) — vale tanto para
  /// que alguien salga por su cuenta como para que el creador expulse a otro
  /// miembro.
  ///
  /// NO toca `users/{targetUid}.groupIds` — no puede: ese documento solo lo
  /// puede escribir su propio dueño (ver `firestore.rules`), y de todas formas
  /// no hace falta para la seguridad, porque el acceso a `groups/{groupId}` se
  /// decide por su `members`. El único efecto de no tocarlo es cosmético: el
  /// grupo puede seguir apareciendo un instante en la lista de la persona
  /// expulsada hasta que su propio dispositivo lo detecte y se autolimpie (ver
  /// `GroupSwitcher`).
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
  }

  /// Salir de [groupId] por cuenta propia — a diferencia de [removeMember],
  /// aquí sí se limpia también `users/{uid}.groupIds`, porque quien llama es
  /// el propio dueño de ese documento.
  ///
  /// Si eras el último miembro, el grupo se borra en vez de quedarse vacío:
  /// un grupo sin miembros no lo puede leer nadie, no lo puede borrar nadie y
  /// —con las reglas anteriores— era reclamable por cualquiera que conociera
  /// su id.
  Future<void> leaveGroup({
    required String groupId,
    required String uid,
  }) async {
    final DocumentReference<Map<String, dynamic>> groupRef = _firestore
        .collection('groups')
        .doc(groupId);

    List<String> members = <String>[];
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await groupRef.get();
      members = List<String>.from(
        (snap.data()?['members'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>(),
      );
    } on FirebaseException catch (e) {
      // Si ya no podemos leerlo es que ya no somos miembros: basta con
      // limpiar nuestra propia lista.
      if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
    }

    final bool amLastMember = members.length == 1 && members.first == uid;

    if (amLastMember) {
      await groupRef.delete();
    } else if (members.contains(uid)) {
      await removeMember(groupId: groupId, targetUid: uid);
    }

    await _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'groupIds': FieldValue.arrayRemove(<String>[groupId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Propaga un cambio de nombre a la copia que cada grupo guarda en
  /// `memberProfiles`. Sin esto, cambiar tu nombre en Perfil no se veía en
  /// ninguna parte: `memberProfiles` era una foto fija del momento de entrar.
  Future<void> syncDisplayNameInGroups({
    required String uid,
    required List<String> groupIds,
    required String displayName,
    String? photoUrl,
  }) async {
    if (groupIds.isEmpty) return;

    for (final String groupId in groupIds) {
      try {
        await _firestore
            .collection('groups')
            .doc(groupId)
            .update(<String, dynamic>{
              'memberProfiles.$uid.displayName': displayName,
              'memberProfiles.$uid.photoUrl': ?photoUrl,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } on FirebaseException catch (e) {
        // Un grupo del que ya nos han expulsado, o que ya no existe, no debe
        // impedir que el resto se actualice.
        if (e.code != 'permission-denied' && e.code != 'not-found') {
          AppLog.w('No se pudo sincronizar el nombre en un grupo: ${e.code}');
        }
      }
    }
  }

  String _generateCode() {
    final Random random = Random.secure();

    return List<String>.generate(
      _codeLength,
      (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
    ).join();
  }
}

/// Resultado de unirse a un grupo — el id hace falta para activarlo al
/// momento y el nombre para poder confirmárselo al usuario.
class JoinResult {
  const JoinResult({required this.groupId, required this.groupName});

  final String groupId;
  final String groupName;
}

/// Invitación viva de un grupo, para poder mostrarla y revocarla.
class InviteSummary {
  const InviteSummary({
    required this.code,
    required this.createdBy,
    required this.expiresAt,
    required this.maxUses,
    required this.useCount,
  });

  factory InviteSummary.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> d = doc.data();

    return InviteSummary(
      code: doc.id,
      createdBy: d['createdBy'] as String? ?? '',
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      maxUses: (d['maxUses'] as num?)?.toInt() ?? 1,
      useCount: (d['useCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String code;
  final String createdBy;
  final DateTime expiresAt;
  final int maxUses;
  final int useCount;

  bool get isSpent => useCount >= maxUses;
}
