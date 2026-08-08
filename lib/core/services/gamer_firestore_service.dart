
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/household_config.dart';

/// ============================================================================
/// SERVICIO FIRESTORE DE GAMER
/// ============================================================================
///
/// RESPONSABILIDAD:
///
/// - Leer estadísticas Gamer desde Firestore.
/// - Normalizar estructuras antiguas y nuevas.
/// - Escribir estadísticas en una estructura compatible.
/// - Exponer streams tipados y normalizados.
/// - Registrar eventos históricos.
///
/// ARQUITECTURA:
///
/// Firestore
///    │
///    ▼
/// GamerFirestoreService
///    │
///    ├── normalización
///    │
///    ▼
/// GamerStats
///    │
///    ├── Eme
///    ├── CeH
///    └── Team
///
/// La UI NO debe interpretar directamente los campos de Firestore.
///
/// ============================================================================

class GamerFirestoreService {
  GamerFirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // ==========================================================================
  // CONSTANTES
  // ==========================================================================

  static const String usersCollection = 'users';

  static const String gamerStatsCollection = 'gamer_stats';

  static const String mainStatsDocument = 'main_stats';

  static const String gameHistoryCollection = 'game_history';

  // ==========================================================================
  // USUARIO ACTUAL
  // ==========================================================================

  User? get currentUser {
    return _auth.currentUser;
  }

  // ==========================================================================
  // UID ACTUAL
  // ==========================================================================

  String? get currentUid {
    return _auth.currentUser?.uid;
  }

  // ==========================================================================
  // REFERENCIA A LA COLECCIÓN GAMER DEL USUARIO ACTUAL
  // ==========================================================================

  // Igual que en MemoryMapFirestoreService: la ruta usa kHouseholdId (no
  // el uid anónimo del dispositivo) para que Eme y CeH compartan las
  // mismas estadísticas sin importar en qué teléfono jueguen.
  CollectionReference<Map<String, dynamic>>? get _userGamerCollection {
    if (_auth.currentUser == null) {
      return null;
    }

    return _firestore
        .collection(usersCollection)
        .doc(kHouseholdId)
        .collection(gamerStatsCollection);
  }

  // ==========================================================================
  // REFERENCIA A MAIN_STATS DEL USUARIO ACTUAL
  // ==========================================================================

  DocumentReference<Map<String, dynamic>>? get _currentMainStatsDocument {
    final CollectionReference<Map<String, dynamic>>? collection =
        _userGamerCollection;

    if (collection == null) {
      return null;
    }

    return collection.doc(mainStatsDocument);
  }

  // ==========================================================================
  // REFERENCIA A MAIN_STATS DE UN UID
  // ==========================================================================

  // El parámetro `uid` se conserva por compatibilidad de firma con las
  // llamadas existentes, pero la ruta real siempre apunta a kHouseholdId
  // (documento compartido por todo el hogar).
  DocumentReference<Map<String, dynamic>> _mainStatsDocumentForUid(
    String uid,
  ) {
    return _firestore
        .collection(usersCollection)
        .doc(kHouseholdId)
        .collection(gamerStatsCollection)
        .doc(mainStatsDocument);
  }

  // ==========================================================================
  // NORMALIZAR UID
  // ==========================================================================

  static String _normalizeUid(String uid) {
    return uid.trim();
  }

  // ==========================================================================
  // CONVERSIÓN SEGURA A INT
  // ==========================================================================

  static int _parseInt(
    dynamic value, {
    int fallback = 0,
  }) {
    if (value == null) {
      return fallback;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      final String cleanValue = value.replaceAll(
        RegExp(r'[^0-9-]'),
        '',
      );

      if (cleanValue.isEmpty) {
        return fallback;
      }

      return int.tryParse(cleanValue) ?? fallback;
    }

    return fallback;
  }

  // ==========================================================================
  // CONVERSIÓN SEGURA A BOOL
  // ==========================================================================

  static bool _parseBool(
    dynamic value, {
    bool fallback = false,
  }) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      final String normalized = value.trim().toLowerCase();

      if (normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'si' ||
          normalized == 'sí') {
        return true;
      }

      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no') {
        return false;
      }
    }

    if (value is num) {
      return value != 0;
    }

    return fallback;
  }

  // ==========================================================================
  // CONVERSIÓN SEGURA A LISTA DE STRINGS
  // ==========================================================================

  static List<String> _parseStringList(
    dynamic value,
  ) {
    if (value is Iterable) {
      return value
          .map(
            (dynamic item) => item.toString().trim(),
          )
          .where(
            (String item) => item.isNotEmpty,
          )
          .toList();
    }

    return <String>[];
  }

  // ==========================================================================
  // NORMALIZAR MAPA
  // ==========================================================================

  static Map<String, dynamic> _mapFromDynamic(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map(
          (
            dynamic key,
            dynamic value,
          ) =>
              MapEntry(
            key.toString(),
            value,
          ),
        ),
      );
    }

    return <String, dynamic>{};
  }

  // ==========================================================================
  // BUSCAR MAPA DE JUGADORES
  // ==========================================================================
  //
  // Soporta:
  //
  // users
  // players
  // comensales
  //
  // ==========================================================================

  static Map<String, dynamic> _extractPlayersMap(
    Map<String, dynamic> data,
  ) {
    final dynamic rawUsers =
        data['users'] ??
        data['players'] ??
        data['comensales'];

    return _mapFromDynamic(rawUsers);
  }

  // ==========================================================================
  // BUSCAR JUGADOR POR CLAVE
  // ==========================================================================

  static Map<String, dynamic>? _findPlayerData(
    Map<String, dynamic> players,
    List<String> aliases,
  ) {
    for (final MapEntry<String, dynamic> entry in players.entries) {
      final String key = entry.key
          .toString()
          .trim()
          .toLowerCase();

      for (final String alias in aliases) {
        final String normalizedAlias = alias.trim().toLowerCase();

        if (key == normalizedAlias ||
            key.contains(normalizedAlias)) {
          final Map<String, dynamic> playerData =
              _mapFromDynamic(entry.value);

          if (playerData.isNotEmpty) {
            return playerData;
          }
        }
      }
    }

    return null;
  }

  // ==========================================================================
  // BUSCAR JUGADOR POR UID
  // ==========================================================================

  static Map<String, dynamic>? _findPlayerByUid(
    Map<String, dynamic> players,
    String uid,
  ) {
    final String normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      return null;
    }

    for (final MapEntry<String, dynamic> entry in players.entries) {
      final Map<String, dynamic> playerData =
          _mapFromDynamic(entry.value);

      final String storedUid =
          playerData['uid']?.toString().trim() ?? '';

      if (storedUid == normalizedUid ||
          entry.key.trim() == normalizedUid) {
        return playerData;
      }
    }

    return null;
  }

  // ==========================================================================
  // NORMALIZAR ESTADÍSTICAS DE JUGADOR
  // ==========================================================================

  static GamerPlayerStats _playerStatsFromMap(
    Map<String, dynamic>? data, {
    required String uid,
    required String defaultName,
  }) {
    if (data == null || data.isEmpty) {
      return GamerPlayerStats.empty(
        uid: uid,
        displayName: defaultName,
      );
    }

    final String displayName =
        data['displayName']?.toString().trim().isNotEmpty == true
            ? data['displayName'].toString().trim()
            : data['name']?.toString().trim().isNotEmpty == true
                ? data['name'].toString().trim()
                : defaultName;

    return GamerPlayerStats(
      uid: uid,
      displayName: displayName,
      gamerPoints: _parseInt(
        data['gamerPoints'] ??
            data['total_score'] ??
            data['totalScore'] ??
            data['score'] ??
            data['points'],
      ),
      decisions: _parseInt(
        data['decisions'] ??
            data['totalDecisions'] ??
            data['total_decisions'],
      ),
      streak: _parseInt(
        data['streak'] ??
            data['decisions_streak'] ??
            data['currentStreak'],
      ),
      unlockedChallenges: _parseStringList(
        data['unlocked_challenges'] ??
            data['unlockedChallenges'],
      ),
    );
  }

  // ==========================================================================
  // LEER ESTADÍSTICAS DE DOCUMENTO
  // ==========================================================================

  static GamerPlayerStats _readPlayerFromDocument(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String uid,
    required String defaultName,
  }) {
    if (!snapshot.exists) {
      return GamerPlayerStats.empty(
        uid: uid,
        displayName: defaultName,
      );
    }

    final Map<String, dynamic> data =
        snapshot.data() ?? <String, dynamic>{};

    final Map<String, dynamic> players =
        _extractPlayersMap(data);

    final Map<String, dynamic>? playerData =
        _findPlayerByUid(players, uid);

    if (playerData != null) {
      return _playerStatsFromMap(
        playerData,
        uid: uid,
        defaultName: defaultName,
      );
    }

    return _playerStatsFromMap(
      data,
      uid: uid,
      defaultName: defaultName,
    );
  }

  // ==========================================================================
  // STREAM PRINCIPAL DE ESTADÍSTICAS GAMER
  // ==========================================================================
  //
  // Esta es la fuente tipada y normalizada utilizada por:
  //
  // - ProfilePage
  // - GamerPage
  // - Panel Pro
  // - cualquier otra pantalla Gamer
  //
  // ==========================================================================

  Stream<GamerStats?> getGamerStatsStream() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream.value(null);
    }

    return _mainStatsDocumentForUid(
      user.uid,
    ).snapshots().map(
      (
        DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (!snapshot.exists) {
          return GamerStats.empty(
            currentUid: user.uid,
          );
        }

        final Map<String, dynamic> data =
            snapshot.data() ?? <String, dynamic>{};

        return GamerStats.fromMainStats(
          data,
          currentUid: user.uid,
        );
      },
    );
  }

  // ==========================================================================
  // STREAM DE ESTADÍSTICAS GAMER DE UN UID
  // ==========================================================================

  Stream<GamerPlayerStats?> getUserGamerStatsStream(
    String uid,
  ) {
    final String normalizedUid = _normalizeUid(uid);

    if (normalizedUid.isEmpty) {
      return Stream.value(null);
    }

    return _mainStatsDocumentForUid(
      normalizedUid,
    ).snapshots().map(
      (
        DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
        return _readPlayerFromDocument(
          snapshot,
          uid: normalizedUid,
          defaultName: 'Usuario',
        );
      },
    );
  }

  // ==========================================================================
  // STREAM DEL PERFIL FIRESTORE
  // ==========================================================================

  Stream<Map<String, dynamic>?> getUserProfileStream(
    String uid,
  ) {
    final String normalizedUid = _normalizeUid(uid);

    if (normalizedUid.isEmpty) {
      return Stream.value(null);
    }

    return _firestore
        .collection(usersCollection)
        .doc(kHouseholdId)
        .snapshots()
        .map(
      (
        DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (!snapshot.exists) {
          return null;
        }

        return snapshot.data();
      },
    );
  }

  // ==========================================================================
  // ACTUALIZAR ESTADÍSTICAS DEL JUGADOR ACTUAL
  // ==========================================================================
  //
  // Método compatible con el código existente.
  //
  // Actualiza:
  //
  // - campos legacy en main_stats
  // - campos normalizados del usuario actual
  //
  // Si existe una estructura individual de jugadores,
  // actualiza el jugador asociado al UID actual.
  //
  // ==========================================================================

  Future<void> updateGamerStats({
    required int score,
    required int streak,
    required List<String> unlockedChallenges,
    int? decisions,
    String? displayName,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      debugPrint(
        '⚠️ GamerFirestoreService: '
        'no existe usuario autenticado.',
      );

      return;
    }

    final DocumentReference<Map<String, dynamic>> docRef =
        _mainStatsDocumentForUid(user.uid);

    try {
      await _firestore.runTransaction(
        (
          Transaction transaction,
        ) async {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(docRef);

          final Map<String, dynamic> currentData =
              snapshot.data() ?? <String, dynamic>{};

          final Map<String, dynamic> players =
              _extractPlayersMap(currentData);

          final bool hasIndividualPlayers =
              players.isNotEmpty;

          final int resolvedDecisions =
              decisions ??
              _parseInt(
                currentData['decisions'],
                fallback: 0,
              );

          final String resolvedDisplayName =
              displayName?.trim().isNotEmpty == true
                  ? displayName!.trim()
                  : user.displayName?.trim().isNotEmpty == true
                      ? user.displayName!.trim()
                      : 'Usuario';

          final Map<String, dynamic> legacyData =
              <String, dynamic>{
            'total_score': score,
            'gamerPoints': score,
            'decisions_streak': streak,
            'streak': streak,
            'decisions': resolvedDecisions,
            'unlocked_challenges': unlockedChallenges,
            'displayName': resolvedDisplayName,
            'last_updated': FieldValue.serverTimestamp(),
          };

          // ------------------------------------------------------------------
          // ESTRUCTURA LEGACY
          // ------------------------------------------------------------------

          if (!hasIndividualPlayers) {
            transaction.set(
              docRef,
              legacyData,
              SetOptions(
                merge: true,
              ),
            );

            return;
          }

          // ------------------------------------------------------------------
          // ESTRUCTURA CON JUGADORES INDIVIDUALES
          // ------------------------------------------------------------------

          final Map<String, dynamic> updatedPlayers =
              Map<String, dynamic>.from(players);

          String? playerKey;

          for (final MapEntry<String, dynamic> entry
              in updatedPlayers.entries) {
            final String key =
                entry.key.toString().trim().toLowerCase();

            final Map<String, dynamic> playerData =
                _mapFromDynamic(entry.value);

            final String storedUid =
                playerData['uid']?.toString().trim() ?? '';

            if (storedUid == user.uid ||
                key == user.uid.toLowerCase()) {
              playerKey = entry.key;
              break;
            }
          }

          // Si no encontramos el UID, intentamos localizar el jugador
          // correspondiente al usuario actual por nombre.
          playerKey ??= _findPlayerKeyByCurrentUser(
            updatedPlayers,
            user,
          );

          // Como último recurso, utilizamos el UID como clave.
          playerKey ??= user.uid;

          final Map<String, dynamic> existingPlayer =
              _mapFromDynamic(
            updatedPlayers[playerKey],
          );

          final Map<String, dynamic> updatedPlayer =
              <String, dynamic>{
            ...existingPlayer,
            'uid': user.uid,
            'displayName':
                displayName ??
                existingPlayer['displayName'] ??
                user.displayName ??
                'Usuario',
            'gamerPoints': score,
            'decisions': resolvedDecisions,
            'streak': streak,
            'unlocked_challenges': unlockedChallenges,
            'last_updated': FieldValue.serverTimestamp(),
          };

          updatedPlayers[playerKey] = updatedPlayer;

          transaction.set(
            docRef,
            <String, dynamic>{
              ...legacyData,
              'users': updatedPlayers,
              'players': updatedPlayers,
              'last_updated': FieldValue.serverTimestamp(),
            },
            SetOptions(
              merge: true,
            ),
          );
        },
      );

      debugPrint(
        '✅ GamerFirestoreService: '
        'estadísticas Gamer actualizadas. '
        'uid=${user.uid}, '
        'score=$score, '
        'streak=$streak',
      );
    } catch (e, stack) {
      debugPrint(
        '❌ GamerFirestoreService: '
        'error al actualizar estadísticas Gamer: '
        '$e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // BUSCAR CLAVE DEL JUGADOR POR DATOS DEL USUARIO ACTUAL
  // ==========================================================================

  static String? _findPlayerKeyByCurrentUser(
    Map<String, dynamic> players,
    User user,
  ) {
    final String currentDisplayName =
        user.displayName?.trim().toLowerCase() ?? '';

    if (currentDisplayName.isEmpty) {
      return null;
    }

    for (final MapEntry<String, dynamic> entry in players.entries) {
      final Map<String, dynamic> playerData =
          _mapFromDynamic(entry.value);

      final String storedName =
          playerData['displayName']?.toString().trim().toLowerCase() ??
          playerData['name']?.toString().trim().toLowerCase() ??
          '';

      if (storedName.isNotEmpty &&
          storedName == currentDisplayName) {
        return entry.key;
      }
    }

    return null;
  }

  // ==========================================================================
  // ACTUALIZAR ESTADÍSTICAS DE UN JUGADOR CONCRETO
  // ==========================================================================
  //
  // Este es el método recomendado para la arquitectura multiusuario.
  //
  // playerKey puede ser:
  //
  // - eme
  // - ceh
  // - cualquier clave existente en users/players
  //
  // ==========================================================================

  Future<void> updatePlayerStats({
    required String playerKey,
    required String uid,
    required int score,
    required int decisions,
    required int streak,
    List<String> unlockedChallenges = const <String>[],
    String? displayName,
  }) async {
    final String normalizedPlayerKey = playerKey.trim();

    final String normalizedUid = uid.trim();

    if (normalizedPlayerKey.isEmpty) {
      throw ArgumentError(
        'playerKey no puede estar vacío.',
      );
    }

    if (normalizedUid.isEmpty) {
      throw ArgumentError(
        'uid no puede estar vacío.',
      );
    }

    final DocumentReference<Map<String, dynamic>> docRef =
        _mainStatsDocumentForUid(normalizedUid);

    try {
      await _firestore.runTransaction(
        (
          Transaction transaction,
        ) async {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(docRef);

          final Map<String, dynamic> currentData =
              snapshot.data() ?? <String, dynamic>{};

          final Map<String, dynamic> players =
              _extractPlayersMap(currentData);

          final Map<String, dynamic> updatedPlayers =
              Map<String, dynamic>.from(players);

          final Map<String, dynamic> previousPlayer =
              _mapFromDynamic(
            updatedPlayers[normalizedPlayerKey],
          );

          final Map<String, dynamic> updatedPlayer =
              <String, dynamic>{
            ...previousPlayer,
            'uid': normalizedUid,
            'displayName':
                displayName ??
                previousPlayer['displayName'] ??
                'Usuario',
            'gamerPoints': score,
            'decisions': decisions,
            'streak': streak,
            'unlocked_challenges': unlockedChallenges,
            'last_updated': FieldValue.serverTimestamp(),
          };

          updatedPlayers[normalizedPlayerKey] = updatedPlayer;

          transaction.set(
            docRef,
            <String, dynamic>{
              'users': updatedPlayers,
              'players': updatedPlayers,
              'last_updated': FieldValue.serverTimestamp(),
            },
            SetOptions(
              merge: true,
            ),
          );
        },
      );

      debugPrint(
        '✅ GamerFirestoreService: '
        'jugador actualizado: '
        '$normalizedPlayerKey',
      );
    } catch (e, stack) {
      debugPrint(
        '❌ GamerFirestoreService: '
        'error actualizando jugador: '
        '$e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // REGISTRAR EVENTO HISTÓRICO
  // ==========================================================================

  Future<void> logGameSessionEvent({
    required String winnerName,
    required String eventDetail,
    required int pointsAwarded,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      debugPrint(
        '⚠️ GamerFirestoreService: '
        'no hay usuario autenticado.',
      );

      return;
    }

    try {
      await _firestore
          .collection(usersCollection)
          .doc(kHouseholdId)
          .collection(gameHistoryCollection)
          .add(
        <String, dynamic>{
          'winner_name': winnerName,
          'event_detail': eventDetail,
          'points_awarded': pointsAwarded,
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      debugPrint(
        '✅ GamerFirestoreService: '
        'evento Gamer registrado.',
      );
    } catch (e, stack) {
      debugPrint(
        '❌ GamerFirestoreService: '
        'error al registrar evento de juego: '
        '$e',
      );

      debugPrintStack(
        stackTrace: stack,
      );

      rethrow;
    }
  }
}

// ============================================================================
// ESTADÍSTICAS DE UN JUGADOR
// ============================================================================

class GamerPlayerStats {
  final String uid;
  final String displayName;
  final int gamerPoints;
  final int decisions;
  final int streak;
  final List<String> unlockedChallenges;

  const GamerPlayerStats({
    required this.uid,
    required this.displayName,
    required this.gamerPoints,
    required this.decisions,
    required this.streak,
    this.unlockedChallenges = const <String>[],
  });

  factory GamerPlayerStats.empty({
    String uid = '',
    String displayName = 'Usuario',
  }) {
    return GamerPlayerStats(
      uid: uid,
      displayName: displayName,
      gamerPoints: 0,
      decisions: 0,
      streak: 0,
      unlockedChallenges: const <String>[],
    );
  }

  GamerPlayerStats copyWith({
    String? uid,
    String? displayName,
    int? gamerPoints,
    int? decisions,
    int? streak,
    List<String>? unlockedChallenges,
  }) {
    return GamerPlayerStats(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      gamerPoints: gamerPoints ?? this.gamerPoints,
      decisions: decisions ?? this.decisions,
      streak: streak ?? this.streak,
      unlockedChallenges:
          unlockedChallenges ?? this.unlockedChallenges,
    );
  }
}

// ============================================================================
// ESTADÍSTICAS GAMER GENERALES
// ============================================================================

class GamerStats {
  final GamerPlayerStats eme;
  final GamerPlayerStats ceh;
  final GamerPlayerStats team;

  const GamerStats({
    required this.eme,
    required this.ceh,
    required this.team,
  });

  factory GamerStats.empty({
    String currentUid = '',
  }) {
    return GamerStats(
      eme: GamerPlayerStats.empty(
        uid: currentUid.isNotEmpty
            ? currentUid
            : 'eme',
        displayName: 'Eme',
      ),
      ceh: GamerPlayerStats.empty(
        uid: 'ceh',
        displayName: 'CeH',
      ),
      team: GamerPlayerStats.empty(
        uid: 'team',
        displayName: 'Team',
      ),
    );
  }

  // ==========================================================================
  // CONSTRUIR DESDE MAIN_STATS
  // ==========================================================================

  factory GamerStats.fromMainStats(
    Map<String, dynamic> data, {
    required String currentUid,
  }) {
    final Map<String, dynamic> players =
        GamerFirestoreService._extractPlayersMap(data);

    final Map<String, dynamic>? emeData =
        GamerFirestoreService._findPlayerData(
      players,
      <String>[
        'eme',
      ],
    );

    final Map<String, dynamic>? cehData =
        GamerFirestoreService._findPlayerData(
      players,
      <String>[
        'ceh',
        'carmen',
      ],
    );

    final bool hasIndividualPlayers =
        emeData != null ||
        cehData != null;

    GamerPlayerStats eme =
        GamerFirestoreService._playerStatsFromMap(
      emeData,
      uid: emeData?['uid']?.toString() ?? 'eme',
      defaultName: 'Eme',
    );

    GamerPlayerStats ceh =
        GamerFirestoreService._playerStatsFromMap(
      cehData,
      uid: cehData?['uid']?.toString() ?? 'ceh',
      defaultName: 'CeH',
    );

    // ------------------------------------------------------------------------
    // COMPATIBILIDAD CON ESTRUCTURA LEGACY
    // ------------------------------------------------------------------------
    //
    // Si no existen jugadores individuales,
    // los campos globales representan al usuario actual.
    //
    // Para conservar la compatibilidad actual de la aplicación,
    // se asignan al perfil Eme.
    //
    // ------------------------------------------------------------------------

    if (!hasIndividualPlayers) {
      final GamerPlayerStats legacyPlayer =
          GamerFirestoreService._playerStatsFromMap(
        data,
        uid: currentUid,
        defaultName: 'Eme',
      );

      eme = legacyPlayer.copyWith(
        uid: currentUid,
        displayName: 'Eme',
      );
    }

    // ------------------------------------------------------------------------
    // TEAM
    // ------------------------------------------------------------------------

    final GamerPlayerStats team = GamerPlayerStats(
      uid: 'team',
      displayName: 'Team',
      gamerPoints:
          eme.gamerPoints +
          ceh.gamerPoints,
      decisions:
          eme.decisions +
          ceh.decisions,
      streak:
          eme.streak +
          ceh.streak,
      unlockedChallenges:
          <String>{
        ...eme.unlockedChallenges,
        ...ceh.unlockedChallenges,
      }.toList(),
    );

    return GamerStats(
      eme: eme,
      ceh: ceh,
      team: team,
    );
  }
}

