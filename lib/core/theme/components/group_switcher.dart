import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../tokens/app_colors.dart';

/// Selector del grupo activo: qué grupo se está viendo/usando ahora mismo
/// en Home/Mapa/Gamer/Perfil. Un toque abre la lista de todos los grupos
/// del usuario (empezando siempre por su diario personal) para cambiar
/// de uno a otro, gestionar sus miembros, o crear/unirse a uno nuevo.
class GroupSwitcher extends ConsumerWidget {
  const GroupSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, dynamic>? activeGroup =
        ref.watch(activeGroupDocProvider).valueOrNull;
    final String? activeGroupId = ref.watch(activeGroupIdProvider);
    final String? personalGroupId = ref.watch(personalGroupIdProvider);

    final String label = activeGroup == null
        ? 'Cargando…'
        : (activeGroupId == personalGroupId
            ? 'Mi diario'
            : (activeGroup['name'] as String?) ?? 'Grupo');

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openSwitcher(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSwitcher(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();

    final List<String> groupIds = ref.read(userGroupIdsProvider);
    final String? personalGroupId = ref.read(personalGroupIdProvider);
    final String? activeGroupId = ref.read(activeGroupIdProvider);
    final String? myUid = ref.read(currentUidProvider);

    // Los datos se cargan bajo demanda, solo al abrir el selector — no
    // hace falta mantener N streams abiertos permanentemente por algo
    // que se consulta ocasionalmente.
    final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait(
      groupIds.map(
        (id) => FirebaseFirestore.instance.collection('groups').doc(id).get(),
      ),
    );

    // Autolimpieza: si alguien nos ha expulsado de un grupo, ese grupo
    // sigue mencionado en nuestro propio `groupIds` (nadie más puede
    // tocarlo — ver la nota de seguridad en firestore.rules) hasta que
    // nuestro propio dispositivo lo detecte, como aquí, y se quite solo
    // de la lista.
    final List<DocumentSnapshot<Map<String, dynamic>>> validSnapshots = [];
    for (final snap in snapshots) {
      final List<String> members =
          (snap.data()?['members'] as List?)?.whereType<String>().toList() ??
              const <String>[];

      if (myUid != null && snap.exists && !members.contains(myUid)) {
        await FirebaseFirestore.instance.collection('users').doc(myUid).set(
          <String, dynamic>{
            'groupIds': FieldValue.arrayRemove(<String>[snap.id]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        if (ref.read(activeGroupIdOverrideProvider) == snap.id) {
          ref.read(activeGroupIdOverrideProvider.notifier).state = null;
        }
        continue;
      }

      validSnapshots.add(snap);
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      // El ShellRoute pinta el AppDock por encima del contenido de cada
      // pantalla dentro de su propio Stack (ver main.dart) — un bottom
      // sheet insertado en el Navigator anidado del shell (por defecto)
      // queda entonces DEBAJO del dock. Usar el Navigator raíz lo pinta
      // por encima de toda la pantalla del shell, dock incluido.
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tus grupos',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                for (final snap in validSnapshots)
                  _GroupTile(
                    name: snap.id == personalGroupId
                        ? 'Mi diario'
                        : (snap.data()?['name'] as String?) ?? 'Grupo',
                    isActive: snap.id == activeGroupId,
                    onTap: () {
                      ref.read(activeGroupIdOverrideProvider.notifier).state =
                          snap.id;
                      Navigator.pop(sheetContext);
                    },
                    // El diario personal (isPersonal: true) no se puede
                    // compartir ni tiene a nadie que gestionar — solo los
                    // grupos reales muestran esos botones.
                    onInvite: snap.data()?['isPersonal'] == true
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            context.push('/invite-partner', extra: snap.id);
                          },
                    onManage: snap.data()?['isPersonal'] == true
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _openMembersSheet(
                              context,
                              ref,
                              groupId: snap.id,
                              groupData: snap.data() ?? const {},
                            );
                          },
                  ),
                const Divider(height: 28),
                _GroupTile(
                  icon: Icons.group_add_rounded,
                  name: 'Compartir con alguien más',
                  isActive: false,
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

  Future<void> _openMembersSheet(
    BuildContext context,
    WidgetRef ref, {
    required String groupId,
    required Map<String, dynamic> groupData,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _MembersSheet(
        groupId: groupId,
        groupName: (groupData['name'] as String?) ?? 'Grupo',
        createdBy: groupData['createdBy'] as String?,
        initialMembers:
            (groupData['members'] as List?)?.whereType<String>().toList() ??
                const <String>[],
        memberProfiles:
            (groupData['memberProfiles'] as Map?)?.cast<String, dynamic>() ??
                const {},
      ),
    );
  }
}

/// Lista de miembros de un grupo con acciones de salir/expulsar. Es
/// `Stateful` (no un simple builder) para poder quitar una fila de la
/// lista al instante tras expulsar a alguien, sin esperar a que el
/// stream del grupo se vuelva a leer.
class _MembersSheet extends ConsumerStatefulWidget {
  const _MembersSheet({
    required this.groupId,
    required this.groupName,
    required this.createdBy,
    required this.initialMembers,
    required this.memberProfiles,
  });

  final String groupId;
  final String groupName;
  final String? createdBy;
  final List<String> initialMembers;
  final Map<String, dynamic> memberProfiles;

  @override
  ConsumerState<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends ConsumerState<_MembersSheet> {
  final List<String> _members = [];
  String? _busyUid;

  @override
  void initState() {
    super.initState();
    _members.addAll(widget.initialMembers);
  }

  String _nameFor(String uid) {
    final profile = widget.memberProfiles[uid] as Map<String, dynamic>?;
    final name = (profile?['displayName'] as String?)?.trim();
    return name?.isNotEmpty == true ? name! : 'Miembro';
  }

  Future<void> _confirmAndRun({
    required String title,
    required String content,
    required String confirmLabel,
    required Future<void> Function() action,
    required String uid,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
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
      if (mounted) setState(() => _members.remove(uid));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo completar la acción. Comprueba tu conexión e '
            'inténtalo de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? myUid = ref.read(currentUidProvider);
    final bool isCreator = myUid != null && myUid == widget.createdBy;
    final householdService = ref.read(householdServiceProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Miembros de "${widget.groupName}"',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            for (final uid in _members)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        uid == myUid ? '${_nameFor(uid)} (tú)' : _nameFor(uid),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (_busyUid == uid)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (uid == myUid)
                      TextButton(
                        onPressed: () => _confirmAndRun(
                          uid: uid,
                          title: 'Salir del grupo',
                          content:
                              'Dejarás de ver y compartir contenido con '
                              '"${widget.groupName}". Podrás volver a '
                              'unirte más adelante si alguien te invita '
                              'de nuevo.',
                          confirmLabel: 'Salir',
                          action: () => householdService.leaveGroup(
                            groupId: widget.groupId,
                            uid: uid,
                          ),
                        ),
                        child: const Text('Salir'),
                      )
                    else if (isCreator)
                      TextButton(
                        onPressed: () => _confirmAndRun(
                          uid: uid,
                          title: 'Expulsar a ${_nameFor(uid)}',
                          content:
                              '${_nameFor(uid)} dejará de tener acceso a '
                              '"${widget.groupName}" y a su contenido '
                              'compartido.',
                          confirmLabel: 'Expulsar',
                          action: () => householdService.removeMember(
                            groupId: widget.groupId,
                            targetUid: uid,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: const Text('Expulsar'),
                      ),
                  ],
                ),
              ),
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
    required this.onTap,
    this.icon,
    this.onInvite,
    this.onManage,
  });

  final String name;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;
  final VoidCallback? onInvite;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon ??
                  (isActive
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded),
              size: 20,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (onManage != null)
              IconButton(
                icon: Icon(
                  Icons.manage_accounts_rounded,
                  size: 19,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Gestionar miembros',
                onPressed: onManage,
              ),
            if (onInvite != null)
              IconButton(
                icon: Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 19,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Invitar a alguien',
                onPressed: onInvite,
              ),
          ],
        ),
      ),
    );
  }
}
