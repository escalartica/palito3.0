import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:palito_3_0/core/models/memory_model.dart';
import 'package:palito_3_0/core/providers/gamer_provider.dart';
import 'package:palito_3_0/core/providers/memory_provider.dart';
import 'package:palito_3_0/core/providers/household_provider.dart';
import 'package:palito_3_0/core/services/auth_service.dart';
import 'package:palito_3_0/core/utils/app_log.dart';
import 'package:palito_3_0/core/theme/components/app_dock.dart';
import 'package:palito_3_0/core/theme/components/neo_pressable.dart';
import '../gamer/zona_gamer_card.dart';
import 'data/gamer_content.dart';
import 'gamer_game_logic.dart';
import 'widgets/add_player_modal.dart';
import 'widgets/badges_modal.dart';
import 'widgets/how_to_play_sheet.dart';
import 'widgets/challenge_outcome_modal.dart';
import 'widgets/mode_selector.dart';
import 'widgets/pro_modal.dart';
import '../../core/services/gamer_firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/data/field_limits.dart';
import '../../core/theme/components/smart_image.dart';
import '../../core/theme/components/progress_track.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/theme/tokens/app_animation.dart';
import '../../core/theme/components/app_motion.dart';
import '../../core/theme/components/app_feedback.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EN LA APP SE LLAMA "LA RULETA"; AQUÍ DENTRO, "GAMER"
// ═══════════════════════════════════════════════════════════════════════════
//
// La pestaña se llamaba "Zona Gamer" y decía lo que la pantalla ES —una zona
// de juego— en vez de lo que HACE: echar a suertes quién elige la comida,
// para no discutirlo. Y "Gamer", que era lo único que cabía en el dock, no
// decía ninguna de las dos cosas.
//
// La CARPETA, las CLASES y los PROVIDERS conservan `gamer` a propósito:
// renombrarlos son cientos de líneas cambiadas, un riesgo de romper algo y
// cero beneficio para quien usa la app. Lo que ve el usuario dice "La
// ruleta"; lo que lee el programador dice `gamer`. Está anotado aquí para
// que nadie se pregunte si son dos cosas distintas.
//
// Los datos guardados en Firestore también siguen bajo `gamer`: cambiarlos
// dejaría sin puntos a quien ya juega.

// ─── Constantes ──────────────────────────────────────────────────────────────
const _kDark = AppColors.textPrimary;
const _kYellow = AppColors.primary;
const _kRed = AppColors.accent;
const _kBg = AppColors.background;

/// Colores de comensal, repartidos por turnos según el orden en que se
/// sientan. Deterministas a propósito: el mismo sitio en la mesa da siempre
/// el mismo color, y ninguno sale de la paleta de la app.
const List<Color> _kPlayerPalette = <Color>[
  AppColors.primary,
  AppColors.accent,
  AppColors.textPrimary,
  Color(0xFF1E7E45), // el verde de acierto
  Color(0xFF4E5765), // pizarra
];

// ════════════════════════════════════════════════════════════════════════════
// GamerPage
// ════════════════════════════════════════════════════════════════════════════
class GamerPage extends ConsumerStatefulWidget {
  const GamerPage({super.key});

  @override
  ConsumerState<GamerPage> createState() => _GamerPageState();
}

class _GamerPageState extends ConsumerState<GamerPage>
    with TickerProviderStateMixin {
  // 0: Ruleta Pro  |  1: Juicio Picante
  int _selectedMode = 0;

  // LA MESA EMPIEZA VACÍA.
  //
  // La versión publicada traía tres comensales inventados de fábrica —dos de
  // ellos, 'CeH' y 'Eme', los nombres de quienes desarrollaron la app—, así
  // que cualquier persona que se descargara Palito se encontraba a dos
  // desconocidos sentados a su mesa y un bot. Eso no es un detalle estético:
  // la primera impresión de la La ruleta era "esto no es mío".
  //
  // Ahora la lista nace vacía y `_loadPersistedData` siembra UNA sola fila,
  // la tuya, con tu nombre real y tu cuenta ya vinculada. A los demás los
  // añades tú, que es justo lo que ocurre en una mesa de verdad.
  List<Map<String, dynamic>> _players = <Map<String, dynamic>>[];

  final _nameController = TextEditingController();
  final _customChallengeController = TextEditingController();

  Map<String, dynamic>? _selectedWinner;
  bool _isSpinning = false;
  /// Qué comensal está encendido ahora mismo.
  ///
  /// Es un `ValueNotifier` y no un campo normal por una razón concreta: cada
  /// giro de la ruleta lo cambia **entre 22 y 32 veces seguidas**. Con un
  /// campo normal cada salto era un `setState`, y un `setState` aquí
  /// reconstruye la pantalla ENTERA de la ruleta: el panel de resultado, el
  /// podio, el historial, los logros, la tarjeta de introducción... dos mil
  /// líneas de widgets, treinta veces, mientras el dedo espera a ver quién
  /// sale. Era la causa del tirón que se nota al girar.
  ///
  /// Con el notificador, el único trozo que se vuelve a pintar es la fila de
  /// comensales, que es el único que cambia.
  final ValueNotifier<int> _highlightedIndex = ValueNotifier<int>(-1);
  // CERO. Estaba en 3.
  //
  // Era un valor de prueba que se quedó puesto, y `_loadPersistedData` solo
  // lo pisa si ya hay algo guardado en el móvil. O sea que cualquiera que se
  // bajaba la app y abría la La ruleta veía "3 decisiones" y "Racha 3" sin
  // haber jugado nada — y peor: `_checkAndUnlockAchievements` se llamaba con
  // ese 3, así que podía desbloquearle insignias que no se había ganado.
  int _decisionsCount = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _winnerScaleController;
  late Animation<double> _winnerScaleAnimation;

  /// Si ya se ha avisado en esta sesión de que los puntos no están llegando
  /// a la cuenta. Un aviso por sesión: repetirlo en cada tirada convierte una
  /// información útil en una molestia que se aprende a ignorar.
  bool _avisadoFalloDeSincronia = false;

  /// Cuándo cantó la ruleta por última vez.
  ///
  /// Solo sirve para una cosa: que el cartel de logro desbloqueado no se
  /// coma el instante en que sale el nombre. Ver `_checkAndUnlockAchievements`.
  DateTime? _revealedAt;

  /// Lo que se le deja al nombre antes de taparlo con nada.
  static const Duration _revealHold = Duration(milliseconds: 1600);

  final List<Map<String, String>> _history = [];
  final Map<String, int> _punishmentCounts = {};

  final List<Map<String, dynamic>> _achievements = buildGamerAchievements();

  final List<String> _palitoChallenges = buildPalitoChallenges();

  String? _currentChallenge;

  /// Lo que propone Palito cuando le toca a él.
  ///
  /// Un comensal llamado "Palito" es la propia app sentada a la mesa: cuando
  /// la ruleta le señala, en vez de mirar a nadie **elige el plato**. Hasta
  /// ahora ese comensal se podía añadir escribiendo el nombre a mano y la
  /// ruleta lo trataba como a cualquier otro: salía su nombre, y ahí acababa
  /// la gracia — la app anunciaba que le tocaba elegir a ella y no elegía
  /// nada.
  String? _palitoPick;

  /// La tarjeta de "qué es esto", cerrada a mano. No se guarda entre
  /// sesiones a propósito: si la cierras sin jugar y vuelves mañana sin
  /// haber jugado, sigues sin saber qué es esto.
  bool _introDismissed = false;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: AppAnimation.pulse,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: AppAnimation.inOut),
    );

    _winnerScaleController = AnimationController(
      vsync: this,
      duration: AppAnimation.slow,
    );
    _winnerScaleAnimation = CurvedAnimation(
      parent: _winnerScaleController,
      curve: AppAnimation.celebrate,
    );

    _loadPersistedData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customChallengeController.dispose();
    _pulseController.dispose();
    _winnerScaleController.dispose();
    _highlightedIndex.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UNA MESA POR DIARIO
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // LA APP LO PROMETÍA POR ESCRITO Y NO ERA VERDAD. La hoja de «Tus diarios»
  // dice, con estas palabras: «Cada diario guarda sus propios platos, su mapa
  // **y su ruleta**».
  //
  // La mesa se guardaba en `palito_players_data`, sin el diario en la clave:
  // **una sola mesa para todos**. Pero los puntos se escriben en
  // `groups/{diario}/gamer_stats`, uno por diario. Una mesa, N marcadores.
  //
  // Lo que se veía: juegas en un diario, cambias a otro, y el Perfil marca
  // cero — porque está leyendo otro marcador. Los puntos no se habían
  // perdido, estaban en el diario donde se ganaron. Y Juan y Pedro te seguían
  // a todas partes, incluido tu diario privado, donde no pintan nada.
  //
  // Peor todavía: lo que se sincroniza es el TOTAL acumulado, no lo que
  // acabas de ganar. Así que bastaba con girar una vez en el diario nuevo
  // para escribir ahí el total entero — los puntos se mudaban solos de un
  // diario a otro.
  static String _clavePartida(String base, String? groupId) =>
      groupId == null ? base : '${base}_$groupId';

  /// La mesa que había antes de que hubiera una por diario.
  ///
  /// No se borra: la adopta el primer diario que se abra, y se apunta cuál
  /// para que no la adopten todos. Quien tenga una partida a medias se la
  /// encuentra donde estaba en vez de perderla.
  static const String _clavePartidaHeredada = 'palito_players_data';
  static const String _claveDecisionesHeredada = 'palito_decisions_count';
  static const String _claveHerenciaReclamada = 'palito_mesa_heredada_de';

  /// El diario cuya mesa se está jugando ahora mismo.
  String? _diarioDeLaMesa;

  // ─── Persistencia ──────────────────────────────────────────────────────────
  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final String? groupId = ref.read(activeGroupIdProvider);
      _diarioDeLaMesa = groupId;

      final String clavePartida = _clavePartida(
        _clavePartidaHeredada,
        groupId,
      );
      final String claveDecisiones = _clavePartida(
        _claveDecisionesHeredada,
        groupId,
      );

      // ¿Hay que adoptar la mesa de antes? Solo si este diario no tiene la
      // suya todavía y nadie más se ha quedado con la heredada.
      String? claveHeredadaAUsar;
      if (prefs.getString(clavePartida) == null) {
        final String? reclamadaPor = prefs.getString(_claveHerenciaReclamada);
        if (reclamadaPor == null || reclamadaPor == (groupId ?? '')) {
          if (prefs.getString(_clavePartidaHeredada) != null) {
            claveHeredadaAUsar = _clavePartidaHeredada;
            await prefs.setString(_claveHerenciaReclamada, groupId ?? '');
          }
        }
      }

      final savedDecisions =
          prefs.getInt(claveDecisiones) ??
          (claveHeredadaAUsar != null
              ? prefs.getInt(_claveDecisionesHeredada)
              : null);
      setState(() => _decisionsCount = savedDecisions ?? 0);

      final savedPlayersJson =
          prefs.getString(clavePartida) ??
          (claveHeredadaAUsar == null
              ? null
              : prefs.getString(claveHeredadaAUsar));
      if (savedPlayersJson != null) {
        final decoded = jsonDecode(savedPlayersJson);
        if (decoded is List) {
          final restored = decoded
              .whereType<Map>()
              .map<Map<String, dynamic>>(
                (item) => {
                  'name': item['name']?.toString() ?? 'Comensal',
                  'icon': _getIconData(
                    item['iconCode'] is int ? item['iconCode'] as int : 0,
                  ),
                  'color': Color(
                    item['colorValue'] is int
                        ? item['colorValue'] as int
                        : 0xFF9E9E9E,
                  ),
                  'points': item['points'] is int ? item['points'] as int : 0,
                  'medals': item['medals'] is int ? item['medals'] as int : 0,
                  // uid del miembro del grupo al que está vinculada esta
                  // fila local — ver _toggleLinkedToMe. Null si nadie la
                  // ha vinculado todavía (bots, invitados, o un jugador
                  // que aún no ha marcado "Soy yo").
                  'uid': item['uid']?.toString(),
                },
              )
              .toList();
          if (restored.isNotEmpty) setState(() => _players = restored);
        }
      }

      // Primera vez en esta La ruleta: te sentamos a ti y a nadie más.
      if (_players.isEmpty) {
        final String? myName = ref.read(currentDisplayNameProvider);
        final String? uid = ref.read(gamerServiceProvider).currentUid;
        setState(() {
          _players = <Map<String, dynamic>>[
            <String, dynamic>{
              'name': (myName != null && myName.trim().isNotEmpty)
                  ? myName.trim()
                  : 'Tú',
              'icon': Icons.person_rounded,
              'color': _kYellow,
              'points': 0,
              'medals': 0,
              'uid': uid,
            },
          ];
        });
      }

      final maxPts = _players.fold<int>(
        0,
        (m, p) => (p['points'] as int? ?? 0) > m ? p['points'] as int : m,
      );
      _checkAndUnlockAchievements(maxPts, fromLoad: true);

      // Ninguna fila por defecto traía `uid`, y `_syncGamerStats` solo
      // sincroniza la fila vinculada: los puntos NUNCA llegaban a la cuenta
      // y el Perfil mostraba 0 indefinidamente. La única pista de que había
      // que vincular era un texto gris de 11 px que nadie leía.
      _autoLinkMyPlayer();

      // Y ahora los demás. Ver `_sentarALosDelDiario`: va DESPUÉS de
      // `_autoLinkMyPlayer` a propósito, para que tu fila de siempre se
      // reconozca como tuya antes de que nadie se plantee añadirte otra.
      _sentarALosDelDiario();

      // PRIMERO SE LEE EL MARCADOR DEL DIARIO, Y LUEGO SE ESCRIBE.
      //
      // Este orden arregla una pérdida de datos, no es una optimización.
      //
      // Aquí decía antes que se re-sincronizaba "para que Profile quede
      // alineado con los puntos locales reales". Eso es justo lo que
      // estaba mal: los puntos locales viven en el almacenamiento de ESTE
      // móvil, y `updatePlayerStats` escribe `gamerPoints` en absoluto, no
      // sumando. Así que abrir la ruleta en un segundo teléfono —o en el
      // mismo después de reinstalar, o de borrar los datos— sentaba a todo
      // el mundo con 0 puntos y acto seguido escribía esos ceros encima
      // del marcador de verdad. El diario entero se quedaba a cero, y el
      // Perfil, que lee Firestore, mostraba 0 mientras la ruleta del otro
      // móvil seguía enseñando los puntos de siempre. Era exactamente el
      // desajuste que se venía notando.
      //
      // Firestore es la verdad compartida; el almacenamiento del móvil
      // solo manda en los invitados, que no tienen cuenta y no existen en
      // ningún otro sitio.
      await _adoptarPuntosDelDiario();

      // Y ahora sí: guardar en el móvil y subir, con el marcador ya bueno.
      await _savePersistedData();
    } catch (e, st) {
      AppLog.e('Error cargando datos del Gamer', e, st);
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// QUIEN ESTÁ EN EL DIARIO, ESTÁ EN LA MESA
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// Eran dos listas de personas que no se conocían: el Perfil enseñaba a los
  /// miembros del diario —cuentas reales, con su foto y sus puntos— y La
  /// ruleta enseñaba comensales escritos a mano en un móvil. Podías tener a
  /// María en el diario y a Juan y Pedro en la mesa, y ninguno de los tres
  /// aparecía en el otro sitio.
  ///
  /// Ahora quien esté en el diario que tengas abierto se sienta solo, con su
  /// nombre y con su cuenta detrás, así que sus puntos llegan a su Perfil.
  ///
  /// LOS INVITADOS SE QUEDAN. Comer es con quien estés comiendo, y habrá
  /// gente en la mesa que no tenga la app ni quiera tenerla — que solo entra
  /// a que la ruleta le señale. Esos se siguen añadiendo a mano y viven solo
  /// en este móvil: juegan, suman y salen en el podio, pero no hay ninguna
  /// cuenta donde guardarles nada, y la app no se la inventa.
  ///
  /// En el diario personal no se sienta a nadie: ahí el único miembro eres
  /// tú, y ya tienes tu fila.
  void _sentarALosDelDiario() {
    final List<String> miembros = ref.read(activeGroupMembersProvider);
    if (miembros.length < 2) return;

    final Map<String, dynamic>? grupo = ref
        .read(activeGroupDocProvider)
        .valueOrNull;
    if (grupo == null) return;

    final Map<String, dynamic> perfiles =
        (grupo['memberProfiles'] as Map<dynamic, dynamic>?)
            ?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final Set<String> yaSentados = _players
        .map((Map<String, dynamic> p) => p['uid']?.toString())
        .whereType<String>()
        .toSet();

    final List<Map<String, dynamic>> nuevos = <Map<String, dynamic>>[];

    for (final String uid in miembros) {
      final Map<String, dynamic>? perfil =
          perfiles[uid] as Map<String, dynamic>?;
      final String nombre =
          (perfil?['displayName'] as String?)?.trim().isNotEmpty == true
          ? (perfil!['displayName'] as String).trim()
          : AuthService.unnamedMember;

      if (yaSentados.contains(uid)) {
        // Ya está en la mesa: solo se le refresca el nombre, por si se lo ha
        // cambiado desde la última partida. Sus puntos no se tocan.
        for (final Map<String, dynamic> p in _players) {
          if (p['uid'] == uid) p['name'] = nombre;
        }
        continue;
      }

      nuevos.add(<String, dynamic>{
        'name': nombre,
        'icon': Icons.person_rounded,
        'color':
            _kPlayerPalette[(_players.length + nuevos.length) %
                _kPlayerPalette.length],
        'points': 0,
        'medals': 0,
        'uid': uid,
      });
    }

    if (nuevos.isEmpty) {
      setState(() {});
      return;
    }

    setState(() => _players.addAll(nuevos));
    // A propósito NO se guarda aquí. Quien llama a esto es la carga, y la
    // carga todavía tiene que leer el marcador del diario antes de
    // escribir nada: guardar en este punto subiría los ceros con los que
    // se acaba de sentar a la gente. Ver `_adoptarPuntosDelDiario`.
  }

  /// Vincula automáticamente tu fila de la mesa la primera vez, para que tus
  /// puntos lleguen a tu cuenta sin que tengas que descubrir un gesto. Si ya
  /// hay una fila vinculada, no toca nada.
  /// Trae de Firestore los puntos de quien tiene cuenta.
  ///
  /// Solo toca las filas que EXISTEN en el marcador del diario. Si el
  /// servidor no sabe nada de alguien, lo local es lo único que hay de él
  /// —puntos ganados sin cobertura, por ejemplo— y no se pisa. Y si la
  /// lectura falla, no se toca nada: no saber es mejor que borrar.
  Future<void> _adoptarPuntosDelDiario() async {
    final GamerStats? marcador;
    try {
      marcador = await ref.read(gamerServiceProvider).fetchGamerStats();
    } catch (e, st) {
      AppLog.e('No se pudo leer el marcador del diario', e, st);
      return;
    }
    if (marcador == null || !mounted) return;

    bool cambio = false;
    for (final Map<String, dynamic> jugador in _players) {
      final String? suUid = jugador['uid']?.toString();
      if (suUid == null || suUid.isEmpty) continue;
      // `conoceA` y no `players.containsKey`: la fila puede estar
      // guardada bajo una clave que no es el uid. Ver `GamerStats`.
      if (!marcador.conoceA(suUid)) continue;

      final GamerPlayerStats suyas = marcador.forUid(suUid);

      // Si en la mesa figura como "Sin nombre" pero el marcador guarda uno
      // de verdad, gana el del marcador. Es la otra mitad del arreglo: no
      // basta con dejar de pisar el nombre bueno, hay que recuperarlo.
      final String enLaMesa = jugador['name']?.toString().trim() ?? '';
      final bool mesaSinNombre =
          enLaMesa.isEmpty || enLaMesa == AuthService.unnamedMember;
      final String fuera = suyas.displayName.trim();
      if (mesaSinNombre &&
          fuera.isNotEmpty &&
          fuera != AuthService.unnamedMember &&
          fuera != 'Usuario') {
        jugador['name'] = fuera;
        cambio = true;
      }
      if (jugador['points'] != suyas.gamerPoints) {
        jugador['points'] = suyas.gamerPoints;
        cambio = true;
      }
      // Las medallas viajan igual que los puntos desde que existen en el
      // servidor. Antes vivían solo en el móvil que llevaba la mesa:
      // cambiabas de teléfono y desaparecían.
      if (jugador['medals'] != suyas.medals) {
        jugador['medals'] = suyas.medals;
        cambio = true;
      }
    }

    // Y las decisiones propias, por lo mismo: el contador es local y una
    // reinstalación lo dejaba en 0 para luego escribir ese 0 en la cuenta.
    final String? miUid = ref.read(gamerServiceProvider).currentUid;
    if (miUid != null && marcador.conoceA(miUid)) {
      final int fuera = marcador.forUid(miUid).decisions;
      if (fuera > _decisionsCount) {
        _decisionsCount = fuera;
        cambio = true;
      }
    }

    if (cambio) setState(() {});
  }

  void _autoLinkMyPlayer() {
    final String? uid = ref.read(gamerServiceProvider).currentUid;
    if (uid == null) return;

    final bool alreadyLinked = _players.any(
      (Map<String, dynamic> p) => p['uid'] == uid,
    );
    if (alreadyLinked) return;

    final String? myName = ref.read(currentDisplayNameProvider);

    int index = _players.indexWhere((Map<String, dynamic> p) {
      final String name = p['name']?.toString() ?? '';
      return name == 'Tú' ||
          (myName != null && name.toLowerCase() == myName.toLowerCase());
    });

    if (index == -1) return;

    setState(() {
      _players[index]['uid'] = uid;
      if (myName != null && myName.isNotEmpty) {
        _players[index]['name'] = myName;
      }
    });
  }

  Future<void> _savePersistedData() async {
    final String? groupId = _diarioDeLaMesa;

    // SIN DIARIO RESUELTO NO SE GUARDA NADA.
    //
    // `_clavePartida(base, null)` devuelve la clave heredada, la misma que
    // guarda la mesa de quien viene de una versión anterior. Así que
    // guardar antes de que el diario se resuelva —cosa que pasa al arrancar
    // en frío, porque la carga se dispara en `initState`— escribía una mesa
    // recién sembrada encima de esa herencia. Y la herencia solo se puede
    // adoptar una vez: el diario de verdad se la encontraría ya pisada.
    //
    // Sincronizar tampoco tendría sentido: sin `groupId`,
    // `updatePlayerStats` lanza porque no hay documento al que escribir.
    //
    // No se pierde nada: en cuanto el diario resuelve, `_cambiarDeDiario`
    // recarga y a partir de ahí todo guardado tiene su sitio.
    if (groupId == null || groupId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _clavePartida(_claveDecisionesHeredada, groupId),
        _decisionsCount,
      );

      final serialized = _players.map((p) {
        final icon = p['icon'] is IconData
            ? p['icon'] as IconData
            : Icons.face_rounded;
        final color = p['color'] is Color
            ? p['color'] as Color
            : AppColors.textMuted;
        return {
          'name': p['name']?.toString() ?? 'Comensal',
          'iconCode': icon.codePoint,
          'colorValue': color.toARGB32(),
          'points': p['points'] is int ? p['points'] as int : 0,
          'medals': p['medals'] is int ? p['medals'] as int : 0,
          'uid': p['uid'],
        };
      }).toList();

      await prefs.setString(
        _clavePartida(_clavePartidaHeredada, groupId),
        jsonEncode(serialized),
      );
    } catch (e, st) {
      AppLog.e('Error guardando la partida en el dispositivo', e, st);
    }

    // FUERA del `try` de arriba, y a propósito.
    //
    // Guardar en el móvil y guardar en la cuenta son dos cosas distintas que
    // fallan por motivos distintos, y estaban en el mismo `try`: un fallo de
    // red hacía saltar el `catch` del guardado local, que ya había terminado
    // bien. Peor aún — ver `_syncGamerStats`.
    await _syncGamerStats();
  }

  /// El nombre que se puede escribir en el marcador, o `null`.
  ///
  /// Devuelve `null` cuando lo único que tenemos es el relleno "Sin
  /// nombre": eso no es un nombre, es la ausencia de uno, y escribirlo
  /// borra el que hubiera.
  static String? _nombreParaElMarcador(Map<String, dynamic> jugador) {
    final String nombre = jugador['name']?.toString().trim() ?? '';
    if (nombre.isEmpty) return null;
    if (nombre == AuthService.unnamedMember) return null;
    return nombre;
  }

  Future<void> _syncGamerStats() async {
    // ══ LOS LOGROS NO DEPENDEN DE LA RED, Y SE HABÍAN QUEDADO DETRÁS DE
    //    ELLA ══
    //
    // Esta llamada estaba AL FINAL de este método, después de la escritura a
    // Firestore. Un fallo de red —estar en un restaurante sin cobertura, que
    // es literalmente el sitio donde se usa esta pantalla— lanzaba antes de
    // llegar aquí, y entonces **dejaban de desbloquearse logros durante el
    // resto de la sesión**. Seguías jugando, seguías sumando puntos, y la
    // mitad divertida del juego estaba apagada sin que nada lo dijera.
    //
    // El progreso de los logros se calcula con lo que hay en la mesa: no
    // tiene nada que ver con el servidor. Va primero.
    final int maxPts = _players.fold<int>(
      0,
      (int m, Map<String, dynamic> p) =>
          (p['points'] as int? ?? 0) > m ? p['points'] as int : m,
    );
    if (!mounted) return;
    _checkAndUnlockAchievements(maxPts);

    // Esta función no puede lanzar: la llaman sitios que no la esperan
    // (`_addPlayer`, `_confirmRemovePlayer`…), y un `Future` suelto que
    // lanza es una excepción sin dueño en mitad de una partida. Resolver el
    // servicio toca `FirebaseAuth.instance`, que también puede quejarse.
    final GamerFirestoreService service;
    final String? uid;
    try {
      service = ref.read(gamerServiceProvider);
      uid = service.currentUid;
    } catch (e, st) {
      AppLog.e('No se pudo resolver la cuenta para sincronizar', e, st);
      return;
    }

    // ══ LOS PUNTOS DE CADA UNO VAN A SU CUENTA ══
    //
    // Antes esto sincronizaba UNA fila: la tuya. Los puntos de los demás
    // —aunque fueran miembros del diario, con su cuenta y su Perfil— se
    // quedaban en este móvil para siempre. En el Perfil, quien jugara
    // contigo salía a cero por muchas partidas que echarais.
    //
    // Ahora va la fila de cada comensal que tenga cuenta. Los INVITADOS no
    // tienen dónde ir y se quedan donde están, que es lo correcto: no hay
    // ninguna cuenta suya que actualizar, y la app no se la inventa.
    //
    // DOS COSAS SOBRE LO QUE SE ESCRIBE Y LO QUE NO:
    //
    //   · Las DECISIONES solo viajan con TU fila. Este móvil sabe los puntos
    //     de todos los que están sentados —los va sumando él—, pero no
    //     cuántas tiradas ha hecho cada uno en sus otras partidas. Escribir
    //     ahí el contador de esta mesa le atribuiría tiradas que no ha hecho
    //     y pisaría las suyas.
    //
    //   · Si dos personas llevan la mesa desde dos móviles a la vez, gana el
    //     último que gire. Sin un servidor que arbitre no hay forma de
    //     evitarlo, y además es lo que espera cualquiera de una mesa: la
    //     lleva quien tiene el móvil delante.
    if (uid != null) {
      for (final Map<String, dynamic> jugador in _players) {
        final String? suUid = jugador['uid']?.toString();
        if (suUid == null || suUid.isEmpty) continue;

        final bool soyYo = suUid == uid;

        try {
          await service.updatePlayerStats(
            playerKey: suUid,
            uid: suUid,
            score: jugador['points'] as int? ?? 0,
            decisions: soyYo ? _decisionsCount : null,
            medals: jugador['medals'] as int? ?? 0,
            // `streak` lleva el mismo número que `decisions` y no es una
            // racha. Se sigue escribiendo porque las versiones de la app
            // que ya están instaladas en otros móviles leen de ahí; el
            // Perfil de esta versión lee `decisions`, que es el campo que
            // dice la verdad. Cuando no queden versiones viejas por ahí,
            // esta línea se puede quitar.
            streak: soyYo ? _decisionsCount : null,
            // `null`, no una lista vacía: mandar `[]` por los demás les
            // borraba sus logros. Solo se escriben los propios.
            unlockedChallenges: soyYo ? _palitoChallenges : null,
            // `null` CUANDO NO SABEMOS CÓMO SE LLAMA, no "Sin nombre".
            //
            // Si el perfil de miembro del diario no trae `displayName`
            // —grupos creados antes de que ese campo existiera—, aquí
            // llegaba el literal "Sin nombre" y se escribía ENCIMA del
            // nombre bueno que sí había en el marcador. Y sin vuelta
            // atrás: nadie puede reescribir el nombre de otro desde la
            // app.
            //
            // Mandando `null`, `updatePlayerStats` conserva el que
            // hubiera. Vale más un nombre viejo que un "Sin nombre"
            // nuevo.
            displayName: _nombreParaElMarcador(jugador),
          );
        } catch (e, st) {
          // ══ DECIRLO, UNA VEZ ══
          //
          // Esto se tragaba en silencio. La partida seguía, los puntos
          // subían en pantalla… y no llegaban a ninguna cuenta: el Perfil
          // se quedaba a cero y quien jugaba concluía que el juego no
          // cuenta nada. Es justo el fallo que esta pantalla ya arregló una
          // vez por otro motivo (ver `_autoLinkMyPlayer`), y volvía a
          // ocurrir por la puerta de al lado.
          //
          // No se pierde nada: la partida está guardada en el móvil y la
          // siguiente sincronización que funcione manda el total, no la
          // diferencia. Lo que hacía falta era decirlo.
          AppLog.e('No se pudieron guardar los puntos en la cuenta', e, st);

          if (!mounted) return;
          // `continue`, no `return`: que falle la fila de uno no puede dejar
          // sin mandar las de los demás. Antes de haber varias filas esto
          // daba igual; ahora no.
          if (_avisadoFalloDeSincronia) continue;
          _avisadoFalloDeSincronia = true;

          // ── QUE EL AVISO DIGA LA VERDAD, TAMBIÉN ÉL ──
          //
          // La primera versión de este aviso —mía, de ayer— decía «no hay
          // conexión» pasara lo que pasara. Y hay un caso que no es la
          // conexión y que además es el más probable jugando en grupo:
          // `permission-denied` significa que ya no eres miembro de este
          // diario. Alguien te ha quitado, o se ha borrado.
          //
          // Mandar a mirar el wifi a quien acaban de sacar de un diario es
          // el mismo fallo que tenía el Mapa, y lo acabo de arreglar allí.
          // No tiene sentido arreglarlo en una pantalla y dejarlo en la de
          // al lado.
          final bool sinPermiso =
              e is FirebaseException && e.code == 'permission-denied';

          AppFeedback.warning(
            context,
            sinPermiso
                ? 'Ya no estás en este diario, así que los puntos se quedan '
                      'en este móvil. Cambia de diario desde tu perfil.'
                // «Los puntos de la mesa» y ya no «tus puntos»: desde que
                // se sincroniza la fila de cada comensal con cuenta, el que
                // falla puede no ser el tuyo.
                : 'Los puntos de la mesa se están guardando solo en este '
                      'móvil: no hay conexión con las cuentas. Se subirán '
                      'solos cuando vuelva.',
          );
        }
      }
    }
  }

  /// Recalcula el progreso de los logros con el estado actual de la mesa.
  ///
  /// Hace falta porque hay logros que no dependen de girar —"Mesa llena"
  /// depende de cuánta gente hay sentada— y el progreso solo se recalculaba
  /// al arrancar y después de cada tirada. Sin esto, sentabas al quinto
  /// comensal y la tira seguía diciendo "te faltan 2" hasta la siguiente
  /// vuelta de ruleta.
  void _refreshAchievements() {
    final int maxPts = _players.fold<int>(
      0,
      (int m, Map<String, dynamic> p) =>
          (p['points'] as int? ?? 0) > m ? p['points'] as int : m,
    );
    _checkAndUnlockAchievements(maxPts);
  }

  /// El logro bloqueado que está más cerca de caer.
  ///
  /// "Más cerca" es el porcentaje de progreso, no cuántas unidades faltan:
  /// estar a 1 de 25 decisiones no es estar cerca, y estar a 1 de 2 sí.
  Map<String, dynamic>? get _nextAchievement {
    Map<String, dynamic>? best;
    double bestRatio = -1;

    for (final Map<String, dynamic> a in _achievements) {
      if (a['unlocked'] == true) continue;

      final int goal = a['goal'] as int? ?? 0;
      if (goal <= 0) continue;

      final double ratio = ((a['progress'] as int? ?? 0) / goal).clamp(0.0, 1.0);
      if (ratio > bestRatio) {
        bestRatio = ratio;
        best = a;
      }
    }

    return best;
  }

  // ─── Palito, el comensal que es la app ──────────────────────────────────────

  /// Si este comensal es la propia app.
  ///
  /// Se marca con `isBot` al añadirlo, pero también se reconoce por el
  /// nombre: quien ya se había inventado el truco escribiendo "Palito" o
  /// "Palito App" a mano —que es exactamente de donde salió esta idea— se
  /// encuentra con que ahora funciona, sin tener que borrar y volver a
  /// añadir.
  static bool _isPalito(Map<String, dynamic> player) {
    if (player['isBot'] == true) return true;

    final String name = (player['name']?.toString() ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');

    return name == 'palito' || name == 'palitoapp';
  }

  /// El plato que propone Palito, sacado del diario que tenéis abierto.
  ///
  /// No es aleatorio del todo: tira primero de los platos que puntuasteis
  /// con un 3,5 o más y a los que dijisteis que volveríais. Proponer a
  /// ciegas el sitio que os pareció regular sería un chiste que se gasta a
  /// la primera; proponer uno de los buenos es una recomendación de verdad,
  /// hecha con lo que vosotros mismos habéis escrito.
  String? _palitoSuggestion() {
    final List<MemoryModel> memories = ref.read(memoryProvider);
    if (memories.isEmpty) return null;

    final List<MemoryModel> favourites = memories
        .where((MemoryModel m) => m.rating >= 3.5 && m.wouldReturn)
        .toList();

    final List<MemoryModel> pool = favourites.isEmpty ? memories : favourites;
    final MemoryModel pick = pool[Random().nextInt(pool.length)];

    final String dish = pick.title.trim();
    final String place = pick.restaurantName.trim();

    if (place.isEmpty) return dish.isEmpty ? null : dish;
    if (dish.isEmpty || dish.toLowerCase() == place.toLowerCase()) return place;

    return '$dish · $place';
  }

  // ─── Logros ─────────────────────────────────────────────────────────────────
  /// El segundo parámetro era `int streak` y las dos llamadas le pasaban
  /// `_decisionsCount`: no había ninguna racha, era el total de decisiones
  /// con otro nombre. Se quita en vez de dejar un parámetro que promete un
  /// dato que la app no tiene.
  void _checkAndUnlockAchievements(int maxPoints, {bool fromLoad = false}) {
    final newlyUnlocked = <Map<String, dynamic>>[];

    // Señales de la mesa, calculadas una sola vez para los siete logros.
    final int playerCount = _players.length;
    final int playersWithPoints = _players
        .where((Map<String, dynamic> p) => (p['points'] as int? ?? 0) > 0)
        .length;
    final int maxMedals = _players.fold<int>(
      0,
      (int m, Map<String, dynamic> p) =>
          (p['medals'] as int? ?? 0) > m ? p['medals'] as int : m,
    );

    for (final a in _achievements) {
      final String id = a['id']?.toString() ?? '';

      final progress = GamerGameLogic.achievementProgress(
        achievementId: id,
        maxPoints: maxPoints,
        decisionsCount: _decisionsCount,
        playerCount: playerCount,
        playersWithPoints: playersWithPoints,
        maxMedals: maxMedals,
      );

      // El progreso se guarda siempre, conseguido o no: es lo que el panel
      // de insignias enseña debajo de cada logro bloqueado ("9 de 10") para
      // que se vea lo cerca que está.
      a['progress'] = progress.current;
      a['goal'] = progress.goal;

      if (a['unlocked'] == true) continue;

      if (progress.goal > 0 && progress.current >= progress.goal) {
        a['unlocked'] = true;
        if (!fromLoad) newlyUnlocked.add(a);
      }
    }

    if (!mounted || newlyUnlocked.isEmpty) return;
    final Map<String, dynamic> a = newlyUnlocked.first;

    // ══ EL LOGRO NO PUEDE PISAR EL NOMBRE QUE ACABA DE SALIR ══
    //
    // Girabas la ruleta, frenaba, cantaba un nombre… y en el mismo
    // fotograma le caía encima un cartel a pantalla completa con su fondo
    // oscuro. La primera vez que alguien juega —que es justo cuando salta
    // "Se abre la veda"— **no llega a ver quién ha salido**: ve el cartel,
    // lo cierra, y se encuentra un nombre que no ha visto aparecer.
    //
    // El logro es una celebración y se queda; lo que no puede es llegar
    // antes que aquello que se está celebrando. Espera a que el nombre haya
    // estado solo en pantalla el tiempo de leerlo.
    //
    // Fuera del giro —sentar a alguien a la mesa, por ejemplo— no hay nada
    // que proteger y sale al momento: la resta se vuelve negativa sola.
    final DateTime? revealed = _revealedAt;
    final Duration espera = revealed == null
        ? Duration.zero
        : _revealHold - DateTime.now().difference(revealed);

    void present() {
      if (!mounted) return;
      _showAchievementUnlockedDialog(
        a['title'] as String,
        a['desc'] as String,
        a['icon'] as IconData,
        a['color'] as Color,
      );
    }

    if (espera <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => present());
    } else {
      Future<void>.delayed(espera, present);
    }
  }

  void _showAchievementUnlockedDialog(
    String title,
    String desc,
    IconData icon,
    Color color,
  ) {
    // showGeneralDialog en vez de showDialog: el logro es el momento de
    // mayor carga emocional de la app (raro, "delight" en el sentido de
    // apple-design), así que se le da una entrada propia con rebote —a
    // diferencia del fade+scale genérico de Material— en vez de reusar
    // el mismo AppAnimation.pop ya usado en el resto de la UI para
    // mantener coherencia de vocabulario.
    showGeneralDialog(
      context: context,
      barrierLabel: 'Logro desbloqueado',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: AppAnimation.slow,
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        // reverseCurve sin rebote: el rebote solo tiene sentido
        // "llegando" (el logro apareciendo), no "yéndose" — reproducir
        // el mismo easeOutBack al revés se ve como si el diálogo se
        // desinflara de forma rara.
        final curved = CurvedAnimation(
          parent: animation,
          // `celebrate` existe exactamente para esto y no se estaba usando
          // en ningún sitio: se pasa de largo un 45 % y vuelve, una sola
          // vez. `pop` (14 %) es el rebote de un chip.
          curve: AppAnimation.celebrate,
          reverseCurve: AppAnimation.exit,
        );
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: curved.value, child: child),
        );
      },
      pageBuilder: (ctx, animation, secondaryAnimation) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: _kDark, width: 2.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Navy sobre el color del logro, nunca blanco.
            //
            // El icono iba en blanco y el título en el color del logro. Con
            // los colores viejos de Material colaba de milagro; desde que
            // los logros usan la paleta de la marca, un logro amarillo
            // pintaba un icono blanco sobre amarillo (1,4:1) y un título
            // amarillo sobre blanco (1,6:1). El momento más celebrado de la
            // app enseñaba un premio que no se leía.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: _kDark, width: 2),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: _kDark, offset: Offset(3, 3), blurRadius: 0),
                ],
              ),
              child: Icon(icon, size: 40, color: _kDark),
            ),
            const SizedBox(height: 18),
            Text(
              'LOGRO DESBLOQUEADO',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.15,
                letterSpacing: -0.4,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  // Amarillo de marca con texto navy (12,47:1), no el color
                  // del logro con texto blanco: ese blanco sobre amarillo
                  // medía 1,4:1.
                  backgroundColor: AppColors.primary,
                  foregroundColor: _kDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    side: const BorderSide(color: _kDark, width: 2),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  '¡Genial!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Iconos ─────────────────────────────────────────────────────────────────
  IconData _getIconData(int code) => switch (code) {
    0xe491 => Icons.person_rounded,
    0xe25d => Icons.favorite_rounded,
    0xf04e9 => Icons.smart_toy_rounded,
    0xe5f9 => Icons.star_rounded,
    0xe3a7 => Icons.local_fire_department_rounded,
    0xe0e9 => Icons.bolt_rounded,
    _ => Icons.face_rounded,
  };

  // ─── Jugadores ──────────────────────────────────────────────────────────────
  /// Sienta a la app a la mesa como un comensal más.
  ///
  /// CIERRA LA HOJA CON EL CONTEXTO DE LA HOJA, NO CON EL DE LA PÁGINA.
  /// Las hojas de esta pantalla se abren con `useRootNavigator: true` para
  /// que no las tape el dock. Eso significa que viven en el navegador RAÍZ,
  /// mientras que el `context` del `State` cuelga del navegador del shell
  /// —el de las cuatro pestañas—. Un `Navigator.pop(context)` desde aquí no
  /// cerraba la hoja: desapilaba la pantalla entera, y la app se quedaba en
  /// negro justo al añadir un comensal.
  void _addPalito(BuildContext sheetContext) {
    if (_players.any(_isPalito)) return;

    setState(() {
      _players.add(<String, dynamic>{
        'name': 'Palito',
        'icon': Icons.restaurant_rounded,
        'color': AppColors.textPrimary,
        'points': 0,
        'medals': 0,
        'uid': null,
        'isBot': true,
      });
    });

    _refreshAchievements();
    Navigator.pop(sheetContext);
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar('Palito se sienta con vosotros');
    _savePersistedData();
  }

  /// Ver la nota de `_addPalito`: el `sheetContext` es obligatorio a
  /// propósito, para que no se pueda volver a cerrar la hoja equivocada.
  void _addPlayer(BuildContext sheetContext) {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _players.add({
        'name': text,
        'icon': Icons.face_rounded,
        // Antes: `Colors.primaries[Random().nextInt(...)]`. Un color de
        // Material al azar —lima, cian, índigo— en una app que es navy,
        // amarillo y coral, y distinto cada vez que se añadía a la misma
        // persona. Ahora se reparte por turnos de una paleta corta y
        // propia, así que dos comensales nunca coinciden hasta el quinto.
        'color': _kPlayerPalette[_players.length % _kPlayerPalette.length],
        'points': 0,
        'medals': 0,
        'uid': null,
      });
      _nameController.clear();
    });

    _refreshAchievements();
    Navigator.pop(sheetContext);
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar('¡$text añadido a la mesa!');
    _savePersistedData();
  }

  /// Confirma antes de quitar a alguien de la mesa. La pulsación larga
  /// borraba al instante, sin diálogo, sin deshacer y sin que en ninguna
  /// parte se dijera que ese gesto existía.
  Future<void> _confirmRemovePlayer(int index) async {
    if (index < 0 || index >= _players.length) return;
    if (_players.length <= 1) {
      _showFeedbackSnackbar('Debe quedar al menos un comensal');
      return;
    }

    final String name = _players[index]['name']?.toString() ?? 'Comensal';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('¿Quitar a $name de la mesa?'),
        content: const Text(
          'Sus puntos de esta sesión se pierden. Puedes volver a añadirlo '
          'cuando quieras.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _removePlayer(index);
  }

  void _removePlayer(int index) {
    if (index < 0 || index >= _players.length) return;
    if (_players.length <= 1) {
      _showFeedbackSnackbar('Debe quedar al menos un comensal');
      return;
    }
    final removedName = _players[index]['name']?.toString() ?? 'Comensal';
    setState(() {
      _players.removeAt(index);
      if (_highlightedIndex.value >= _players.length) {
        _highlightedIndex.value = _players.isEmpty
            ? -1
            : _players.length - 1;
      }
      if (_selectedWinner != null && _selectedWinner!['name'] == removedName) {
        _selectedWinner = null;
      }
    });
    _refreshAchievements();
    _savePersistedData();
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar('Comensal $removedName eliminado');
  }

  /// Vincula (o desvincula, si ya lo estaba) la fila [index] de la mesa
  /// local al uid del usuario que ha iniciado sesión en este dispositivo.
  /// Solo puede haber una fila vinculada a la vez por dispositivo — vincular
  /// otra desvincula automáticamente la anterior. Ver el comentario de
  /// _syncGamerStats: solo la fila vinculada llega a guardarse en la cuenta
  /// de alguien; el resto son invitados/bots puramente locales de la mesa.
  void _toggleLinkedToMe(int index) {
    final uid = ref.read(gamerServiceProvider).currentUid;
    if (uid == null) return;

    final name = _players[index]['name']?.toString() ?? 'Comensal';
    final String? suUid = _players[index]['uid']?.toString();
    final wasLinked = suUid == uid;

    // ── LA FILA DE OTRA PERSONA NO SE TOCA ──
    //
    // Esto borraba el uid de TODAS las filas y ponía el tuyo en la que
    // tocaras. Daba igual mientras la única fila con cuenta podía ser la
    // tuya; desde que los miembros del diario se sientan solos, un toque en
    // la ficha de otra persona le quitaría su cuenta —y sus puntos dejarían
    // de llegarle— sin que nadie lo pidiera.
    //
    // Solo se puede vincular una ficha de INVITADO, que es la que no tiene
    // dueño.
    if (suUid != null && suUid.isNotEmpty && !wasLinked) {
      _showFeedbackSnackbar('«$name» ya está en el diario con su cuenta');
      return;
    }

    setState(() {
      // Solo se limpian las filas que sean TUYAS: las de los demás miembros
      // se quedan como están.
      for (final player in _players) {
        if (player['uid'] == uid) player['uid'] = null;
      }
      if (!wasLinked) {
        _players[index]['uid'] = uid;
      }
    });

    _savePersistedData();
    HapticFeedback.selectionClick();
    _showFeedbackSnackbar(
      wasLinked
          ? 'Ya no vinculas tus puntos a "$name"'
          : 'Tus puntos ahora se guardan como "$name"',
    );
  }

  // ─── Sesión ──────────────────────────────────────────────────────────────────
  void _resetSessionScores() {
    setState(() {
      for (final p in _players) {
        p['points'] = 0;
        p['medals'] = 0;
      }
      _history.clear();
      _punishmentCounts.clear();
      _decisionsCount = 0;
      _selectedWinner = null;
      _currentChallenge = null;
      _palitoPick = null;
      _highlightedIndex.value = -1;
      // Los logros NO se vuelven a bloquear: un logro conseguido no debería
      // perderse al reiniciar la puntuación de una sesión de juego.
    });
    _savePersistedData();
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar('🔄 Puntuaciones de la sesión reiniciadas');
  }

  void _clearHistory() {
    if (_history.isEmpty && _punishmentCounts.isEmpty) return;
    setState(() {
      _history.clear();
      _punishmentCounts.clear();
    });
    _savePersistedData();
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar('Historial de sesión borrado');
  }

  void _showFeedbackSnackbar(String message) {
    if (!mounted) return;
    AppFeedback.success(context, message);
  }

  // ─── Resultado del reto ──────────────────────────────────────────────────────
  void _resolveChallengeResult(String playerName, bool succeeded) {
    if (!mounted || _players.isEmpty) return;
    final idx = _players.indexWhere((p) => p['name'] == playerName);
    if (idx == -1) return;

    final player = _players[idx];
    setState(() {
      if (succeeded) {
        // OJO AL CAMBIAR ESTAS CIFRAS. Los 15 puntos y la medalla de aquí
        // están escritos en palabras en la hoja de "Cómo se juega"
        // (`widgets/how_to_play_sheet.dart`) y en la línea del historial de
        // tres líneas más abajo. Si cambian aquí y no allí, la pantalla que
        // explica las reglas pasa a mentir.
        //
        // El aviso gemelo está en `gamer_game_logic.dart`, que es donde
        // viven los 5 y los 10 del giro. Las cifras del juicio picante están
        // repartidas entre los dos ficheros: al girar se dan 10 puntos y una
        // medalla, y estos 15 y esta segunda medalla son SOLO por cumplir el
        // reto.
        player['points'] = (player['points'] ?? 0) + 15;
        player['medals'] = (player['medals'] ?? 0) + 1;
        _history.insert(0, {
          'winner': playerName,
          // En español solo va en mayúscula la primera palabra. "Reto
          // Superado" y "Reto Fallido" son mayúsculas a la inglesa: en un
          // registro que se lee en español se leen como un error.
          'detail': '✅ ¡Reto superado! +15 puntos y otra medalla',
          'time': TimeOfDay.now().format(context),
        });
      } else {
        _history.insert(0, {
          'winner': playerName,
          'detail': '❌ Reto no superado',
          'time': TimeOfDay.now().format(context),
        });
      }
      if (_history.length > 5) _history.removeLast();
    });

    _savePersistedData();
    HapticFeedback.mediumImpact();
    _showFeedbackSnackbar(
      succeeded
          ? '🎉 ¡+15 puntos para $playerName!'
          : '❌ Reto no superado por $playerName',
    );
  }

  // ─── Diálogos / Modales ──────────────────────────────────────────────────────
  void _showChallengeOutcomeDialog(String playerName, String challengeText) {
    showModalBottomSheet(
      context: context,
      // Sobre TODO, incluido el dock. Sin esto la hoja se abre dentro
      // del navegador del shell, y el dock —que vive en un Stack por
      // encima— le pasa por delante y le tapa el botón de confirmar.
      // Pasaba en el modal de añadir comensal: el botón "Añadir a la
      // Mesa" quedaba detrás de la barra de pestañas.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChallengeOutcomeModal(
        playerName: playerName,
        challengeText: challengeText,
        onOutcome: (succeeded) =>
            _resolveChallengeResult(playerName, succeeded),
      ),
    );
  }

  void _showAddChallengeDialog() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Añadir un juicio picante',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _kDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customChallengeController,
              autofocus: true,
              // Un reto se lee en voz alta en la mesa. Ciento veinte
              // caracteres son dos frases; más que eso no es un reto, es un
              // texto — y el panel donde se pinta mide media tarjeta.
              maxLength: FieldLimits.retoPicante,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ej: Pagar la cuenta o hacer un baile…',
                hintStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceWarm,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () {
                  final text = _customChallengeController.text.trim();
                  if (text.isEmpty) return;
                  final challenge = '🔥 $text';
                  setState(() {
                    _palitoChallenges.add(challenge);
                    _currentChallenge = challenge;
                  });
                  _customChallengeController.clear();
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  _showFeedbackSnackbar('Juicio picante añadido con éxito');
                  _savePersistedData();
                },
                child: Text(
                  'Guardar y Aplicar Juicio',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showBadgesModal() {
    final sorted = List<Map<String, dynamic>>.from(_players)
      ..sort(
        (a, b) =>
            (b['points'] as int? ?? 0).compareTo(a['points'] as int? ?? 0),
      );

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          BadgesModal(players: sorted, achievements: _achievements),
    );
  }

  void _showZonaGamerProModal() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProModal(
        players: _players,
        decisionsCount: _decisionsCount,
        history: _history,
        onViewBadges: _showBadgesModal,
        onResetSession: _confirmResetSession,
        onClearHistory: _clearHistory,
      ),
    );
  }

  /// Reiniciar la sesión borraba puntos, medallas e historial al instante,
  /// sin confirmación y sin forma de deshacerlo.
  Future<void> _confirmResetSession() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('¿Reiniciar la sesión?'),
        content: const Text(
          'Se ponen a cero los puntos, las medallas y el historial de esta '
          'mesa. Los logros conseguidos se mantienen. No se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _resetSessionScores();
  }

  void _showAddPlayerDialog() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          AddPlayerModal(
            controller: _nameController,
            onAdd: () => _addPlayer(ctx),
            onAddPalito: () => _addPalito(ctx),
            palitoAlreadyPlaying: _players.any(_isPalito),
          ),
    );
  }

  // ─── Ruleta ──────────────────────────────────────────────────────────────────
  void _spinGame() {
    if (_isSpinning || !mounted) return;

    // Una ruleta con un solo comensal siempre sale tú. Antes el botón se
    // pulsaba igual y "elegía" al único que había, que es una forma tonta de
    // no hacer nada. Ahora dice qué falta.
    if (_players.length < 2) {
      AppFeedback.warning(
        context,
        'Añade a quien esté contigo en la mesa para poder jugar.',
        actionLabel: 'Añadir',
        onAction: _showAddPlayerDialog,
      );
      return;
    }

    setState(() {
      _isSpinning = true;
      _selectedWinner = null;
      _currentChallenge = null;
      _palitoPick = null;
    });
    // El pulso solo mientras gira — y solo si el sistema no pide reducir el
    // movimiento. Un latido que no para nunca es de lo que peor sienta a
    // quien tiene vértigo o migraña, y es justo lo que esa opción del sistema
    // existe para evitar.
    if (!MediaQuery.disableAnimationsOf(context)) {
      _pulseController.repeat(reverse: true);
    }
    HapticFeedback.heavyImpact();

    final random = Random();
    final totalSteps = 22 + random.nextInt(10);

    Future<void> runSpin() async {
      try {
        for (int step = 0; step <= totalSteps; step++) {
          if (!mounted || _players.isEmpty) return;
          // Sin `setState`: el notificador avisa al escenario y a la fila de
          // comensales. Ver el comentario de `_highlightedIndex`.
          _highlightedIndex.value =
              (_highlightedIndex.value + 1) % _players.length;

          final int delayMs = 35 + (pow(step, 1.35) * 3).toInt();

          // ── UN TIC POR SALTO NO ES UN TIC: ES UN ZUMBIDO ──
          //
          // Los primeros saltos van a 35 ms. Treinta golpecitos seguidos a
          // esa velocidad no se sienten como una ruleta chasqueando, se
          // sienten como el móvil vibrando. La ruleta solo chasquea cuando
          // ya se puede distinguir un salto del siguiente —y eso es justo
          // cuando empieza a frenar, que es el momento en el que el tacto
          // aporta algo: dice que se está parando.
          if (step == 0 || delayMs >= 70) {
            HapticFeedback.selectionClick();
          }

          if (step < totalSteps) {
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        }

        if (!mounted || _players.isEmpty) return;

        final winnerIndex = _highlightedIndex.value % _players.length;
        final winner = _players[winnerIndex];
        final winnerName = winner['name']?.toString() ?? 'Comensal';
        int pointsWon = 0;
        String? eventDetail;

        setState(() {
          _isSpinning = false;
          _selectedWinner = winner;
          _decisionsCount++;

          // Si le toca a la app, la app elige.
          _palitoPick = (_selectedMode == 0 && _isPalito(winner))
              ? _palitoSuggestion()
              : null;

          final outcome = GamerGameLogic.computeSpinOutcome(
            selectedMode: _selectedMode,
            challenges: _palitoChallenges,
            random: random,
          );

          pointsWon = outcome.pointsAwarded;
          eventDetail = outcome.eventDetail;
          winner['points'] = (winner['points'] ?? 0) + pointsWon;

          if (outcome.awardsMedal) {
            winner['medals'] = (winner['medals'] ?? 0) + 1;
            _punishmentCounts[winnerName] =
                (_punishmentCounts[winnerName] ?? 0) + 1;
          }

          if (outcome.challenge != null) {
            _currentChallenge = outcome.challenge;
          }

          _history.insert(0, {
            'winner': winnerName,
            'detail': outcome.historyDetail,
            'time': TimeOfDay.now().format(context),
          });

          if (_history.length > 5) _history.removeLast();
        });

        _pulseController.stop();

        // Arrancar la animación AQUÍ, en el mismo turno que el setState que
        // hace visible el panel. Antes se llamaba después de `await
        // _savePersistedData()` y de una escritura de red: como
        // `Transform.scale` no colapsa el layout, el panel dejaba de pintarse
        // pero seguía ocupando su sitio — el hueco vertical enorme de Zona
        // Gamer.
        _winnerScaleController.forward(from: 0.0);
        _revealedAt = DateTime.now();
        // `vibrate()` en iOS es el zumbido largo del sistema —el de una
        // alarma—, no una respuesta a un gesto. El remate de la ruleta es
        // un golpe seco.
        HapticFeedback.heavyImpact();

        _showFeedbackSnackbar(
          _selectedMode == 0
              ? 'A $winnerName le toca elegir plato'
              : '🔥 ¡Juicio picante para $winnerName!',
        );

        await _savePersistedData();
        if (!mounted) return;

        try {
          await ref
              .read(gamerServiceProvider)
              .logGameSessionEvent(
                winnerName: winnerName,
                eventDetail: eventDetail ?? 'Evento Gamer',
                pointsAwarded: pointsWon,
              );
        } catch (e, st) {
          AppLog.e('Error sincronizando evento de ruleta', e, st);
        }
      } catch (e, st) {
        AppLog.e('Error durante el giro de la ruleta', e, st);
        if (!mounted) return;
        _pulseController.stop();
        setState(() {
          _isSpinning = false;
          _selectedWinner = null;
          _currentChallenge = null;
          _palitoPick = null;
        });
        _showFeedbackSnackbar(
          '⚠️ No se pudo completar el giro. Inténtalo de nuevo.',
        );
      }
    }

    runSpin();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LA MESA
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // POR QUÉ ESTA PANTALLA SE REESCRIBE ENTERA Y NO SE RETOCA.
  //
  // La ruleta llevaba NUEVE bloques apilados en una sola columna, y los
  // nueve con el mismo borde navy y la misma sombra maciza: dos botones
  // enmarcados y una pastilla amarilla en la barra de título, la tarjeta de
  // introducción, el selector de modo, el panel de la partida, el botón de
  // girar, la tira del logro, la fila de comensales, el resumen, el
  // historial y un botón suelto al final.
  //
  // Ninguno estaba mal por separado. Se han pulido uno a uno, tres veces, y
  // la pantalla seguía leyéndose como una lista de cajas. **Ese era el
  // fallo**: cuando todo pesa lo mismo, nada manda, y una pantalla sin
  // jerarquía se lee como "sin terminar" por muy limpia que esté cada caja.
  // No se arregla con bordes más finos ni con menos amarillo; se arregla
  // decidiendo qué es lo importante y dejando que lo demás retroceda.
  //
  // EL CRITERIO, uno solo, y todos los valores de abajo salen de él:
  // **La ruleta es una mesa a la que te sientas, no una página que
  // recorres.**
  //
  // De ahí:
  //
  //   · UN SOLO PROTAGONISTA. Las pestañas de modo, el escenario, los
  //     comensales y el botón de girar eran cuatro objetos apilados que
  //     competían entre ellos; son partes de la misma cosa, así que ahora
  //     son un solo objeto con cuatro zonas: cabecera, escenario, mesa y
  //     base. La jerarquía de dentro se hace con espacio y peso tipográfico,
  //     no con más bordes: **nada anidado lleva sombra**. Una sombra dentro
  //     de otra sombra es lo que hacía que esto pareciera recortado a mano.
  //
  //   · EL CROMO DEJA DE SER CONTENIDO. Los dos botones de la barra de
  //     título iban enmarcados en blanco con borde y sombra, como si fueran
  //     tarjetas. Son cromo: dos iconos planos.
  //
  //   · EL CONTADOR DE DECISIONES SE VA DE LA BARRA. Era el tercer objeto
  //     flotando ahí arriba y por eso el título se cortaba en "Zona Gam…".
  //     Ahora vive en el subtítulo del resumen, que es donde ya se cuentan
  //     los puntos y las tiradas, y de paso ese subtítulo deja de ser fijo.
  //
  //   · EL HISTORIAL SE VA AL RESUMEN. El "Resumen de la partida" ya
  //     prometía "historial" en su propio subtítulo y no lo enseñaba,
  //     mientras la lista entera estaba repetida abajo del todo en la
  //     pantalla principal. Estaba en dos sitios y ninguno de los dos era
  //     el correcto.
  //
  //   · "AÑADIR UN JUICIO PICANTE" DEJA DE ESTAR SIEMPRE AL FINAL. Salía
  //     abajo del todo en los dos modos, incluso jugando a la ruleta, donde
  //     no pinta nada. Ahora aparece dentro del escenario del juicio
  //     picante, que es el momento exacto en que a alguien se le ocurre un
  //     reto.
  //
  // De nueve bloques a tres: la mesa, el próximo logro y el resumen.
  //
  // LA ESCALA, para que no vuelva a haber dieciocho valores a ojo:
  //   espacios     6 · 10 · 16 · 24 · 32  (nada de 14, 18, 22, 26, 28)
  //   titular      34 / w900 / tracking −0,8 / interlineado 1,05
  //   rótulo       10 / w800 / tracking +1,4 / mayúsculas
  //   nombre       17 / w800
  //   cuerpo       13 / w500 / interlineado 1,45
  // El tracking se aprieta al crecer y se abre al encoger, que es como se
  // comporta la tipografía bien ajustada: las letras grandes se leen
  // separadas y las pequeñas, apelotonadas.
  // ═══════════════════════════════════════════════════════════════════════════

  // ─── Escala tipográfica de esta pantalla ────────────────────────────────────
  static TextStyle get _display => GoogleFonts.outfit(
    fontSize: 34,
    height: 1.05,
    letterSpacing: -0.8,
    fontWeight: FontWeight.w900,
    color: _kDark,
  );

  static TextStyle get _overline => GoogleFonts.inter(
    fontSize: 10,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w800,
    color: AppColors.textSecondary,
  );

  static TextStyle get _body => GoogleFonts.inter(
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // Los mismos tres, para cuando el fondo es el navy del escenario.
  //
  // No basta con poner el texto blanco: sobre oscuro los trazos finos se
  // adelgazan ópticamente, así que el cuerpo sube a w600. Los alfas están
  // elegidos por contraste medido sobre #0F172A, no a ojo: el overline queda
  // en 8,6:1 y el cuerpo en 10:1, los dos por encima de AA a ese tamaño.
  static TextStyle get _displayOnDark => _display.copyWith(color: Colors.white);
  static TextStyle get _overlineOnDark =>
      _overline.copyWith(color: Colors.white.withValues(alpha: 0.72));
  static TextStyle get _bodyOnDark => _body.copyWith(
    color: Colors.white.withValues(alpha: 0.80),
    fontWeight: FontWeight.w600,
  );

  /// Cambiar de diario cambia de mesa.
  ///
  /// Sin esto, el arreglo de arriba solo funcionaría al abrir la app: si
  /// cambias de diario con La ruleta ya montada, la pantalla se quedaría con
  /// los comensales y los puntos del anterior y los guardaría bajo la clave
  /// del nuevo — que es la misma mezcla de antes, por otra puerta.
  Future<void> _cambiarDeDiario() async {
    setState(() {
      _players = <Map<String, dynamic>>[];
      _decisionsCount = 0;
      _selectedWinner = null;
      _currentChallenge = null;
      _palitoPick = null;
      _history.clear();
      _punishmentCounts.clear();
      _highlightedIndex.value = -1;
      // El aviso de «no llegan tus puntos» se vuelve a permitir: el diario
      // nuevo puede tener otros permisos.
      _avisadoFalloDeSincronia = false;
    });

    await _loadPersistedData();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // La mesa pertenece al diario que estés viendo. Ver `_clavePartida`.
    ref.listen<String?>(activeGroupIdProvider, (String? _, String? ahora) {
      if (ahora == _diarioDeLaMesa) return;
      _cambiarDeDiario();
    });

    final bool firstTime = _decisionsCount == 0 && !_introDismissed;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        // SIN flecha de volver. La ruleta es una pestaña raíz del dock, no
        // una pantalla apilada: esa flecha prometía un "atrás" que no existe
        // y en realidad te mandaba a Inicio, que no es de donde venías.
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(color: _kDark, width: AppBorder.thin),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: Image.asset(
                  'assets/images/logo.png',
                  semanticLabel: 'Logotipo de Palito de Sabores',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'La ruleta',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  letterSpacing: -0.3,
                  color: _kDark,
                ),
              ),
            ),
          ],
        ),
        centerTitle: false,
        // ── DOS ICONOS PLANOS, NO DOS TARJETAS ──
        //
        // Iban enmarcados en blanco, con borde de 2 y sombra maciza, igual
        // que las tarjetas del contenido. Una barra de título es cromo: lo
        // que hace es estar disponible sin llamar la atención. Enmarcarlos
        // los ponía a competir con la mesa, que es lo único que hay que
        // mirar aquí. El área táctil sigue siendo la de un `IconButton`
        // completo, o sea 48: lo que se quita es dibujo, no dedo.
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, size: 23),
            color: _kDark,
            onPressed: () => showHowToPlaySheet(context),
            tooltip: 'Cómo se juega',
          ),
          IconButton(
            // El botón decía "Puntuaciones e Insignias", la hoja que abre se
            // titula "El podio" y su sección se llama "Logros de la mesa":
            // tres nombres para lo mismo, y el del botón era el único que no
            // aparecía dentro.
            icon: const Icon(Icons.military_tech_rounded, size: 23),
            color: _kDark,
            onPressed: _showBadgesModal,
            tooltip: 'Ver el podio y los logros',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SafeArea(
            child: SingleChildScrollView(
              // EL HUECO DE ABAJO LO MARCA EL DOCK, NO UN 60 A OJO.
              //
              // El dock flota por delante del contenido en su propio `Stack`
              // (ver main.dart) y ocupa 76 píxeles más el área segura del
              // móvil: en un iPhone con isla dinámica, unos 110.
              padding: EdgeInsets.fromLTRB(
                20,
                6,
                20,
                AppDock.height + 32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Una línea, no una tarjeta. Quien abre esto por primera
                  // vez necesita saber que hay reglas escritas; no necesita
                  // un bloque de 120 puntos de alto empujando el botón de
                  // girar fuera de pantalla, que es lo que hacía la tarjeta
                  // de introducción.
                  // ── SE PLIEGA, NO DESAPARECE ──
                  //
                  // Al cerrarla, la línea se esfumaba de un fotograma al
                  // siguiente y toda la pantalla daba un tirón hacia arriba.
                  // Lo que el usuario acaba de hacer —quitar un aviso— se
                  // leía como un fallo de dibujado.
                  //
                  // Con `AnimatedSize` el hueco se cierra en 240 ms y la
                  // mesa sube acompañando. Es de los pocos sitios de la app
                  // donde algo se va, y una salida sin animar se nota más
                  // que una entrada sin animar: la entrada la esperas, la
                  // salida la provocas tú.
                  AnimatedSize(
                    duration: AppMotion.dur(context, AppAnimation.standard),
                    curve: AppAnimation.inOut,
                    alignment: Alignment.topCenter,
                    child: firstTime
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _FirstTimeLine(
                                onOpen: () => showHowToPlaySheet(context),
                                onDismiss: () =>
                                    setState(() => _introDismissed = true),
                              ),
                              const SizedBox(height: 10),
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),

                  _buildTable(context),

                  const SizedBox(height: 16),

                  if (_nextAchievement != null) ...<Widget>[
                    _NextAchievementStrip(
                      achievement: _nextAchievement!,
                      onTap: _showBadgesModal,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // El subtítulo ya no es un rótulo fijo: cuenta lo que
                  // lleváis. Un botón que dice cuánto hay dentro se pulsa;
                  // uno que dice "insignias, historial y empezar de cero"
                  // en todas las partidas, no.
                  ZonaGamerCard(
                    title: kResumenDeLaPartida,
                    subtitle: _decisionsCount == 0
                        ? 'Puntos, historial e insignias'
                        : '$_decisionsCount '
                              '${_decisionsCount == 1 ? 'decisión' : 'decisiones'}'
                              ' · puntos, historial e insignias',
                    backgroundColor: _kDark,
                    onTap: _showZonaGamerProModal,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EL PROTAGONISTA
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // Cuatro zonas dentro de un solo objeto, de arriba abajo:
  //
  //   CABECERA   las dos pestañas de modo, a sangre, rellenas del color del
  //              modo. El color ES el borde superior de la mesa.
  //   ESCENARIO  sobre blanco: quién sale, qué le toca, qué propone Palito.
  //   LA MESA    banda crema con los comensales. Otro tono de superficie
  //              basta para decir "esto es otra cosa" — no hace falta otro
  //              borde ni otra sombra.
  //   BASE       el botón de girar, a sangre, navy, con el radio de abajo
  //              de la propia tarjeta. Es la base de la máquina, no un
  //              botón suelto flotando debajo de ella.
  //
  // La tarjeta entera es lo único de la pantalla con sombra grande (4,4).
  // Eso es lo que la convierte en el protagonista sin subir ni un punto de
  // saturación.
  Widget _buildTable(BuildContext context) {
    final Color modeColor = _selectedMode == 0 ? _kYellow : _kRed;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _kDark, width: AppBorder.normal),
        boxShadow: AppShadow.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ModeSelector(
            selectedMode: _selectedMode,
            onSelect: (int m) {
              if (m == _selectedMode) return;
              HapticFeedback.selectionClick();
              setState(() => _selectedMode = m);
            },
          ),

          // La altura del escenario cambia cuando aparece un reto, cuando
          // Palito propone plato o cuando sale un ganador. Sin esto, la
          // tarjeta pega un salto y la mesa entera se descoloca de golpe.
          AnimatedSize(
            duration: AppMotion.dur(context, AppAnimation.standard),
            curve: AppAnimation.inOut,
            alignment: Alignment.topCenter,
            child: _buildStage(context, modeColor),
          ),

          Container(height: AppBorder.thin, color: _kDark),

          _buildTableBand(context, modeColor),

          _SpinFoot(
            spinning: _isSpinning,
            pulse: _pulseAnimation,
            accent: modeColor,
            icon: _selectedMode == 0
                ? Icons.casino_rounded
                : Icons.local_fire_department_rounded,
            label: _isSpinning
                ? 'Girando…'
                // En español solo va en mayúscula la primera palabra.
                // "Girar Ruleta" es mayúscula a la inglesa: en un botón
                // español se lee como un error, no como énfasis.
                : (_selectedMode == 0
                      ? '¡Girar la ruleta!'
                      : '¡Lanzar el juicio picante!'),
            onTap: _isSpinning ? null : _spinGame,
          ),
        ],
      ),
    );
  }

  // ─── Escenario ──────────────────────────────────────────────────────────────
  //
  // POR QUÉ EL ESCENARIO ES OSCURO Y TIENE UNA CARA GRANDE EN MEDIO.
  //
  // Hasta aquí el escenario eran dos líneas de texto sobre blanco. Eso quería
  // decir que durante el giro no se movía nada grande: el barrido solo existía
  // en las fichas de 62 puntos del fondo de la tarjeta, y el premio final era
  // una palabra creciendo un 6 %. El momento más importante de la app no tenía
  // ni imagen, ni escala, ni luz — y por eso la pantalla se leía como una lista
  // de cajas por muy pulida que estuviera cada caja. Ese era el fallo, y no se
  // arregla añadiendo adornos a las cajas.
  //
  // Ahora el escenario es un foco encendido: navy de marca con un halo del
  // color del modo detrás, y en el centro la cara de quien el barrido está
  // señalando en ese instante. El barrido deja de ser un detalle del fondo y
  // pasa a ser el espectáculo, porque la cara cambia al ritmo real del giro,
  // que ya decelera bien (35 + paso^1,35 × 3 ms).
  //
  // El navy no amplía la paleta: la tarjeta de Resumen ya es navy. Blanco
  // sobre #0F172A mide 17:1 y el amarillo de marca 11:1, así que el texto de
  // aquí dentro cumple AA holgado.
  Widget _buildStage(BuildContext context, Color modeColor) {
    final Map<String, dynamic>? winner = _selectedWinner;
    final bool canPlay = _players.length >= 2;

    // Las fotos se leen aquí, en `build`, y no dentro del
    // `ValueListenableBuilder`: un `ref.watch` en un rebuild que no nace de
    // `build` revienta, y ese builder se dispara treinta veces por giro.
    final Map<String, String> fotos = ref.watch(activeGroupProfileImagesProvider);

    final String overline;
    if (winner != null) {
      overline = _selectedMode == 0
          ? (_isPalito(winner)
                ? 'PALITO ELIGE POR VOSOTROS'
                : 'LE TOCA ELEGIR PLATO A')
          : 'VEREDICTO FINAL';
    } else if (_isSpinning) {
      overline = 'BUSCANDO COMENSAL…';
    } else if (_players.isEmpty) {
      overline = 'LA MESA ESTÁ VACÍA';
    } else if (_players.length == 1) {
      overline = 'SOLO ESTÁS TÚ EN LA MESA';
    } else {
      overline = 'SOIS ${_players.length} EN LA MESA';
    }

    final String headline = winner != null
        ? winner['name'] as String
        : (!canPlay
              ? 'Falta gente'
              : (_selectedMode == 0 ? '¿Quién elige?' : '¿A quién le cae?'));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // El halo es el color del modo mezclado con el navy, no el color del
        // modo con alfa: así el amarillo no se apaga a gris sucio y el coral
        // no tira a marrón. `alphaBlend` hace la mezcla una vez, opaca.
        // Un 26 % en dos paradas daba un campo casi plano: en pantalla no
        // se leía como luz, se leía como navy con una mancha. Tres paradas
        // con una caída de verdad (34 % → 10 % → nada) sí hacen un foco.
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 1.4,
          colors: <Color>[
            Color.alphaBlend(modeColor.withValues(alpha: 0.34), _kDark),
            Color.alphaBlend(modeColor.withValues(alpha: 0.10), _kDark),
            _kDark,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ValueListenableBuilder<int>(
            valueListenable: _highlightedIndex,
            builder: (BuildContext context, int highlighted, Widget? _) {
              final Map<String, dynamic>? foco =
                  winner ??
                  (_isSpinning &&
                          highlighted >= 0 &&
                          highlighted < _players.length
                      ? _players[highlighted]
                      : null);
              final bool showsName = foco != null;
              final String liveHeadline = showsName
                  ? (foco['name']?.toString() ?? headline)
                  : headline;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // En reposo no hay foco. Un círculo vacío de 104 puntos en
                  // mitad del escenario es el objeto más grande de la
                  // pantalla sin decir nada: parece un hueco sin cargar, no
                  // una pieza de diseño. El foco aparece cuando hay a quién
                  // enfocar, y ese aparecer es parte del número: el
                  // `AnimatedSize` de la tarjeta abre el escenario al girar.
                  if (foco != null) ...<Widget>[
                    _Spotlight(
                      nombre: foco['name']?.toString() ?? '',
                      fotoUrl: fotos[foco['uid']?.toString()],
                      esPalito: _isPalito(foco),
                      modeColor: modeColor,
                      ganador: winner != null,
                      girando: _isSpinning,
                      pulso: _pulseAnimation,
                      entrada: _winnerScaleAnimation,
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text(
                    overline,
                    style: _overlineOnDark,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    liveHeadline,
                    maxLines: showsName ? 1 : null,
                    overflow: showsName ? TextOverflow.ellipsis : null,
                    style: _displayOnDark,
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),

          // ── La mesa no da para jugar todavía ──
          if (!canPlay && winner == null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _players.isEmpty
                  ? 'Sentad a la mesa a quien esté comiendo. Con dos ya se '
                        'puede jugar.'
                  : 'Con dos ya se puede jugar.',
              style: _bodyOnDark,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            NeoActionButton(
              label: 'Añadir comensales',
              icon: Icons.person_add_alt_1_rounded,
              background: modeColor,
              onTap: _showAddPlayerDialog,
              expand: false,
            ),
          ],

          // ── Lo que ha elegido Palito ──
          if (winner != null && _isPalito(winner) && _selectedMode == 0) ...<
            Widget
          >[
            const SizedBox(height: 18),
            _InsetPanel(
              background: AppColors.tintPrimary,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _palitoPick == null
                        ? 'TODAVÍA NO OS CONOZCO'
                        : 'ESTA NOCHE, ESTO',
                    style: _overline,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _palitoPick ??
                        'Apuntad algún plato y os propongo uno de los '
                            'vuestros',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: _palitoPick == null ? 14 : 19,
                      height: 1.2,
                      letterSpacing: _palitoPick == null ? 0 : -0.3,
                      fontWeight: FontWeight.w800,
                      color: _kDark,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── El reto del juicio picante ──
          if (_selectedMode == 1 && _currentChallenge != null) ...<Widget>[
            const SizedBox(height: 18),
            Semantics(
              button: true,
              label: 'Reto: ${_currentChallenge!}. Tocar para evaluarlo.',
              child: ExcludeSemantics(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () {
                      final Map<String, dynamic>? w = _selectedWinner;
                      final String? challenge = _currentChallenge;
                      if (w == null || challenge == null) return;
                      _showChallengeOutcomeDialog(
                        w['name'] as String,
                        challenge,
                      );
                    },
                    child: _InsetPanel(
                      background: AppColors.tintAccent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _currentChallenge!,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                              color: _kDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Decir si lo cumplió',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentText,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 17,
                                color: AppColors.accentText,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // ── Añadir un reto propio ──
          if (_selectedMode == 1 && winner == null && canPlay) ...<Widget>[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showAddChallengeDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Añadir un reto vuestro'),
              // Blanco y no el coral del modo: es una acción secundaria y el
              // coral sobre navy se queda en 4,9:1, justo en el filo de AA.
              // El blanco da 17:1 y además evita meter un tercer color en un
              // panel que ya tiene el navy y el halo del modo.
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: Colors.white,
                textStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── La banda de la mesa ────────────────────────────────────────────────────
  Widget _buildTableBand(BuildContext context, Color modeColor) {
    final String? myUid = ref.watch(gamerServiceProvider).currentUid;
    // Las fotos salen del documento del diario que esta pantalla ya observa:
    // ni una lectura más. Ver `_CaraComensal`.
    final Map<String, String> fotos = ref.watch(
      activeGroupProfileImagesProvider,
    );
    final bool anyLinked =
        myUid != null &&
        _players.any((Map<String, dynamic> p) => p['uid'] == myUid);

    return Container(
      // ── POR QUÉ LA BANDA VOLVIÓ A SER BLANCA ──
      //
      // Fue amarillo pálido mientras el escenario era blanco: hacía falta
      // algo que dijera "esto es la mesa, aquello es el juego". Ahora el
      // escenario es navy con luz propia, o sea que esa separación ya está
      // hecha, y el amarillo solo añadía una tercera franja de color a una
      // tarjeta que ya iba pestaña amarilla → panel oscuro → botón navy.
      //
      // Blanco es aquí el color que descansa: deja que el navy de arriba
      // mande y que el amarillo vuelva a significar una sola cosa en esta
      // pantalla — a quién está señalando la ruleta.
      color: AppColors.surface,
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _players.isEmpty
                        ? 'LA MESA'
                        : 'LA MESA · ${_players.length}',
                    style: _overline,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddPlayerDialog,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Añadir'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: _kDark,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_players.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 2, 24, 4),
              child: Text('Todavía no hay nadie sentado.', style: _body),
            )
          else ...<Widget>[
            const SizedBox(height: 14),
            // ═══════════════════════════════════════════════════════════
            // LA MESA ES EL ESCENARIO
            // ═══════════════════════════════════════════════════════════
            //
            // Esto era una fila que se desplazaba en horizontal, con fichas
            // de 74 puntos, debajo de un escenario blanco de 155 que
            // enseñaba un círculo, un rótulo diminuto y un titular.
            //
            // O sea: **la pantalla le daba el espacio grande a lo que menos
            // tenía que enseñar**, y metía a las personas —que son el
            // contenido del juego— en una tira de fichas pequeñas al fondo.
            // Con tres comensales sobraba medio panel en blanco, y con seis
            // la mitad de la gente estaba fuera de pantalla.
            //
            // Y contradecía el criterio que este mismo fichero declara:
            // «La ruleta es una mesa a la que te sientas». A una mesa te
            // sientas con gente delante, no con una tira de cromos.
            //
            // Ahora las caras están en el centro y en grande, y la ruleta
            // las va encendiendo ahí. `Wrap` y no una lista horizontal: una
            // mesa de ocho se ve entera en dos filas en vez de esconder a
            // la mitad detrás del borde. Una mesa no se desplaza; se mira.
            ValueListenableBuilder<int>(
              valueListenable: _highlightedIndex,
              builder: (BuildContext context, int highlighted, Widget? _) =>
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    // `WrapAlignment.center` no hacía nada: la columna de
                    // esta banda alinea a la izquierda, así que el `Wrap` se
                    // ajustaba al ancho de sus propias fichas, y centrar
                    // dentro de sí mismo no mueve nada. Con el ancho
                    // declarado ya hay espacio que repartir, y la mesa queda
                    // centrada bajo el escenario en vez de escorada.
                    child: SizedBox(
                      width: double.infinity,
                      child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 16,
                      children: <Widget>[
                      for (
                        int index = 0;
                        index < _players.length;
                        index++
                      )
                        Builder(
                          builder: (BuildContext context) {
                            final Map<String, dynamic> player =
                                _players[index];
                            return _PlayerChip(
                            player: player,
                            photoUrl: fotos[player['uid']?.toString()],
                            highlighted: index == highlighted,
                            spinning: _isSpinning,
                            accent: modeColor,
                            // El foco de un escenario apaga lo que no
                            // señala. Mientras gira, los demás bajan a un
                            // 40 %: el barrido deja de competir con siete
                            // fichas igual de fuertes.
                            dimmed: _isSpinning && index != highlighted,
                            winner:
                                _selectedWinner != null &&
                                _selectedWinner!['name'] == player['name'],
                            linkedToMe:
                                myUid != null && player['uid'] == myUid,
                            onTap: () => _toggleLinkedToMe(index),
                            onLongPress: () => _confirmRemovePlayer(index),
                            );
                          },
                        ),
                      ],
                      ),
                    ),
                  ),
            ),
            // La pista desaparece en cuanto ha servido para algo. Un texto
            // de ayuda que sigue ahí cuando ya has hecho lo que pedía deja
            // de ser ayuda y pasa a ser ruido.
            //
            // Y ya no pide lo mismo: antes había que buscar tu propia ficha
            // y tocarla para que tus puntos llegaran a tu cuenta. Ahora
            // quien está en el diario se sienta solo y con su cuenta puesta,
            // así que lo único que queda por explicar es lo que la app no
            // puede adivinar: quién de los que están comiendo eres tú, si te
            // añadiste a mano antes de que existiera todo esto.
            if (!anyLinked) ...<Widget>[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Toca tu ficha para que tus puntos lleguen a tu cuenta. '
                  'Mantén pulsada cualquiera para quitarla de la mesa.',
                  style: _body.copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// ===========================================================================
/// LA BASE DE LA MESA
/// ===========================================================================
///
/// El botón de girar era un bloque suelto con su propio borde y su propia
/// sombra, separado 24 puntos del panel al que pertenece. Aquí es la base de
/// la tarjeta: a sangre, sin borde propio, y el radio de las esquinas de
/// abajo se lo da el recorte de la mesa.
///
/// Responde en el momento en que el dedo baja, no al levantarlo: el `InkWell`
/// ilumina en `onPointerDown`. Un botón que solo reacciona al soltar se
/// siente muerto aunque tarde lo mismo.
class _SpinFoot extends StatelessWidget {
  const _SpinFoot({
    required this.spinning,
    required this.pulse,
    required this.accent,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool spinning;
  final Animation<double> pulse;
  final Color accent;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double scale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 1.4).toDouble();

    // ── ESTO TENÍA QUE SER UN BOTÓN Y NO LO ERA ──
    //
    // Lo rompí yo al rehacer la pantalla: el botón de girar era un
    // `NeoPressable`, que declara su papel de botón, y lo sustituí por un
    // `Material` + `InkWell` pelados para poder pintarlo a sangre como base
    // de la tarjeta. Un `InkWell` a secas registra el toque pero **no se
    // anuncia como botón**: comprobado en el árbol de accesibilidad del
    // simulador, salía como texto suelto.
    //
    // O sea que la acción principal de la pantalla —lo único que hay que
    // tocar— le llegaba a quien usa VoiceOver como una frase que no se puede
    // pulsar. Y mientras gira, además, hay que decir que no se puede tocar:
    // sin `enabled: false` el lector lo ofrece igual y el doble toque no
    // hace nada.
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: ExcludeSemantics(
      child: Material(
      color: AppColors.textPrimary,
      child: InkWell(
        onTap: onTap,
        highlightColor: Colors.white24,
        splashColor: Colors.white10,
        child: SizedBox(
          height: 60 * scale,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // El latido va en el icono, no en la tarjeta entera. Lo que
              // está trabajando es la ruleta; una mesa que respira mientras
              // gira no dice nada y además mueve el suelo bajo el texto.
              ScaleTransition(
                // Un latido continuo es de lo que peor le sienta a quien ha
                // pedido menos movimiento: no es un cambio que pasa y se
                // acaba, es algo que no para nunca.
                scale: spinning && !AppMotion.reduced(context)
                    ? pulse
                    : const AlwaysStoppedAnimation<double>(1.0),
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    letterSpacing: -0.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}

/// Una caja DENTRO de la mesa: borde fino, sin sombra.
///
/// Todo lo que va dentro de la tarjeta grande usa esto. La regla, que es la
/// que faltaba: **nada anidado lleva sombra**. Una sombra maciza dentro de
/// otra sombra maciza es lo que hacía que esta pantalla pareciera pegada con
/// cinta.
class _InsetPanel extends StatelessWidget {
  const _InsetPanel({required this.child, required this.background});

  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: _kDark, width: AppBorder.thin),
      ),
      child: child,
    );
  }
}

/// ===========================================================================
/// LA CARA DE UN COMENSAL
/// ===========================================================================
///
/// POR QUÉ ESTA PANTALLA PARECÍA DE JUGUETE. Cada comensal se pintaba con un
/// icono de Material: `Icons.face_rounded` —una carita sonriente de
/// clipart— o `Icons.person_rounded`, la silueta genérica. Todos iguales,
/// todos de dibujo animado, cada uno teñido de un color de una paleta
/// rotatoria.
///
/// Ese es el motivo de fondo, y no los bordes ni el amarillo: **una mesa de
/// caritas sonrientes es una mesa de dibujos**, y da igual lo cuidada que
/// esté la tipografía alrededor. Ninguna app que se tome en serio a sus
/// usuarios les representa con un emoji del sistema.
///
/// La app ya tenía lo que hacía falta y no lo usaba aquí: la foto de perfil
/// de cada miembro del diario. Ahora, por orden:
///
///   1. **Su foto**, si la tiene. Es una persona real en la mesa.
///   2. **Su inicial**, si no. Una letra distingue; una silueta, no.
///   3. **El tenedor**, solo para Palito, que sí es un personaje.
///
/// Los invitados —quien está comiendo y no tiene la app— se quedan en su
/// inicial, que es exactamente lo que se sabe de ellos: su nombre.
/// ===========================================================================
/// EL FOCO
/// ===========================================================================
///
/// La cara grande del escenario: la que el barrido va iluminando durante el
/// giro y en la que aterriza el ganador.
///
/// POR QUÉ AQUÍ SÍ HAY REBOTE.
///
/// La regla del resto de la app es amortiguar del todo: nada de sobreimpulso
/// en algo que simplemente ha aparecido, porque se lee como un tic. Aquí el
/// gesto trae inercia — veintitantos pasos decelerando — y un frenazo seco
/// después de eso se siente como una pared. `AppAnimation.celebrate`
/// (Cubic 0.175, 0.885, 0.32, 1.45) es el rebote que ya estaba en los tokens
/// y que esta pantalla nunca llegó a usar.
///
/// El aro que sale despedido y la escala de la cara van con `Transform`, no
/// cambiando el tamaño de los `Container`: así el foco ocupa siempre 104
/// puntos de alto y el texto de debajo no da botes mientras la animación
/// corre.
class _Spotlight extends StatelessWidget {
  const _Spotlight({
    required this.nombre,
    required this.fotoUrl,
    required this.esPalito,
    required this.modeColor,
    required this.ganador,
    required this.girando,
    required this.pulso,
    required this.entrada,
  });

  final String nombre;
  final String? fotoUrl;
  final bool esPalito;

  final Color modeColor;
  final bool ganador;
  final bool girando;
  final Animation<double> pulso;
  final Animation<double> entrada;

  static const double _lado = 104;
  static const double _aro = 3;

  @override
  Widget build(BuildContext context) {
    final Widget cara = Container(
      width: _lado,
      height: _lado,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: _aro),
        // El halo no es una sombra: es la luz del foco. Por eso no lleva
        // desplazamiento y sí difuminado, al revés que las sombras macizas
        // de la marca.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: modeColor.withValues(alpha: ganador ? 0.55 : 0.28),
            blurRadius: ganador ? 32 : 16,
            spreadRadius: ganador ? 2 : 0,
          ),
        ],
      ),
      child: _CaraComensal(
        nombre: nombre,
        esPalito: esPalito,
        fotoUrl: fotoUrl,
        lado: _lado - _aro * 2,
        colorTexto: _kDark,
        fondo: ganador ? modeColor : AppColors.tintPrimary,
      ),
    );

    if (AppMotion.reduced(context)) return cara;

    // Girando o en reposo: el foco respira al compás del botón y nada más.
    if (girando || !ganador) {
      return ScaleTransition(
        scale: girando ? pulso : const AlwaysStoppedAnimation<double>(1.0),
        child: cara,
      );
    }

    // Aterrizaje.
    return SizedBox(
      width: _lado,
      height: _lado,
      child: AnimatedBuilder(
        animation: entrada,
        child: cara,
        builder: (BuildContext context, Widget? child) {
          // `celebrate` pasa de 1 antes de asentarse: la escala lo aprovecha
          // sin recortar, y solo la opacidad se acota porque `Opacity` no
          // admite valores fuera de 0–1.
          final double v = entrada.value;
          final double t = v.clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: <Widget>[
              if (t < 0.999)
                Opacity(
                  opacity: (1.0 - t) * 0.7,
                  child: Transform.scale(
                    scale: 1.0 + t * 0.55,
                    child: Container(
                      width: _lado,
                      height: _lado,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: modeColor, width: 2.5),
                      ),
                    ),
                  ),
                ),
              Transform.scale(scale: 0.72 + 0.28 * v, child: child),
            ],
          );
        },
      ),
    );
  }
}

class _CaraComensal extends StatelessWidget {
  const _CaraComensal({
    required this.nombre,
    required this.esPalito,
    required this.fotoUrl,
    required this.lado,
    required this.colorTexto,
    this.fondo,
  });

  final String nombre;
  final bool esPalito;
  final String? fotoUrl;
  final double lado;
  final Color colorTexto;
  final Color? fondo;

  @override
  Widget build(BuildContext context) {
    final String limpio = nombre.trim();

    Widget contenido;
    if (esPalito) {
      contenido = Image.asset(
        'assets/icons/IconoRedondoTenedor.png',
        width: lado * 0.78,
        height: lado * 0.78,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) =>
            Icon(Icons.restaurant, color: colorTexto, size: lado * 0.45),
      );
    } else if (fotoUrl != null && fotoUrl!.isNotEmpty) {
      // EL `SizedBox` NO ES DECORATIVO, ARREGLA UN FALLO.
      //
      // El `Container` de abajo lleva `alignment: center`, y un `Container`
      // con alineación da a su hijo restricciones holgadas: la foto se
      // pintaba a su tamaño natural —una foto de cámara— centrada y
      // recortada por el círculo. O sea que en la mesa no se veía la cara
      // de nadie: se veía el trozo del centro de su foto a resolución
      // completa. `BoxFit.cover` no puede cubrir nada si no se le dice qué.
      //
      // Con el hueco declarado, `cover` hace su trabajo: escala la foto
      // hasta tapar el círculo y recorta lo que sobra por el lado largo.
      contenido = SizedBox(
        width: lado,
        height: lado,
        child: SmartImage(
          imagePath: fotoUrl,
          width: lado.round(),
          fit: BoxFit.cover,
        ),
      );
    } else {
      contenido = Text(
        limpio.isEmpty
            ? '?'
            : String.fromCharCode(limpio.runes.first).toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: lado * 0.44,
          fontWeight: FontWeight.w900,
          color: colorTexto,
          height: 1,
        ),
      );
    }

    return Container(
      width: lado,
      height: lado,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
      child: contenido,
    );
  }
}

/// La ficha de un comensal sentado a la mesa.
class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.player,
    required this.photoUrl,
    required this.highlighted,
    required this.spinning,
    required this.accent,
    required this.dimmed,
    required this.winner,
    required this.linkedToMe,
    required this.onTap,
    required this.onLongPress,
  });

  final Map<String, dynamic> player;

  /// La foto de perfil de este comensal, si es un miembro del diario y la
  /// tiene puesta. Los invitados no tienen ninguna, y está bien así.
  final String? photoUrl;

  final bool highlighted;

  /// El color del modo en juego. La ficha marcada se ribetea con él, igual
  /// que el halo del escenario: mesa y foco hablan el mismo idioma.
  final Color accent;

  /// La ruleta está señalando a otro. Esta ficha se aparta.
  final bool dimmed;

  /// La ruleta está girando ahora mismo.
  final bool spinning;

  final bool winner;
  final bool linkedToMe;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final String name = player['name']?.toString() ?? 'Comensal';
    final bool marked = highlighted || winner;

    return AnimatedOpacity(
      // Sin transición mientras gira: el barrido cambia de ficha cada 35 ms
      // y una interpolación de 160 ms las dejaría a todas a medio encender.
      // Al parar sí se funde, para que la mesa vuelva entera sin un salto.
      duration: spinning
          ? Duration.zero
          : AppMotion.dur(context, AppAnimation.fast),
      curve: AppAnimation.tint,
      opacity: dimmed ? 0.4 : 1.0,
      child: Semantics(
      button: true,
      label:
          '$name${linkedToMe ? ', vinculado a tu cuenta' : ''}. '
          'Toca para vincular tus puntos, mantén pulsado para quitarlo.',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            onLongPress: onLongPress,
            child: AnimatedContainer(
              // ── GIRANDO, LA LUZ SE ENCIENDE DE GOLPE ──
              //
              // El tinte tardaba 160 ms en cambiar, y los primeros saltos de
              // la ruleta van a 35 ms: la ficha iba cuatro saltos por detrás
              // del titular. Lo vi en una captura a mitad de giro —arriba
              // ponía "Pedro" y la ficha encendida era la de Juan—, que es
              // exactamente la clase de detalle por el que una pantalla
              // parece mal hecha aunque nadie sepa decir por qué.
              //
              // Una bombilla de ruleta no se funde a color: se enciende.
              // Parada, sí se funde —ahí el cambio lo provoca un dedo, no
              // la máquina—.
              duration: spinning
                  ? Duration.zero
                  : AppMotion.dur(context, AppAnimation.fast),
              curve: AppAnimation.tint,
              // 86 y no 74: la cara pasa de 38 a 62 puntos. Es el cambio que
              // convierte una tira de cromos en una mesa con gente. Ver el
              // comentario de `_buildTableBand`.
              // 92 y no 86: es el ancho más grande con el que siguen
              // entrando tres fichas por fila en un iPhone de 393 puntos
              // (3×92 + 2×14 = 304, y el hueco útil de la banda mide 313).
              // Con 96 se caían a dos por fila.
              width: 92,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                // Relleno sólido, no alpha-blend: el mismo patrón de
                // "seleccionado" que las pestañas y los chips del resto de
                // la app.
                color: highlighted ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: marked ? accent : _kDark,
                  width: marked ? AppBorder.normal : AppBorder.thin,
                ),
                // SIN SOMBRA. Estas fichas están APOYADAS en la mesa, no
                // flotando sobre ella: la sombra de 2 que llevaban era la
                // cuarta capa de sombras anidadas de la pantalla.
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      // Cuando la ficha está encendida su fondo es amarillo,
                      // y el círculo se pintaba con EL COLOR DEL COMENSAL al
                      // 20 % y el icono en ese mismo color. Para quien
                      // tuviera el amarillo de marca —el primero de la mesa,
                      // siempre— salía amarillo sobre amarillo: el icono
                      // desaparecía justo cuando la ruleta lo elegía.
                      // Encendida, el círculo va en blanco con aro navy —el
                      // fondo de la ficha ya es amarillo y el color del
                      // comensal encima sería amarillo sobre amarillo justo
                      // cuando la ruleta lo señala—. Apagada, su color al
                      // 20 %, que es lo que lo distingue de un vistazo.
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: highlighted
                              ? const Border.fromBorderSide(
                                  BorderSide(
                                    color: _kDark,
                                    width: AppBorder.thin,
                                  ),
                                )
                              : null,
                        ),
                        child: _CaraComensal(
                          nombre: name,
                          esPalito: player['isBot'] == true,
                          fotoUrl: photoUrl,
                          lado: 62,
                          // Todas las caras iguales, a propósito.
                          //
                          // Cada comensal tenía su pastel de la paleta de
                          // asientos: amarillo, rosa, gris… Tres pasteles
                          // distintos uno al lado del otro, cada uno con su
                          // letra, no se leen como un sistema: se leen como
                          // pegatinas. Y el gris, además, parecía un avatar
                          // sin cargar.
                          //
                          // El color de asiento sigue existiendo y sigue
                          // usándose donde sí distingue (el podio del
                          // resumen). Aquí lo que tiene que destacar es a
                          // quién señala la ruleta, y eso ya lo dice el
                          // relleno amarillo de la ficha.
                          colorTexto: _kDark,
                          fondo: highlighted
                              ? AppColors.surface
                              : AppColors.tintPrimary,
                        ),
                      ),
                      if (linkedToMe)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(
                                  color: _kDark,
                                  width: AppBorder.thin,
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: _kDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // UNA LÍNEA, Y QUE SE ENCOJA SI HACE FALTA.
                  //
                  // Primero probé dos líneas, y en el simulador se vio por
                  // qué no vale: un nombre de usuario no tiene espacios
                  // donde partir, así que «marialr1989» salía «marialr198»
                  // y «9» debajo — el número cortado por la mitad. Y peor:
                  // esa ficha crecía 14 puntos y la fila quedaba con una
                  // ficha más alta que las otras.
                  //
                  // `FittedBox` en `scaleDown` deja el nombre en una línea
                  // y solo lo encoge cuando no cabe: nunca lo agranda, así
                  // que los nombres normales se siguen viendo a 13 puntos y
                  // todas las fichas miden lo mismo. El alto va declarado
                  // para que encoger no mueva nada de sitio.
                  //
                  // EL `SizedBox` DE DENTRO ES EL SUELO.
                  //
                  // `FittedBox` a secas no tiene límite: el campo admite 24
                  // caracteres (`FieldLimits.nombreComensal`), y 24
                  // caracteres en 80 puntos se encogen hasta 6 — completo y
                  // también ilegible, que no es arreglarlo.
                  //
                  // Así que el texto se mide primero en una caja de 104
                  // puntos, donde recorta con puntos suspensivos si no
                  // cabe, y `FittedBox` reduce esos 104 a los 80 reales:
                  // un factor de 0,77, o sea 10 puntos efectivos. Nunca
                  // baja de ahí. Los nombres normales siguen a 13.
                  SizedBox(
                    height: 17,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 104,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: _kDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// La línea de la primera vez.
///
/// Era una tarjeta de 120 puntos de alto con titular, párrafo, botón de
/// cerrar y enlace a las reglas — justo en la única visita en la que se ve, y
/// empujando el botón de girar fuera de pantalla. Lo único que tiene que
/// hacer es decir que las reglas existen y quitarse de en medio.
class _FirstTimeLine extends StatelessWidget {
  const _FirstTimeLine({required this.onOpen, required this.onDismiss});

  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('¿Primera vez? Mira cómo se juega'),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, 44),
              foregroundColor: _kDark,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Ocultar el aviso',
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: onDismiss,
            child: Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              alignment: Alignment.center,
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// La tira del siguiente logro: qué es, cuánto llevas y cuánto falta.
class _NextAchievementStrip extends StatelessWidget {
  const _NextAchievementStrip({
    required this.achievement,
    required this.onTap,
  });

  final Map<String, dynamic> achievement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String title = achievement['title']?.toString() ?? '';
    final int goal = achievement['goal'] as int? ?? 1;
    final int current = (achievement['progress'] as int? ?? 0).clamp(0, goal);
    final int missing = goal - current;

    return Semantics(
      button: true,
      label:
          'Siguiente logro: $title. Llevas $current de $goal. '
          'Toca para ver todos los logros',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: _kDark, width: AppBorder.thin),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    achievement['icon'] as IconData? ?? Icons.star_rounded,
                    size: 22,
                    color: _kDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // ── Decía "Mesa llena · te faltan 4" ──
                        //
                        // Sin este rótulo, la tira afirma un hecho y lo
                        // desmiente en la misma línea: "Mesa llena" a la
                        // izquierda y "te faltan 4" a la derecha. Visto en el
                        // simulador y hay que leerlo dos veces para entender
                        // que "Mesa llena" es el NOMBRE de un logro que
                        // todavía no tienes, no el estado de tu mesa.
                        //
                        // Lo llamativo: la etiqueta de VoiceOver de esta
                        // misma tira ya dice "Siguiente logro: ...". Quien la
                        // escuchaba entendía la pantalla mejor que quien la
                        // veía.
                        Text(
                          'PRÓXIMO LOGRO',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: _kDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              missing == 1 ? 'te falta 1' : 'te faltan $missing',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        ProgressTrack(
                          value: current / goal,
                          color: AppColors.primary,
                          height: 9,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
