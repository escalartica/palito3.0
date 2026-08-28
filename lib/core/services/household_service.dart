import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// ===========================================================================
/// HOUSEHOLD SERVICE
/// ===========================================================================
///
/// Crear un hogar, generar códigos de invitación y unirse a un hogar con
/// un código — la contraparte de escritura de
/// `lib/core/providers/household_provider.dart` (que solo lee).
///
/// NOTA DE SEGURIDAD: unirse a un hogar se valida aquí, en el cliente,
/// contra `firestore.rules` (ver `isJoiningHousehold()`), no mediante una
/// Cloud Function server-side. Eso significa que la única barrera real
/// contra unirse a un hogar ajeno sin invitación es que su `householdId`
/// (un ID de Firestore de ~20 caracteres aleatorios) no es adivinable ni
/// enumerable — el mismo modelo de confianza que ya usan los códigos de
/// invitación (legibles solo por ID exacto, nunca listables). Proporcional
/// al tamaño actual de la app; si crece, este es el punto a sustituir por
/// una Cloud Function que valide el código server-side antes de escribir.
/// ===========================================================================

class HouseholdService {
  HouseholdService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _codeAlphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin O/0/I/1, ambiguos al leerlos

  /// Crea un hogar nuevo con [uid] como único miembro inicial, y actualiza
  /// su `users/{uid}.householdId`. Devuelve el ID del hogar creado.
  Future<String> createHousehold({
    required String uid,
    required String displayName,
    String? photoUrl,
    String name = 'Nuestro hogar',
  }) async {
    final DocumentReference<Map<String, dynamic>> householdRef =
        _firestore.collection('households').doc();

    await householdRef.set(<String, dynamic>{
      'name': name,
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

    await _firestore.collection('users').doc(uid).update(<String, dynamic>{
      'householdId': householdRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '✅ HouseholdService: hogar creado ${householdRef.id} por $uid.',
    );

    return householdRef.id;
  }

  /// Genera un código de invitación de un solo uso (por defecto) para
  /// [householdId], válido durante [validFor].
  Future<String> createInvite({
    required String householdId,
    required String createdBy,
    int maxUses = 1,
    Duration validFor = const Duration(days: 7),
  }) async {
    final String code = _generateCode();

    await _firestore.collection('invites').doc(code).set(<String, dynamic>{
      'householdId': householdId,
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

  /// Une a [uid] al hogar asociado al código [code]. Lanza [StateError]
  /// con un mensaje legible si el código no existe, ya se agotó o caducó.
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

    final String? householdId = invite['householdId'] as String?;
    final int maxUses = (invite['maxUses'] as num?)?.toInt() ?? 1;
    final int useCount = (invite['useCount'] as num?)?.toInt() ?? 0;
    final Timestamp? expiresAt = invite['expiresAt'] as Timestamp?;

    if (householdId == null || householdId.isEmpty) {
      throw StateError('Ese código no es válido.');
    }

    if (useCount >= maxUses) {
      throw StateError('Ese código ya se ha usado.');
    }

    if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
      throw StateError('Ese código ha caducado.');
    }

    // Sin lectura previa del documento del hogar: request.resource.data
    // (el estado tras aplicar arrayUnion) es lo que evalúan las reglas,
    // así que no hace falta — y unirse a un hogar del que todavía no se
    // es miembro no está permitido leerlo primero de todos modos.
    await _firestore
        .collection('households')
        .doc(householdId)
        .update(<String, dynamic>{
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

    await _firestore.collection('users').doc(uid).update(<String, dynamic>{
      'householdId': householdId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '✅ HouseholdService: $uid se unió al hogar $householdId.',
    );
  }

  String _generateCode() {
    final Random random = Random.secure();

    return List<String>.generate(
      6,
      (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
    ).join();
  }
}
