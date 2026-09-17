import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/data/invite_policy.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/household_provider.dart';
import '../../core/services/household_service.dart';
import '../../core/theme/components/group_switcher.dart';
import '../../core/theme/components/neo_header.dart';
import '../../core/theme/components/neo_pressable.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/theme/components/app_feedback.dart';
import '../../core/theme/components/app_motion.dart';
import '../../core/theme/components/skeleton.dart';

/// El camino que hay que seguir para canjear un código de invitación.
///
/// ══ ESTE TEXTO SE FUE DE LA REALIDAD, Y EN EL PEOR SITIO POSIBLE ══
///
/// Aquí ponía: tocar «Ver tus diarios y quién está en cada uno». Ese rótulo
/// del Perfil se mejoró hace tiempo —eran once palabras y partía en dos
/// líneas— y este texto se quedó con el viejo. O sea que el mensaje que la
/// gente pega en un grupo de WhatsApp mandaba al invitado a buscar un botón
/// **que no existe**, justo en el momento en que se está estrenando la app y
/// no sabe dónde está nada.
///
/// Había un comentario aquí mismo avisando de que esto tenía que coincidir
/// «PALABRA POR PALABRA» con la pantalla. No sirvió de nada, y no podía
/// servir: un comentario le pide cuidado a quien edita ESTE fichero, y quien
/// renombró el botón estaba editando otro. Ahora las dos etiquetas son
/// constantes compartidas con las pantallas que las pintan (ver
/// `group_switcher.dart`), así que renombrar una cambia también lo que se
/// copia.
///
/// Y ya no se nombra el botón del Perfil, sino el titular que lleva encima:
/// el rótulo del botón **cambia según cuántos diarios tengas**, así que quien
/// acaba de instalar la app lee «Solo tienes tu diario privado» — que no se
/// parece a nada de lo que se pudiera escribir aquí. El titular no cambia.
///
/// Es público a propósito: `test/mensaje_invitacion_test.dart` comprueba que
/// nombra rótulos que existen de verdad.
const String kComoCanjear =
    'abrir la app, iniciar sesión, ir a la pestaña Perfil, tocar el botón '
    'amarillo que hay debajo de "$kSeccionTusDiarios" y ahí '
    '"$kEntrarConCodigo"';

/// ===========================================================================
/// INVITAR A UN GRUPO
/// ===========================================================================
///
/// Se llega aquí justo después de crear un grupo, o desde la hoja de diarios
/// para invitar a alguien más a uno ya existente — siempre con el grupo
/// explícito, nunca resuelto de forma ambigua (un usuario puede pertenecer a
/// varios a la vez).
///
/// QUÉ CAMBIÓ Y POR QUÉ. Esta pantalla generaba un código NUEVO y DE UN SOLO
/// USO cada vez que se abría. Las dos cosas estaban mal para lo que la gente
/// hace de verdad con un código de invitación, que es pegarlo en un grupo de
/// WhatsApp:
///
///   · De un solo uso: entraba el primero que lo tocaba y los demás recibían
///     "Ese código ya se ha usado". Quien invitaba no se enteraba nunca.
///   · Nuevo en cada visita: el código que ya habías mandado seguía siendo
///     válido, pero la app te enseñaba otro distinto. Dos códigos vivos, y
///     ninguna pantalla para verlos ni anularlos.
///
/// Ahora el código es UNO, dura mientras sirva, dice para cuánta gente vale y
/// hasta cuándo, y se puede anular a mano. La lógica de "cuál enseñar" está
/// en [InvitePolicy], con pruebas.
/// ===========================================================================
class InvitePartnerPage extends ConsumerStatefulWidget {
  const InvitePartnerPage({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<InvitePartnerPage> createState() => _InvitePartnerPageState();
}

class _InvitePartnerPageState extends ConsumerState<InvitePartnerPage> {

  InviteSummary? _invite;
  String? _errorMessage;
  bool _isWorking = false;
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final String? uid = ref.read(currentUidProvider);

    if (uid == null) {
      // Esta rama se daba con `setState` sin comprobar `mounted`, justo en el
      // frame en el que el router redirige a /sign-in por falta de sesión.
      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudo determinar tu cuenta.');
      return;
    }

    setState(() {
      _isWorking = true;
      _errorMessage = null;
    });

    try {
      final InviteSummary invite = await ref
          .read(householdServiceProvider)
          .ensureInvite(groupId: widget.groupId, createdBy: uid);

      if (!mounted) return;
      setState(() {
        _invite = invite;
        _errorMessage = null;
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo preparar el código. Comprueba tu conexión.';
      });
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _regenerate() async {
    final String? uid = ref.read(currentUidProvider);
    if (uid == null || _isWorking) return;

    final bool confirmed = await _confirmRegenerate();
    if (!confirmed || !mounted) return;

    setState(() {
      _isWorking = true;
      _errorMessage = null;
    });

    try {
      final InviteSummary invite = await ref
          .read(householdServiceProvider)
          .replaceInvite(
            groupId: widget.groupId,
            createdBy: uid,
            previousCode: _invite?.code,
          );

      if (!mounted) return;
      setState(() {
        _invite = invite;
        _copied = false;
      });
        AppFeedback.success(
          context,
          'Código nuevo listo. El anterior ya no sirve.',
        );
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo generar otro código. Comprueba tu conexión.';
      });
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<bool> _confirmRegenerate() async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '¿Generar otro código?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'El código actual dejará de funcionar al momento. Quien ya esté '
          'dentro del diario se queda dentro; solo deja de servir para '
          'entrar.',
          style: GoogleFonts.inter(height: 1.45),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generar otro'),
          ),
        ],
      ),
    );

    return answer ?? false;
  }

  String get _shareMessage =>
      'Te invito a mi diario en Palito de Sabores 🍽️\n\n'
      'Código: ${_invite?.code}\n\n'
      'Descarga la app y para usarlo tendrás que $kComoCanjear.\n'
      '${_expiryLine(capitalized: true)}.';

  String _expiryLine({bool capitalized = false}) {
    final InviteSummary? invite = _invite;
    if (invite == null) return '';

    final String text = InvitePolicy.describe(invite.life, DateTime.now());
    if (!capitalized) return text;

    return text[0].toUpperCase() + text.substring(1);
  }

  void _copy({required bool full}) {
    final InviteSummary? invite = _invite;
    if (invite == null) return;

    Clipboard.setData(
      ClipboardData(text: full ? _shareMessage : invite.code),
    );
    HapticFeedback.selectionClick();

    setState(() => _copied = true);

    // Antes `_copied` se quedaba en true para siempre: el botón se congelaba
    // en "Copiado" y un segundo toque no daba ninguna señal.
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final InviteSummary? invite = _invite;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NeoHeader(
        title: 'Invitar',
        onBack: () => context.canPop() ? context.pop() : context.go('/'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: MotionColumn(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Invita a quien quieras',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pásales este código: sirve para varias personas, así que '
                'puedes pegarlo en un grupo. Para usarlo tendrán que '
                '$kComoCanjear.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              if (_errorMessage != null)
                _ErrorBlock(message: _errorMessage!, onRetry: _load)
              else if (invite == null)
                // El hueco con la forma del código que viene, no un
                // indicador girando en mitad de la nada: así, cuando llega,
                // ocupa un sitio que ya estaba ocupado y la pantalla no
                // pega el salto. Las medidas salen de `_CodeBlock`.
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Skeleton(width: 220, height: 78, radius: AppRadius.lg),
                  ),
                )
              else ...<Widget>[
                _CodeBlock(code: invite.code),
                const SizedBox(height: 12),
                // Las dos únicas cosas que quien invita necesita saber y que
                // antes no aparecían por ninguna parte.
                Text(
                  _expiryLine(capitalized: true),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (invite != null) ...<Widget>[
                NeoPrimaryButton(
                  label: _copied ? 'Copiado ✓' : 'Copiar invitación completa',
                  // `ios_share` es el glifo de COMPARTIR de iOS —la caja con
                  // la flecha—, y este botón no comparte: copia al
                  // portapapeles. Un icono que promete la hoja de compartir
                  // de iOS y abre otra cosa no es un detalle: es la app
                  // diciendo algo que no cumple, en su acción principal.
                  icon: _copied ? Icons.check_rounded : Icons.copy_all_rounded,
                  onPressed: _isWorking ? null : () => _copy(full: true),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _isWorking ? null : () => _copy(full: false),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar solo el código'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: const Size(0, 48),
                  ),
                ),
                const SizedBox(height: 18),
                // Anular el código es lo único que permite cerrar la puerta
                // cuando se ha ido de las manos (un grupo reenviado, una
                // captura publicada). Estaba escrito en el servicio desde
                // hacía tiempo, pero no había ningún sitio desde el que
                // pedirlo.
                NeoActionButton(
                  label: 'Generar un código nuevo',
                  hint: 'El actual dejará de funcionar.',
                  icon: Icons.autorenew_rounded,
                  onTap: _isWorking ? null : _regenerate,
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Listo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.textPrimary,
            width: AppBorder.normal,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: AppColors.textPrimary,
              blurRadius: 0,
              offset: Offset(4, 4),
            ),
          ],
        ),
        // Un código de 8 caracteres a 36 px con letterSpacing 7 no cabe en un
        // iPhone SE. FittedBox lo encoge en vez de desbordar.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Semantics(
            // VoiceOver leía el código con letterSpacing como una palabra
            // ininteligible; deletreado es utilizable.
            label: 'Código de invitación: ${code.split('').join(', ')}',
            child: ExcludeSemantics(
              child: Text(
                code,
                style: GoogleFonts.outfit(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 7,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: AppColors.error, fontSize: 14),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reintentar'),
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
      ],
    );
  }
}
