
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
///    ├── players (por uid, cualquier número de miembros)
///    └── Team (agregado)
///
/// La UI NO debe interpretar directamente los campos de Firestore.
///
/// ============================================================================

class GamerFirestoreService {
  GamerFirestoreService({
    required this.groupId,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _injectedFirestore = firestore,
        _injectedAuth = auth;

  /// ID del grupo activo del usuario (`groups/{groupId}`), resuelto
  /// por `activeGroupIdProvider` a partir de su sesión. Null si el
  /// usuario ha iniciado sesión pero todavía no se conoce ningún grupo.
  final String? groupId;

  // Resolución perezosa (ver el mismo patrón y justificación en
  // MemoryMapFirestoreService): no se tocan los singletons de Firebase
  // hasta el primer uso real.
  final FirebaseFirestore? _injectedFirestore;
  final FirebaseAuth? _injectedAuth;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  // ==========================================================================
  // CONSTANTES
  // ==========================================================================

  static const String _groupsCollection = 'groups';

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
  // REFERENCIA A MAIN_STATS DE UN UID
  // ==========================================================================

  // El parámetro `uid` se conserva por compatibilidad de firma con las
  // llamadas existentes, pero la ruta real siempre apunta al grupo actual
  // (documento compartido por todos sus miembros). Null si el usuario no
  // pertenece todavía a ningún grupo.
  DocumentReference<Map<String, dynamic>>? _mainStatsDocumentForUid(
    String uid,
  ) {
    if (groupId == null) {
      return null;
    }

    return _firestore
        .collection(_groupsCollection)
        .doc(groupId)
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

    final DocumentReference<Map<String, dynamic>>? docRef =
        _mainStatsDocumentForUid(user.uid);

    if (docRef == null) {
      return Stream.value(
        GamerStats.empty(currentUid: user.uid),
      );
    }

    return docRef.snapshots().map(
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

    final DocumentReference<Map<String, dynamic>>? docRef =
        _mainStatsDocumentForUid(normalizedUid);

    if (docRef == null) {
      return Stream.value(
        GamerPlayerStats.empty(
          uid: normalizedUid,
          displayName: 'Usuario',
        ),
      );
    }

    return docRef.snapshots().map(
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

    if (normalizedUid.isEmpty || groupId == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection(_groupsCollection)
        .doc(groupId)
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

    final DocumentReference<Map<String, dynamic>>? docRef =
        _mainStatsDocumentForUid(user.uid);

    if (docRef == null) {
      debugPrint(
        '⚠️ GamerFirestoreService: '
        'el usuario no pertenece a ningún grupo todavía.',
      );

      return;
    }

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

    final DocumentReference<Map<String, dynamic>>? docRef =
        _mainStatsDocumentForUid(normalizedUid);

    if (docRef == null) {
      throw StateError(
        'El usuario no pertenece a ningún grupo todavía.',
      );
    }

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

    if (groupId == null) {
      debugPrint(
        '⚠️ GamerFirestoreService: '
        'el usuario no pertenece a ningún grupo todavía.',
      );

      return;
    }

    try {
      await _firestore
          .collection(_groupsCollection)
          .doc(groupId)
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
  /// Estadísticas de cada miembro del grupo, indexadas por su uid — no por
  /// un nombre fijo. Soporta cualquier número de miembros.
  final Map<String, GamerPlayerStats> players;
  final GamerPlayerStats team;

  const GamerStats({
    required this.players,
    required this.team,
  });

  /// Estadísticas del miembro `uid`, o un valor vacío si todavía no tiene
  /// ninguna entrada (p. ej. se acaba de unir al grupo).
  GamerPlayerStats forUid(String uid) {
    return players[uid] ??
        GamerPlayerStats.empty(uid: uid);
  }

  factory GamerStats.empty({
    String currentUid = '',
  }) {
    return GamerStats(
      players: currentUid.isNotEmpty
          ? <String, GamerPlayerStats>{
              currentUid: GamerPlayerStats.empty(
                uid: currentUid,
              ),
            }
          : const <String, GamerPlayerStats>{},
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
    final Map<String, dynamic> rawPlayers =
        GamerFirestoreService._extractPlayersMap(data);

    Map<String, GamerPlayerStats> players =
        <String, GamerPlayerStats>{
      for (final MapEntry<String, dynamic> entry
          in rawPlayers.entries)
        entry.key: GamerFirestoreService._playerStatsFromMap(
          GamerFirestoreService._mapFromDynamic(entry.value),
          uid: entry.key,
          defaultName: 'Usuario',
        ),
    };

    // ------------------------------------------------------------------------
    // COMPATIBILIDAD CON ESTRUCTURA LEGACY
    // ------------------------------------------------------------------------
    //
    // Si el documento no tiene un mapa de jugadores individuales (formato
    // previo a la introducción de cuentas reales), los campos globales
    // representan al usuario actual.
    //
    // ------------------------------------------------------------------------

    if (players.isEmpty && currentUid.isNotEmpty) {
      players = <String, GamerPlayerStats>{
        currentUid: GamerFirestoreService._playerStatsFromMap(
          data,
          uid: currentUid,
          defaultName: 'Usuario',
        ),
      };
    }

    // ------------------------------------------------------------------------
    // TEAM — suma de todos los miembros, sea cual sea su número.
    // ------------------------------------------------------------------------

    final GamerPlayerStats team = GamerPlayerStats(
      uid: 'team',
      displayName: 'Team',
      gamerPoints: players.values.fold(
        0,
        (int sum, GamerPlayerStats p) => sum + p.gamerPoints,
      ),
      decisions: players.values.fold(
        0,
        (int sum, GamerPlayerStats p) => sum + p.decisions,
      ),
      streak: players.values.fold(
        0,
        (int sum, GamerPlayerStats p) => sum + p.streak,
      ),
      unlockedChallenges: players.values
          .expand((GamerPlayerStats p) => p.unlockedChallenges)
          .toSet()
          .toList(),
    );

    return GamerStats(
      players: players,
      team: team,
    );
  }
}

