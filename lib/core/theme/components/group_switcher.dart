import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_log.dart';
import '../tokens/app_colors.dart';

/// Selector del grupo activo: qué grupo se está viendo/usando ahora mismo en
/// Inicio/Mapa/Gamer/Perfil. Un toque abre la lista de todos los grupos del
/// usuario (empezando siempre por su diario personal) para cambiar de uno a
/// otro, gestionar sus miembros, o crear/unirse a uno nuevo.
class GroupSwitcher extends ConsumerWidget {
  const GroupSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, dynamic>?> activeGroupAsync = ref.watch(
      activeGroupDocProvider,
    );
    final String? activeGroupId = ref.watch(activeGroupIdProvider);
    final String? personalGroupId = ref.watch(personalGroupIdProvider);

    // Antes, un error del stream se mostraba como "Cargando…" para siempre.
    final String label;
    if (activeGroupAsync.hasError) {
      label = 'Sin grupo';
    } else if (activeGroupAsync.isLoading && !activeGroupAsync.hasValue) {
      label = 'Cargando…';
    } else if (activeGroupId == personalGroupId) {
      label = 'Mi diario';
    } else {
      label = (activeGroupAsync.valueOrNull?['name'] as String?) ?? 'Grupo';
    }

    return Semantics(
      button: true,
      label: 'Grupo activo: $label. Toca para cambiar de grupo',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openGroupSwitcher(context, ref),
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.groups_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
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
    } catch (e) {
      AppLog.w('No se pudo limpiar la lista de grupos.');
    }

    if (toForget.contains(ref.read(activeGroupIdOverrideProvider))) {
      ref.read(activeGroupIdOverrideProvider.notifier).state = null;
    }
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    // El shell pinta el dock por encima del contenido dentro de su propio
    // Stack (ver main.dart); un sheet en el Navigator anidado quedaría por
    // debajo. El Navigator raíz lo pinta por encima de todo.
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Tus grupos',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              for (final DocumentSnapshot<Map<String, dynamic>> snap in valid)
                _GroupTile(
                  name: snap.id == personalGroupId
                      ? 'Mi diario'
                      : (snap.data()?['name'] as String?) ?? 'Grupo',
                  memberCount:
                      (snap.data()?['members'] as List<dynamic>?)?.length ?? 1,
                  isPersonal:
                      snap.id == personalGroupId ||
                      snap.data()?['isPersonal'] == true,
                  isActive: snap.id == activeGroupId,
                  onTap: () {
                    ref.read(activeGroupIdOverrideProvider.notifier).state =
                        snap.id;
                    Navigator.pop(sheetContext);
                  },
                  onInvite: () {
                    Navigator.pop(sheetContext);
                    context.push('/invite-partner', extra: snap.id);
                  },
                  onManage: () {
                    Navigator.pop(sheetContext);
                    openGroupMembersSheet(
                      context,
                      ref,
                      groupId: snap.id,
                      groupData: snap.data() ?? const <String, dynamic>{},
                    );
                  },
                ),
              const Divider(height: 28),
              _GroupTile(
                icon: Icons.group_add_rounded,
                name: 'Compartir con alguien más',
                isActive: false,
                isPersonal: true,
                memberCount: 0,
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/household-setup');
                },
              ),
            ],
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
      groupName: (groupData['name'] as String?) ?? 'Grupo',
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
    ),
  );
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
  });

  final String groupId;
  final String groupName;
  final bool isPersonal;
  final String? createdBy;
  final List<String> initialMembers;
  final Map<String, dynamic> memberProfiles;

  @override
  ConsumerState<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends ConsumerState<_MembersSheet> {
  final List<String> _members = <String>[];
  String? _busyUid;

  @override
  void initState() {
    super.initState();
    _members.addAll(widget.initialMembers);
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
        ref.read(activeGroupIdOverrideProvider.notifier).state = null;
      }

      if (isLeaving && mounted) Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      AppLog.w('Acción sobre miembros fallida: ${e.code}');
      _showError(
        e.code == 'permission-denied'
            ? 'No tienes permiso para hacer eso en este grupo.'
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
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
            Text(
              widget.isPersonal
                  ? 'Mi diario'
                  : 'Miembros de «${widget.groupName}»',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isPersonal
                  ? 'Tu diario personal es solo tuyo: no se puede compartir '
                        'ni invitar a nadie.'
                  : canModerate
                  ? 'Puedes invitar a más gente o quitar a quien ya no '
                        'deba estar.'
                  : 'Solo quien creó el grupo puede quitar a otras '
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

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.person_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
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
                                    'Creó el grupo',
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
                          else if (isMe && !widget.isPersonal)
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () => _confirmAndRun(
                                uid: uid,
                                isLeaving: true,
                                title: 'Salir del grupo',
                                content:
                                    'Dejarás de ver y compartir contenido con '
                                    '«${widget.groupName}». Podrás volver a '
                                    'unirte si alguien te invita de nuevo.',
                                confirmLabel: 'Salir',
                                action: () => householdService.leaveGroup(
                                  groupId: widget.groupId,
                                  uid: uid,
                                ),
                              ),
                              child: const Text('Salir'),
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
                                    '«${widget.groupName}» y a su contenido '
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
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/invite-partner', extra: widget.groupId);
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Invitar a alguien con un código'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.name,
    required this.isActive,
    required this.isPersonal,
    required this.memberCount,
    required this.onTap,
    this.icon,
    this.onInvite,
    this.onManage,
  });

  final String name;
  final bool isActive;
  final bool isPersonal;
  final int memberCount;
  final VoidCallback onTap;
  final IconData? icon;
  final VoidCallback? onInvite;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final bool hasMenu = onManage != null || onInvite != null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: <Widget>[
            Icon(
              icon ??
                  (isActive
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded),
              size: 20,
              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (memberCount > 0)
                    Text(
                      isPersonal
                          ? 'Privado'
                          : '$memberCount ${memberCount == 1 ? 'persona' : 'personas'}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            // Un solo menú en vez de dos IconButton de 19 px pegados dentro de
            // una fila que también es pulsable: acertar en "gestionar" y
            // acabar cambiando de grupo activo era facilísimo.
            if (hasMenu)
              PopupMenuButton<String>(
                tooltip: 'Opciones del grupo',
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.textSecondary,
                ),
                onSelected: (String value) {
                  if (value == 'invite') onInvite?.call();
                  if (value == 'manage') onManage?.call();
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  if (!isPersonal && onInvite != null)
                    const PopupMenuItem<String>(
                      value: 'invite',
                      child: Text('Invitar con un código'),
                    ),
                  if (onManage != null)
                    const PopupMenuItem<String>(
                      value: 'manage',
                      child: Text('Ver miembros'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
