import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/field_limits.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_log.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_shape.dart';
import 'app_motion.dart';
import 'marker_highlight.dart';
import 'smart_image.dart';
import '../../providers/memory_provider.dart';
import 'app_feedback.dart';

/// Selector del grupo activo: qué grupo se está viendo/usando ahora mismo en
/// Inicio/Mapa/Gamer/Perfil. Un toque abre la lista de todos los grupos del
/// usuario (empezando siempre por su diario personal) para cambiar de uno a
/// otro, gestionar sus miembros, o crear/unirse a uno nuevo.
/// Cabecera de Inicio: DE QUÉ DIARIO estás viendo el contenido, y el control
/// para cambiarlo.
///
/// La versión anterior era una pastilla de unos 30 píxeles de alto, debajo de
/// un titular enorme que ponía "Palito de Sabores". Es decir: el elemento más
/// grande de la pantalla repetía el nombre de la app —que el usuario ya sabe,
/// y que además está en el logotipo de al lado— mientras que el dato que de
/// verdad cambia lo que estás viendo iba en letra pequeña y con aspecto de
/// etiqueta, no de botón. Ese es el origen directo de "no entiendo los
/// grupos": la app nunca decía, con todas sus letras y en el sitio donde se
/// mira primero, en qué diario estás ni que puedes cambiarlo.
///
/// Ahora el nombre del diario ES el titular, con su galón y su flecha, y
/// debajo dice quién lo ve.
/// ===========================================================================
/// LAS DOS ETIQUETAS QUE EL INVITADO TIENE QUE ENCONTRAR
/// ===========================================================================
///
/// Son constantes y no literales sueltos por una razón concreta: el mensaje
/// que se copia al invitar («abre la app, ve a Perfil, toca…») NOMBRA ESTOS
/// DOS RÓTULOS. Si alguien los renombra aquí y no allí, el invitado se queda
/// buscando en el Perfil un botón que ya no se llama así — y ese mensaje es
/// justo el que se pega en un grupo de WhatsApp, o sea el texto de la app
/// que más gente lee y el único que nadie vuelve a mirar.
///
/// Ya pasó: el rótulo del Perfil se mejoró, el mensaje de invitación se
/// quedó con el viejo, y durante semanas mandó a la gente a tocar «Ver tus
/// diarios y quién está en cada uno», que no existe. Un comentario pidiendo
/// «cuidado, cámbialo en los dos sitios» no lo evitó. Esto sí.
const String kEntrarConCodigo = 'Entrar con un código';

/// El titular de la sección del Perfil. El rótulo del botón que hay debajo
/// NO sirve para dar indicaciones: cambia según cuántos diarios tengas
/// («Solo tienes tu diario privado», «Tu diario y 3 compartidos»), así que
/// quien acaba de instalar la app nunca ve el mismo texto que quien la
/// lleva usando un mes.
const String kSeccionTusDiarios = 'Tus diarios';

class GroupSwitcher extends ConsumerWidget {
  const GroupSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, dynamic>?> activeGroupAsync = ref.watch(
      activeGroupDocProvider,
    );
    final String? activeGroupId = ref.watch(activeGroupIdProvider);
    final String? personalGroupId = ref.watch(personalGroupIdProvider);
    final List<String> members = ref.watch(activeGroupMembersProvider);
    final int groupCount = ref.watch(userGroupIdsProvider).length;

    final bool isPersonal =
        activeGroupId != null && activeGroupId == personalGroupId;

    // Antes, un error del stream se mostraba como "Cargando…" para siempre.
    final String label;
    if (activeGroupAsync.hasError) {
      label = 'Sin diario';
    } else if (activeGroupAsync.isLoading && !activeGroupAsync.hasValue) {
      label = 'Cargando…';
    } else if (isPersonal) {
      label = 'Mi diario';
    } else {
      label = (activeGroupAsync.valueOrNull?['name'] as String?) ?? 'Diario';
    }

    final String subtitle;
    if (activeGroupAsync.hasError) {
      subtitle = 'No se pudo cargar';
    } else if (isPersonal) {
      subtitle = 'Privado — solo tú';
    } else if (members.length <= 1) {
      subtitle = 'Solo tú de momento';
    } else {
      subtitle = 'Tú y ${members.length - 1} '
          '${members.length - 1 == 1 ? 'persona' : 'personas'}';
    }

    return Semantics(
      button: true,
      label: 'Estás viendo el diario $label. $subtitle. '
          'Toca para cambiar de diario',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => openGroupSwitcher(context, ref),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'ESTÁS VIENDO',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      // El rotulador va AQUÍ y en ningún otro sitio de la
                      // app. Señalar a mano funciona porque dice "esto de
                      // aquí": con un solo trazo, el nombre del diario es lo
                      // primero que ve el ojo al abrir. Con tres trazos por
                      // pantalla no diría nada.
                      //
                      // Navy sobre el amarillo de marca mide 12,47:1 — el
                      // contraste más alto de toda la app.
                      child: MarkerHighlight(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            height: 1.1,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // El galón amarillo con la flecha: sin él, un titular
                    // grande no se lee como algo pulsable.
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(
                          color: AppColors.textPrimary,
                          width: AppBorder.normal,
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: AppColors.textPrimary,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.unfold_more_rounded,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  // La hoja ya no solo cambia de diario: también es donde
                  // se ve quién está en cada uno, se invita, se entra con un
                  // código y se crea uno nuevo. Con un solo diario todavía
                  // no hay nada que "cambiar", pero sí hay dónde compartir.
                  groupCount > 1
                      ? '$subtitle · Diarios y gente'
                      : '$subtitle · Compartir con alguien',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Abre la lista de grupos. Expuesto como función para que Perfil pueda usar
/// exactamente el mismo panel (antes solo se llegaba a él desde un chip
/// pequeño en Inicio, cuatro niveles por debajo de donde el usuario lo busca).
Future<void> openGroupSwitcher(BuildContext context, WidgetRef ref) async {
  HapticFeedback.selectionClick();

  final List<String> groupIds = ref.read(userGroupIdsProvider);
  final String? personalGroupId = ref.read(personalGroupIdProvider);
  final String? activeGroupId = ref.read(activeGroupIdProvider);
  final String? myUid = ref.read(currentUidProvider);

  // Los datos se cargan bajo demanda, solo al abrir el selector.
  //
  // Cada lectura va en su propio try/catch: si te han expulsado de un grupo,
  // su `get()` devuelve `permission-denied`, y antes ese fallo se propagaba
  // por el `Future.wait` y el panel NO SE ABRÍA NUNCA MÁS. La autolimpieza
  // que se supone que cubre ese caso era código inalcanzable, porque la
  // excepción saltaba antes de llegar a ella.
  final List<DocumentSnapshot<Map<String, dynamic>>> valid =
      <DocumentSnapshot<Map<String, dynamic>>>[];
  final List<String> toForget = <String>[];

  await Future.wait(
    groupIds.map((String id) async {
      try {
        final DocumentSnapshot<Map<String, dynamic>> snap =
            await FirebaseFirestore.instance.collection('groups').doc(id).get();

        final List<String> members =
            (snap.data()?['members'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const <String>[];

        // Un documento que ya no existe también hay que olvidarlo: antes
        // pasaba el filtro y se pintaba como un grupo llamado "Grupo" con
        // botones de invitar que fallaban al pulsarlos.
        if (!snap.exists || (myUid != null && !members.contains(myUid))) {
          toForget.add(id);
          return;
        }

        valid.add(snap);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' || e.code == 'not-found') {
          toForget.add(id);
        } else {
          AppLog.w('No se pudo leer un grupo: ${e.code}');
        }
      }
    }),
  );

  if (myUid != null && toForget.isNotEmpty) {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .set(<String, dynamic>{
            'groupIds': FieldValue.arrayRemove(toForget),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      AppLog.w('No se pudo limpiar la lista de grupos.');
    }

    if (toForget.contains(ref.read(activeGroupIdOverrideProvider))) {
      switchActiveGroup(ref, null);
    }
  }

  if (!context.mounted) return;

  String nameOf(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (snap.id == personalGroupId) return 'Mi diario';
    final String raw = (snap.data()?['name'] as String?)?.trim() ?? '';
    return raw.isEmpty ? 'Diario' : raw;
  }

  // ORDEN FIJO.
  //
  // La lista se pintaba en el orden en que iban contestando las lecturas de
  // Firestore, que depende de la red: los mismos cinco diarios salían en un
  // orden distinto en cada apertura, y "Mi diario" tan pronto era el primero
  // como el último. Una lista que se recoloca sola no se puede aprender: hay
  // que leerla entera cada vez, y eso es exactamente la sensación de "no me
  // aclaro con los grupos".
  //
  // Ahora: el diario personal primero —lo tiene todo el mundo y es el único
  // que no se puede perder— y el resto por orden alfabético.
  valid.sort((
    DocumentSnapshot<Map<String, dynamic>> a,
    DocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final bool aPersonal = a.id == personalGroupId;
    final bool bPersonal = b.id == personalGroupId;
    if (aPersonal != bPersonal) return aPersonal ? -1 : 1;
    return nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase());
  });

  // El que estás viendo sale arriba del todo y en su propia tarjeta; los
  // demás, debajo, bajo un rótulo que dice literalmente qué pasa si los
  // tocas. Antes todos eran la misma fila gris con un punto, y el activo se
  // distinguía por un círculo relleno de 20 píxeles: la respuesta a "¿dónde
  // estoy?" no puede depender de comparar dos iconos casi iguales.
  final List<DocumentSnapshot<Map<String, dynamic>>> others = valid
      .where((DocumentSnapshot<Map<String, dynamic>> s) => s.id != activeGroupId)
      .toList();
  final int activeIndex = valid.indexWhere(
    (DocumentSnapshot<Map<String, dynamic>> s) => s.id == activeGroupId,
  );

  await showModalBottomSheet<void>(
    context: context,
    // El shell pinta el dock por encima del contenido dentro de su propio
    // Stack (ver main.dart); un sheet en el Navigator anidado quedaría por
    // debajo. El Navigator raíz lo pinta por encima de todo.
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    // DESPLAZABLE Y ACOTADO. La lista no cabía: con cinco diarios el panel se
    // desbordaba por abajo —la cinta amarilla y negra de Flutter— y las
    // acciones del final quedaban fuera de la pantalla, sin forma de llegar a
    // ellas porque la columna no se podía desplazar. El número de grupos de
    // un usuario no tiene techo, así que la altura tampoco puede darse por
    // supuesta.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheetContext) {
      void openPeople(DocumentSnapshot<Map<String, dynamic>> snap) {
        Navigator.pop(sheetContext);
        openGroupMembersSheet(
          context,
          ref,
          groupId: snap.id,
          groupData: snap.data() ?? const <String, dynamic>{},
        );
      }

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  // "Diarios" en todas partes. La app los llamaba "grupos"
                  // aquí y "diarios" en el resto de pantallas: dos palabras
                  // para la misma cosa obligan a deducir que son la misma.
                  'Tus diarios',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // Una frase. Ningún sitio de la app explicaba qué es un
                  // diario, así que la palabra había que deducirla del
                  // contexto —y el contexto era una lista de nombres—.
                  'Cada diario guarda sus propios platos, su mapa y su ruleta. '
                  'Cambias de uno a otro cuando quieras.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                if (activeIndex >= 0) ...<Widget>[
                  const _SheetLabel('Estás viendo'),
                  const SizedBox(height: 8),
                  _ActiveGroupCard(
                    name: nameOf(valid[activeIndex]),
                    memberCount:
                        (valid[activeIndex].data()?['members'] as List<dynamic>?)
                            ?.length ??
                        1,
                    isPersonal:
                        valid[activeIndex].id == personalGroupId ||
                        valid[activeIndex].data()?['isPersonal'] == true,
                    onManage: () => openPeople(valid[activeIndex]),
                  ),
                ],
                if (others.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  // El rótulo dice qué hace tocar una fila. Sin él, una lista
                  // de nombres podía ser un menú, un informe o un selector:
                  // el usuario no tenía forma de saberlo antes de pulsar.
                  const _SheetLabel('Cambiar a'),
                  const SizedBox(height: 4),
                  // ── LA LISTA SE FORMA, NO APARECE DE UNA PIEZA ──
                  //
                  // Esta hoja es la única de la app donde se ve QUÉ diarios
                  // tienes, y aparecía entera de golpe, como un cartel que se
                  // enciende. Con el escalón, la lista se lee como una lista:
                  // el ojo la recorre de arriba abajo en el mismo orden en
                  // que va a tener que elegir.
                  //
                  // Son cinco o seis filas, no doscientas, así que cada una
                  // puede traerse su propio reloj (ver MotionItem).
                  for (final MapEntry<int, DocumentSnapshot<Map<String, dynamic>>> entrada
                      in others.asMap().entries)
                    MotionItem(
                      index: entrada.key,
                      child: _GroupTile(
                        name: nameOf(entrada.value),
                        memberCount:
                            (entrada.value.data()?['members'] as List<dynamic>?)
                                ?.length ??
                            1,
                        isPersonal:
                            entrada.value.id == personalGroupId ||
                            entrada.value.data()?['isPersonal'] == true,
                        onTap: () {
                          switchActiveGroup(ref, entrada.value.id);
                          Navigator.pop(sheetContext);
                        },
                        onManage: () => openPeople(entrada.value),
                      ),
                    ),
                ],
                const SizedBox(height: 22),
                // Dos filas, no una. "Compartir con alguien más" mezclaba tres
                // acciones distintas —invitar a tu grupo, entrar en el de otro
                // y crear uno nuevo— bajo una etiqueta que no es ninguna de
                // las tres. Quien había recibido un código no se le ocurría
                // que "compartir" fuera el sitio donde meterlo.
                //
                // Y ya no se pintan con la misma fila que los diarios: antes
                // "Entrar con un código" era un `_GroupTile` con el contador
                // de personas a cero, así que se leía como un diario más de
                // la lista. Un botón de acción no puede parecer un dato.
                const _SheetLabel('Añadir un diario'),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.login_rounded,
                  title: kEntrarConCodigo,
                  subtitle: 'Si alguien te ha pasado uno para entrar en su diario',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/household-setup?mode=join');
                  },
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.group_add_rounded,
                  title: 'Crear un diario compartido',
                  subtitle: 'Para apuntar platos junto a quien tú invites',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/household-setup');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Panel de miembros de un grupo, con salir/expulsar.
Future<void> openGroupMembersSheet(
  BuildContext context,
  WidgetRef ref, {
  required String groupId,
  required Map<String, dynamic> groupData,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheetContext) => _MembersSheet(
      groupId: groupId,
      groupName: (groupData['name'] as String?) ?? 'Diario',
      isPersonal: groupData['isPersonal'] == true,
      createdBy: groupData['createdBy'] as String?,
      initialMembers:
          (groupData['members'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      memberProfiles:
          (groupData['memberProfiles'] as Map<dynamic, dynamic>?)
              ?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      // Las fotos ya venían en este mismo documento y esta hoja las
      // ignoraba: enseñaba tres iconos grises idénticos donde hay tres
      // personas distintas. Es la pantalla de «quién está aquí» — no
      // reconocer a nadie en ella es justo lo contrario de lo que promete.
      profileImages:
          (groupData['profileImages'] as Map<dynamic, dynamic>?)
              ?.map(
                (dynamic k, dynamic v) =>
                    MapEntry<String, String>(k.toString(), v.toString()),
              ) ??
          const <String, String>{},
    ),
  );
}

/// La cara de un miembro en la lista de «quién está aquí».
///
/// Enseñaba un icono gris para todo el mundo, aunque las fotos estuvieran
/// ahí mismo, en el documento del grupo que la hoja ya lee. Tres personas
/// distintas se veían como tres siluetas iguales.
///
/// Sin foto no se pinta la silueta: se pinta **la inicial**. Una silueta no
/// distingue a nadie; una letra sí, y además dice quién es sin leer el
/// nombre. Es lo que hacen Mensajes y Contactos cuando no hay foto.
class _CaraDeMiembro extends StatelessWidget {
  const _CaraDeMiembro({required this.url, required this.nombre});

  final String? url;
  final String nombre;

  static const double _lado = 32;

  @override
  Widget build(BuildContext context) {
    final String limpio = nombre.trim();
    // `runes.first` y no `substring(0, 1)`: un nombre que empiece por emoji
    // o por una letra fuera del plano básico ocupa dos unidades UTF-16, y
    // cortar por la primera devuelve media letra —un rombo con un
    // interrogante—.
    final String inicial = limpio.isEmpty
        ? '?'
        : String.fromCharCode(limpio.runes.first).toUpperCase();

    return Container(
      width: _lado,
      height: _lado,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.tintPrimary,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.textPrimary,
          width: AppBorder.thin,
        ),
      ),
      child: (url == null || url!.isEmpty)
          ? Text(
              inicial,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            )
          // `width` en dp: `SmartImage` lo multiplica por la densidad real y
          // le pide a Cloudinary una versión de ese tamaño, en vez de bajar
          // la foto de cámara entera para pintarla a 32 puntos.
          : SmartImage(
              imagePath: url,
              width: _lado.round(),
              fit: BoxFit.cover,
              semanticLabel: 'Foto de $limpio',
            ),
    );
  }
}

/// Lista de miembros de un grupo con acciones de salir/expulsar. Es
/// `Stateful` para poder quitar una fila al instante tras expulsar a alguien,
/// sin esperar a que el stream del grupo se vuelva a leer.
class _MembersSheet extends ConsumerStatefulWidget {
  const _MembersSheet({
    required this.groupId,
    required this.groupName,
    required this.isPersonal,
    required this.createdBy,
    required this.initialMembers,
    required this.memberProfiles,
    required this.profileImages,
  });

  final String groupId;
  final String groupName;
  final bool isPersonal;
  final String? createdBy;
  final List<String> initialMembers;
  final Map<String, dynamic> memberProfiles;

  /// Foto de perfil de cada miembro, por uid. Sale del mismo documento del
  /// grupo, así que no cuesta ni una lectura más.
  final Map<String, String> profileImages;

  @override
  ConsumerState<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends ConsumerState<_MembersSheet> {
  final List<String> _members = <String>[];
  String? _busyUid;

  /// El nombre vive en el estado para que un cambio se vea al instante en
  /// esta misma hoja, sin cerrarla y volver a abrirla.
  late String _name;

  @override
  void initState() {
    super.initState();
    _members.addAll(widget.initialMembers);
    _name = widget.groupName;
  }

  /// Cambiar el nombre del diario.
  ///
  /// No se podía. Un diario se llamaba para siempre como lo hubieras escrito
  /// el día que lo creaste —«Prueba», «Prueba grupo»— y la única salida era
  /// salirte y crear otro, perdiendo por el camino a la gente que ya estaba
  /// dentro. Las reglas de Firestore ya permitían el cambio; lo que faltaba
  /// era el sitio donde pedirlo.
  Future<void> _promptRename() async {
    final TextEditingController controller = TextEditingController(text: _name);

    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Nombre del diario'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: FieldLimits.nombreDiario,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Cenas con los amigos',
            counterText: '',
          ),
          onSubmitted: (String v) =>
              Navigator.pop(dialogContext, v.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(
              'Guardar',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    // Después del fotograma, no aquí: `showDialog` completa su future en el
    // `Navigator.pop`, no cuando acaba la animación de salida, así que el
    // `TextField` de arriba sigue montado y apuntando a este controlador.
    // Liberarlo ya provoca "A TextEditingController was used after being
    // disposed" al desmontarse el foco del diálogo. (El mismo fallo estaba
    // en el diálogo de cambiar tu nombre, en profile_page.dart.)
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (newName == null || newName.isEmpty || newName == _name) return;

    // Optimista: el nombre nuevo se ve ya. Si el servidor lo rechaza se
    // vuelve atrás y se dice por qué, en vez de dejar la hoja congelada.
    final String previous = _name;
    setState(() => _name = newName);

    try {
      await ref
          .read(householdServiceProvider)
          .renameGroup(groupId: widget.groupId, name: newName);
    } catch (e, st) {
      AppLog.e('No se pudo renombrar el diario', e, st);
      if (!mounted) return;
      setState(() => _name = previous);
      _showError('No se pudo cambiar el nombre. Inténtalo de nuevo.');
    }
  }

  String _nameFor(String uid) {
    final Map<String, dynamic>? profile =
        widget.memberProfiles[uid] as Map<String, dynamic>?;
    final String? name = (profile?['displayName'] as String?)?.trim();
    return name?.isNotEmpty == true ? name! : AuthService.unnamedMember;
  }

  Future<void> _confirmAndRun({
    required String title,
    required String content,
    required String confirmLabel,
    required Future<void> Function() action,
    required String uid,
    required bool isLeaving,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              confirmLabel,
              style: GoogleFonts.inter(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busyUid = uid);

    try {
      await action();

      if (!mounted) return;

      setState(() => _members.remove(uid));

      // Al salir del grupo que estabas viendo, nadie reseteaba el override:
      // todos los streams (recuerdos, mapa, gamer) pasaban a
      // `permission-denied` y la app se quedaba en blanco cargando para
      // siempre.
      if (isLeaving && ref.read(activeGroupIdProvider) == widget.groupId) {
        switchActiveGroup(ref, null);
      }

      if (isLeaving && mounted) Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      AppLog.w('Acción sobre miembros fallida: ${e.code}');
      _showError(
        e.code == 'permission-denied'
            ? 'No tienes permiso para hacer eso en este diario.'
            : 'No se pudo completar la acción. Comprueba tu conexión.',
      );
    } catch (e, st) {
      if (!mounted) return;
      AppLog.e('Acción sobre miembros fallida', e, st);
      _showError('No se pudo completar la acción. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  void _showError(String message) {
    AppFeedback.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final String? myUid = ref.watch(currentUidProvider);

    // Quien creó el grupo puede expulsar. Si el creador ya no es miembro
    // (se fue), el grupo quedaba ingobernable: nadie volvía a ver el botón
    // de expulsar nunca más. Ahora, en ese caso, puede cualquier miembro —
    // y `firestore.rules` aplica exactamente el mismo criterio, así que no
    // es solo cosmético como antes.
    final bool creatorPresent =
        widget.createdBy != null && _members.contains(widget.createdBy);
    final bool canModerate =
        myUid != null && (myUid == widget.createdBy || !creatorPresent);

    final householdService = ref.read(householdServiceProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // El nombre del diario, tal cual y en grande. Antes ponía
            // «Miembros de «X»»: tres palabras de andamiaje delante del
            // único dato que importa, y comillas dentro de comillas.
            Text(
              widget.isPersonal ? 'Mi diario' : _name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            // Lo que dice esta línea depende de lo que se pueda hacer aquí
            // de verdad. El caso de estar solo no lo cubría ninguna de las
            // tres frases: decía "puedes quitar a quien ya no deba estar"
            // en un diario donde no hay nadie a quien quitar, y se callaba
            // lo único que sí se puede hacer, que es eliminarlo.
            Text(
              widget.isPersonal
                  ? 'Tu diario personal es solo tuyo: no se puede compartir '
                        'ni invitar a nadie.'
                  : _members.length == 1 && _members.first == myUid
                  ? 'Estás tú solo en este diario. Puedes invitar a alguien '
                        'con un código, cambiarle el nombre o eliminarlo.'
                  : canModerate
                  ? 'Puedes invitar a más gente o quitar a quien ya no '
                        'deba estar.'
                  : 'Solo quien creó el diario puede quitar a otras '
                        'personas.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (_members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No se ha podido cargar la lista de miembros.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _members.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String uid = _members[index];
                    final String name = _nameFor(uid);
                    final bool isMe = uid == myUid;

                    return MotionItem(
                      index: index,
                      child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          _CaraDeMiembro(
                            url: widget.profileImages[uid],
                            nombre: name,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  isMe ? '$name (tú)' : name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (uid == widget.createdBy)
                                  Text(
                                    'Creó el diario',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_busyUid == uid)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          // ══ SALIR Y BORRAR NO SON LO MISMO ══
                          //
                          // Y la app llamaba "Salir" a las dos cosas.
                          //
                          // `leaveGroup` borra el diario entero cuando quien
                          // se va es el último que queda —tiene que hacerlo:
                          // un diario sin miembros no lo puede leer, borrar
                          // ni reclamar nadie—. Pero el botón decía "Salir" y
                          // el aviso remataba con «Podrás volver a unirte si
                          // alguien te invita de nuevo», que en ese caso es
                          // **exactamente lo contrario de lo que pasa**: no
                          // queda nadie para invitarte y no queda diario al
                          // que volver. Los recuerdos, las fotos, el mapa y
                          // los puntos se van con él.
                          //
                          // Aquí está la otra mitad de "no se puede borrar un
                          // diario": sí se podía, pero la única forma era
                          // pulsar un botón que prometía no borrar nada.
                          else if (isMe && !widget.isPersonal)
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                foregroundColor: _members.length == 1
                                    ? AppColors.error
                                    : null,
                              ),
                              onPressed: () => _confirmAndRun(
                                uid: uid,
                                isLeaving: true,
                                title: _members.length == 1
                                    ? '¿Eliminar «$_name»?'
                                    : 'Salir del diario',
                                content: _members.length == 1
                                    ? 'Eres la única persona en este '
                                          'diario, así que al salir '
                                          'desaparece: se borran sus '
                                          'recuerdos, sus fotos, sus '
                                          'sitios del mapa y sus puntos. '
                                          'No se puede deshacer.'
                                    : 'Dejarás de ver y compartir '
                                          'contenido con «$_name». El '
                                          'diario sigue existiendo para '
                                          'los demás, y podrás volver a '
                                          'unirte si alguien te invita de '
                                          'nuevo.',
                                confirmLabel: _members.length == 1
                                    ? 'Eliminar'
                                    : 'Salir',
                                action: () => householdService.leaveGroup(
                                  groupId: widget.groupId,
                                  uid: uid,
                                ),
                              ),
                              child: Text(
                                _members.length == 1 ? 'Eliminar' : 'Salir',
                              ),
                            )
                          else if (!isMe && canModerate)
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () => _confirmAndRun(
                                uid: uid,
                                isLeaving: false,
                                title: 'Quitar a $name',
                                content:
                                    '$name dejará de tener acceso a '
                                    '«$_name» y a su contenido '
                                    'compartido.',
                                confirmLabel: 'Quitar',
                                action: () => householdService.removeMember(
                                  groupId: widget.groupId,
                                  targetUid: uid,
                                ),
                              ),
                              child: const Text('Quitar'),
                            ),
                        ],
                      ),
                      ),
                    );
                  },
                ),
              ),
            if (!widget.isPersonal) ...<Widget>[
              const Divider(height: 24),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: AppColors.textPrimary,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/invite-partner', extra: widget.groupId);
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Invitar a alguien con un código'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: AppColors.textPrimary,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: _promptRename,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Cambiar el nombre del diario'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rótulo de sección de la hoja. Existe para que cada bloque diga en voz
/// alta qué es, en vez de dejar que se deduzca del orden.
class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// El diario que estás viendo ahora mismo, en su propia tarjeta.
///
/// No es pulsable a propósito: ya estás dentro, y una fila que no hace nada
/// al tocarla es peor que una que no invita a tocarse. Lo único accionable
/// es «Personas».
class _ActiveGroupCard extends StatelessWidget {
  const _ActiveGroupCard({
    required this.name,
    required this.memberCount,
    required this.isPersonal,
    required this.onManage,
  });

  final String name;
  final int memberCount;
  final bool isPersonal;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final String who = isPersonal
        ? 'Privado — solo tú'
        : memberCount <= 1
        ? 'Solo tú de momento'
        : 'Tú y ${memberCount - 1} '
              '${memberCount - 1 == 1 ? 'persona' : 'personas'}';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        // Tinte opaco, no `primary.withValues(...)`: la sombra dura se pinta
        // ANTES del fondo, así que cualquier transparencia deja subir el
        // navy por debajo y el texto se queda ilegible (ver `AppColors`).
        color: AppColors.tintPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.textPrimary,
          width: AppBorder.normal,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.textPrimary,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Igual que en la lista: el diario personal no tiene personas
          // que gestionar.
          if (!isPersonal) _PeopleButton(groupName: name, onTap: onManage),
        ],
      ),
    );
  }
}

/// Botón «Personas» con su nombre escrito, no un menú de tres puntos.
///
/// El "..." era exactamente lo que la gente no encontraba: para ver quién
/// está en un diario —o para quitar a alguien, o para cambiarle el nombre—
/// había que adivinar que se escondía ahí dentro. Un icono de tres puntos no
/// promete nada, así que nadie lo pulsa.
class _PeopleButton extends StatelessWidget {
  const _PeopleButton({required this.groupName, required this.onTap});

  final String groupName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Personas de $groupName',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          // 44x44 reales, el mínimo táctil de iOS.
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.group_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(height: 2),
                Text(
                  'Personas',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una fila de la lista «Cambiar a».
///
/// Ya no lleva radio button. El círculo relleno/vacío es el control de un
/// formulario: promete que hay que elegir uno y confirmar después. Aquí no
/// hay confirmación —tocar cambia el diario y cierra la hoja— así que la
/// flecha es más honesta, y además el activo ya no está en esta lista.
class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.name,
    required this.isPersonal,
    required this.memberCount,
    required this.onTap,
    required this.onManage,
  });

  final String name;
  final bool isPersonal;
  final int memberCount;
  final VoidCallback onTap;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            button: true,
            label: 'Cambiar al diario $name',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: onTap,
              child: ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        isPersonal
                            ? Icons.lock_outline_rounded
                            : Icons.menu_book_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              isPersonal
                                  ? 'Privado'
                                  : '$memberCount '
                                        '${memberCount == 1 ? 'persona' : 'personas'}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // El diario personal no tiene a nadie más dentro: un botón de
        // «Personas» ahí solo sirve para abrir una hoja que dice que no se
        // puede compartir.
        if (!isPersonal) _PeopleButton(groupName: name, onTap: onManage),
      ],
    );
  }
}

/// Fila de acción: entrar con un código, crear un diario. Con su explicación
/// de una línea, porque «entrar con un código» no dice de dónde sale el
/// código ni quién lo tiene.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppBorder.thin,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 20, color: AppColors.textPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          height: 1.3,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
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
    );
  }
}
