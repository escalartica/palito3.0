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
  }) : _injectedFirestore = firestore,
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

  static int _parseInt(dynamic value, {int fallback = 0}) {
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
      final String cleanValue = value.replaceAll(RegExp(r'[^0-9-]'), '');

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

  static List<String> _parseStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }

    return <String>[];
  }

  // ==========================================================================
  // NORMALIZAR MAPA
  // ==========================================================================

  static Map<String, dynamic> _mapFromDynamic(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
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

  static Map<String, dynamic> _extractPlayersMap(Map<String, dynamic> data) {
    final dynamic rawUsers =
        data['users'] ?? data['players'] ?? data['comensales'];

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
      final Map<String, dynamic> playerData = _mapFromDynamic(entry.value);

      final String storedUid = playerData['uid']?.toString().trim() ?? '';

      if (storedUid == normalizedUid || entry.key.trim() == normalizedUid) {
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
      return GamerPlayerStats.empty(uid: uid, displayName: defaultName);
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
        data['decisions'] ?? data['totalDecisions'] ?? data['total_decisions'],
      ),
      streak: _parseInt(
        data['streak'] ?? data['decisions_streak'] ?? data['currentStreak'],
      ),
      medals: _parseInt(data['medals'] ?? data['totalMedals']),
      unlockedChallenges: _parseStringList(
        data['unlocked_challenges'] ?? data['unlockedChallenges'],
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
      return GamerPlayerStats.empty(uid: uid, displayName: defaultName);
    }

    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

    final Map<String, dynamic> players = _extractPlayersMap(data);

    final Map<String, dynamic>? playerData = _findPlayerByUid(players, uid);

    if (playerData != null) {
      return _playerStatsFromMap(
        playerData,
        uid: uid,
        defaultName: defaultName,
      );
    }

    return _playerStatsFromMap(data, uid: uid, defaultName: defaultName);
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

  /// Una lectura, una vez, del marcador del diario.
  ///
  /// La ruleta la necesita al abrirse: su tabla vive en el almacenamiento
  /// del móvil, y el almacenamiento del móvil no sabe nada de lo que se ha
  /// jugado en los otros. Sin esta lectura, entrar en la ruleta desde un
  /// segundo teléfono pisaba el marcador con los ceros de ese teléfono.
  /// El `stream` no sirve para eso: la carga necesita un valor ya, no una
  /// suscripción.
  Future<GamerStats?> fetchGamerStats() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;

    final DocumentReference<Map<String, dynamic>>? docRef =
        _mainStatsDocumentForUid(user.uid);
    if (docRef == null) return GamerStats.empty(currentUid: user.uid);

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();
    if (!snapshot.exists) return GamerStats.empty(currentUid: user.uid);

    return GamerStats.fromMainStats(
      snapshot.data() ?? <String, dynamic>{},
      currentUid: user.uid,
    );
  }

  Stream<GamerStats?> getGamerStatsStream() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream.value(null);
    }

    final DocumentReference<Map<String, dynamic>>? docRef =
        _mainStatsDocumentForUid(user.uid);

    if (docRef == null) {
      return Stream.value(GamerStats.empty(currentUid: user.uid));
    }

    return docRef.snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      if (!snapshot.exists) {
        return GamerStats.empty(currentUid: user.uid);
      }

      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};

      return GamerStats.fromMainStats(data, currentUid: user.uid);
    });
  }

  // ==========================================================================
  // STREAM DE ESTADÍSTICAS GAMER DE UN UID
  // ==========================================================================

  Stream<GamerPlayerStats?> getUserGamerStatsStream(String uid) {
    final String normalizedUid = _normalizeUid(uid);

    if (normalizedUid.isEmpty) {
      return Stream.value(null);
    }

    final DocumentReference<Map<String, dynamic>>? docRef =
        _mainStatsDocumentForUid(normalizedUid);

    if (docRef == null) {
      return Stream.value(
        GamerPlayerStats.empty(uid: normalizedUid, displayName: 'Usuario'),
      );
    }

    return docRef.snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      return _readPlayerFromDocument(
        snapshot,
        uid: normalizedUid,
        defaultName: 'Usuario',
      );
    });
  }

  // ==========================================================================
  // STREAM DEL PERFIL FIRESTORE
  // ==========================================================================

  Stream<Map<String, dynamic>?> getUserProfileStream(String uid) {
    final String normalizedUid = _normalizeUid(uid);

    if (normalizedUid.isEmpty || groupId == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection(_groupsCollection)
        .doc(groupId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
          if (!snapshot.exists) {
            return null;
          }

          return snapshot.data();
        });
  }
  // `updateGamerStats` VIVÍA AQUÍ Y SE HA BORRADO.
  //
  // No tenía ningún llamador, y era una copia exacta del fallo que
  // acabamos de arreglar: escribía `total_score` y `gamerPoints` en
  // absoluto, en la RAÍZ del documento —campos compartidos por todo el
  // diario— a partir de un marcador que el que llamara tuviera a mano.
  //
  // Código muerto que hace lo correcto se borra por limpieza. Código
  // muerto que hace algo peligroso se borra por seguridad: el día que
  // alguien busque "cómo guardo los puntos" y encuentre dos métodos,
  // va a elegir el de nombre más obvio. Ese era este.
  //
  // Lo que hay que usar es `updatePlayerStats`, que escribe dentro del
  // mapa `users` del jugador que toca y respeta lo que no se le manda.

  // `_findPlayerKeyByCurrentUser` SE HA IDO CON `updateGamerStats`.
  //
  // Emparejaba jugadores comparando el NOMBRE VISIBLE en minúsculas. Eso
  // es identidad frágil: dos personas que se llamen igual en el mismo
  // diario son el mismo jugador para esa función, y cambiarte el nombre en
  // Perfil te convertía en otro. Es la misma clase de fallo que ha costado
  // la sincronización de puntos de hoy.
  //
  // La identidad de un jugador es su uid. Para encontrar su fila está
  // `_findPlayerByUid`, que mira por clave del mapa O por el campo `uid`
  // guardado dentro.

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

  /// Guarda los puntos de un miembro en el marcador del grupo.
  ///
  /// [decisions] y [streak] son OPCIONALES a propósito. La mesa de La ruleta
  /// la lleva un móvil, y ese móvil conoce los puntos de todos los que están
  /// sentados —los va sumando él—, pero **no** cuántas decisiones ha tomado
  /// cada uno en sus propias partidas. Escribir ahí el contador de esta mesa
  /// le atribuiría a otra persona unas tiradas que no ha hecho, y encima
  /// pisaría las suyas.
  ///
  /// Así que quien lleva la mesa manda los puntos de todos y su propio
  /// contador de decisiones; el de los demás se queda como estaba.
  Future<void> updatePlayerStats({
    required String playerKey,
    required String uid,
    required int score,
    int? decisions,
    int? streak,
    int? medals,
    List<String>? unlockedChallenges,
    String? displayName,
  }) async {
    final String normalizedPlayerKey = playerKey.trim();

    final String normalizedUid = uid.trim();

    if (normalizedPlayerKey.isEmpty) {
      throw ArgumentError('playerKey no puede estar vacío.');
    }

    if (normalizedUid.isEmpty) {
      throw ArgumentError('uid no puede estar vacío.');
    }

    final DocumentReference<Map<String, dynamic>>? docRef =
        _mainStatsDocumentForUid(normalizedUid);

    if (docRef == null) {
      throw StateError('El usuario no pertenece a ningún grupo todavía.');
    }

    // Fuera de la transacción porque el registro de después la necesita:
    // saber en qué fila se acabó escribiendo es justo el dato que hace
    // falta cuando alguien se queje de que sus puntos no aparecen.
    String claveDeLaFila = normalizedPlayerKey;

    try {
      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(docRef);

        final Map<String, dynamic> currentData =
            snapshot.data() ?? <String, dynamic>{};

        final Map<String, dynamic> players = _extractPlayersMap(currentData);

        final Map<String, dynamic> updatedPlayers = Map<String, dynamic>.from(
          players,
        );

        // LA FILA DE ESTA PERSONA PUEDE NO ESTAR GUARDADA BAJO SU UID.
        //
        // La documentación de arriba lo dice: `playerKey` puede ser `eme`,
        // `ceh` o cualquier clave que ya exista. Si llega un uid y en el
        // marcador hay una fila vieja con ese uid dentro pero otra clave
        // fuera, escribir en `updatedPlayers[uid]` crea una SEGUNDA fila
        // de la misma persona — y `team` las suma las dos, con lo que a
        // partir de ahí sus puntos se cuentan por duplicado.
        claveDeLaFila = normalizedPlayerKey;
        if (!updatedPlayers.containsKey(claveDeLaFila)) {
          for (final MapEntry<String, dynamic> entry
              in updatedPlayers.entries) {
            final Map<String, dynamic> fila = _mapFromDynamic(entry.value);
            if ((fila['uid']?.toString().trim() ?? '') == normalizedUid) {
              claveDeLaFila = entry.key;
              break;
            }
          }
        }

        final Map<String, dynamic> previousPlayer = _mapFromDynamic(
          updatedPlayers[claveDeLaFila],
        );

        final Map<String, dynamic> updatedPlayer = <String, dynamic>{
          ...previousPlayer,
          'uid': normalizedUid,
          'displayName':
              displayName ?? previousPlayer['displayName'] ?? 'Usuario',
          'gamerPoints': score,
          // `?decisions` es la sintaxis de Dart para «si es nulo, esta
          // entrada no existe»: deja intacto lo que ya hubiera en
          // `previousPlayer` en vez de escribir un cero encima.
          'decisions': ?decisions,
          'streak': ?streak,
          // Las medallas sí las sabe quien lleva la mesa para todo el
          // mundo, igual que los puntos: se las ha ido dando él. Va con
          // `?` de todas formas, para que una llamada que no las mande no
          // las ponga a cero.
          'medals': ?medals,
          // MISMO MOTIVO QUE `decisions` Y `streak`, Y SE HABÍA QUEDADO
          // FUERA.
          //
          // Esto se escribía siempre, y quien lleva la mesa mandaba una
          // lista vacía para todos los demás: abrir La ruleta —sin llegar
          // siquiera a girar— borraba los logros desbloqueados del resto
          // de miembros del diario. Las reglas lo permiten, porque
          // cualquier miembro puede escribir cualquier fila del marcador.
          //
          // Ahora, si no se manda nada, lo que hubiera se queda.
          'unlocked_challenges': ?unlockedChallenges,
          'last_updated': FieldValue.serverTimestamp(),
        };

        updatedPlayers[claveDeLaFila] = updatedPlayer;

        transaction.set(docRef, <String, dynamic>{
          'users': updatedPlayers,
          'players': updatedPlayers,
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      _log(
        '✅ GamerFirestoreService: '
        'jugador actualizado: '
        '$claveDeLaFila',
      );
    } catch (e, stack) {
      _log(
        '❌ GamerFirestoreService: '
        'error actualizando jugador: '
        '$e',
      );

      _logStack(stackTrace: stack);

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
      _log(
        '⚠️ GamerFirestoreService: '
        'no hay usuario autenticado.',
      );

      return;
    }

    if (groupId == null) {
      _log(
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
          .add(<String, dynamic>{
            'winner_name': winnerName,
            'event_detail': eventDetail,
            'points_awarded': pointsAwarded,
            'timestamp': FieldValue.serverTimestamp(),
          });

      _log(
        '✅ GamerFirestoreService: '
        'evento Gamer registrado.',
      );
    } catch (e, stack) {
      _log(
        '❌ GamerFirestoreService: '
        'error al registrar evento de juego: '
        '$e',
      );

      _logStack(stackTrace: stack);

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

  /// Las medallas de los juicios picantes.
  ///
  /// Vivían solo en el móvil que llevaba la mesa: cambiabas de teléfono y
  /// desaparecían, y nadie más las veía nunca. Sube con los puntos, por la
  /// misma vía y con las mismas cautelas.
  final int medals;

  final List<String> unlockedChallenges;

  const GamerPlayerStats({
    required this.uid,
    required this.displayName,
    required this.gamerPoints,
    required this.decisions,
    required this.streak,
    this.medals = 0,
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
      medals: 0,
      unlockedChallenges: const <String>[],
    );
  }

  GamerPlayerStats copyWith({
    String? uid,
    String? displayName,
    int? gamerPoints,
    int? decisions,
    int? streak,
    int? medals,
    List<String>? unlockedChallenges,
  }) {
    return GamerPlayerStats(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      gamerPoints: gamerPoints ?? this.gamerPoints,
      decisions: decisions ?? this.decisions,
      streak: streak ?? this.streak,
      medals: medals ?? this.medals,
      unlockedChallenges: unlockedChallenges ?? this.unlockedChallenges,
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

  /// uid guardado DENTRO de una fila → clave del mapa donde vive esa fila.
  ///
  /// POR QUÉ HACE FALTA ESTE ÍNDICE.
  ///
  /// El comentario de arriba dice "indexadas por su uid", y no siempre es
  /// verdad: la documentación de `updatePlayerStats` dice que `playerKey`
  /// puede ser `eme`, `ceh` o cualquier clave que ya exista, y en diarios
  /// con historia las hay. `_findPlayerByUid` ya buscaba bien —por clave O
  /// por el campo `uid` de dentro—, pero `forUid` hacía `players[uid]` a
  /// secas.
  ///
  /// Consecuencia: con la fila guardada como `eme`, el Perfil leía 0
  /// mientras La ruleta seguía enseñando los puntos, y la siguiente
  /// escritura creaba una fila nueva con el uid al lado de la vieja, con
  /// lo que el total del equipo pasaba a contar a esa persona dos veces.
  /// Ese era el "tengo 5 puntos en el juego y 0 en el perfil".
  final Map<String, String> claveDelUid;

  const GamerStats({
    required this.players,
    required this.team,
    this.claveDelUid = const <String, String>{},
  });

  /// La clave bajo la que vive la fila de [uid], o null si no está.
  String? claveDe(String uid) {
    final String limpio = uid.trim();
    if (limpio.isEmpty) return null;
    if (players.containsKey(limpio)) return limpio;
    return claveDelUid[limpio];
  }

  /// ¿El marcador sabe algo de esta persona? No es lo mismo que "tiene 0".
  bool conoceA(String uid) => claveDe(uid) != null;

  /// Estadísticas del miembro `uid`, o un valor vacío si todavía no tiene
  /// ninguna entrada (p. ej. se acaba de unir al grupo).
  GamerPlayerStats forUid(String uid) {
    final String? clave = claveDe(uid);
    return clave == null
        ? GamerPlayerStats.empty(uid: uid)
        : players[clave] ?? GamerPlayerStats.empty(uid: uid);
  }

  factory GamerStats.empty({String currentUid = ''}) {
    return GamerStats(
      players: currentUid.isNotEmpty
          ? <String, GamerPlayerStats>{
              currentUid: GamerPlayerStats.empty(uid: currentUid),
            }
          : const <String, GamerPlayerStats>{},
      team: GamerPlayerStats.empty(uid: 'team', displayName: 'Team'),
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

    Map<String, GamerPlayerStats> players = <String, GamerPlayerStats>{
      for (final MapEntry<String, dynamic> entry in rawPlayers.entries)
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
      medals: players.values.fold(
        0,
        (int sum, GamerPlayerStats p) => sum + p.medals,
      ),
      unlockedChallenges: players.values
          .expand((GamerPlayerStats p) => p.unlockedChallenges)
          .toSet()
          .toList(),
    );

    final Map<String, String> claveDelUid = <String, String>{};
    for (final MapEntry<String, dynamic> entry in rawPlayers.entries) {
      final Map<String, dynamic> fila = GamerFirestoreService._mapFromDynamic(
        entry.value,
      );
      final String guardado = fila['uid']?.toString().trim() ?? '';
      if (guardado.isNotEmpty && guardado != entry.key) {
        claveDelUid[guardado] = entry.key;
      }
    }

    return GamerStats(players: players, team: team, claveDelUid: claveDelUid);
  }
}

// ===========================================================================
// LOGS
// ===========================================================================
//
// `debugPrint` NO se desactiva en una build de release: sigue escribiendo al
// log del sistema (Console.app en iOS, logcat en Android), donde lo puede leer
// cualquiera con el dispositivo delante o un informe de diagnóstico. Este
// archivo estaba volcando ahí identificadores de usuario, de grupo y datos de
// ubicación. Con este envoltorio, en release no se escribe nada.
void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

void _logStack({StackTrace? stackTrace}) {
  if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
}
