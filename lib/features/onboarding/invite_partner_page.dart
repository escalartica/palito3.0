import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/household_provider.dart';
import '../../core/theme/components/neo_header.dart';
import '../../core/theme/tokens/app_colors.dart';

/// Muestra un código de invitación recién generado para el grupo [groupId].
/// Se llega aquí justo después de crear un grupo, o desde Perfil para invitar
/// a alguien más a uno ya existente — siempre con el grupo explícito, nunca
/// resuelto de forma ambigua (un usuario puede pertenecer a varios a la vez).
class InvitePartnerPage extends ConsumerStatefulWidget {
  const InvitePartnerPage({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<InvitePartnerPage> createState() => _InvitePartnerPageState();
}

class _InvitePartnerPageState extends ConsumerState<InvitePartnerPage> {
  static const Duration _validFor = Duration(days: 7);

  String? _code;
  String? _errorMessage;
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateCode());
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateCode() async {
    final String? uid = ref.read(currentUidProvider);

    if (uid == null) {
      // Esta rama se daba con `setState` sin comprobar `mounted`, justo en el
      // frame en el que el router redirige a /sign-in por falta de sesión.
      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudo determinar tu cuenta.');
      return;
    }

    try {
      final String code = await ref
          .read(householdServiceProvider)
          .createInvite(
            groupId: widget.groupId,
            createdBy: uid,
            validFor: _validFor,
          );

      if (!mounted) return;
      setState(() {
        _code = code;
        _errorMessage = null;
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo generar el código. Comprueba tu conexión.';
      });
    }
  }

  /// Mensaje completo, con las instrucciones REALES incluidas. El texto
  /// anterior decía que el invitado introduciría el código "al abrir la app
  /// por primera vez" — ese sitio no existe: hay que ir a Perfil → Grupos →
  /// Unirme con un código. Quien invitaba creía haber hecho su parte y el
  /// invitado no encontraba dónde meterlo.
  String get _shareMessage =>
      'Te invito a mi grupo en Palito de Sabores 🍽️\n\n'
      'Código: $_code\n\n'
      'Descarga la app, inicia sesión con Apple y ve a '
      'Perfil → Grupos → "Unirme con un código".\n'
      'El código caduca en ${_validFor.inDays} días.';

  void _copy({required bool full}) {
    if (_code == null) return;

    Clipboard.setData(ClipboardData(text: full ? _shareMessage : _code!));
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Invita a alguien',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pásale este código. Para usarlo tendrá que abrir la app, '
                'iniciar sesión y entrar en Perfil → Grupos → "Unirme con un '
                'código". Caduca en ${_validFor.inDays} días.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                _ErrorBlock(message: _errorMessage!, onRetry: _generateCode)
              else if (_code == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _CodeBlock(code: _code!),
              const SizedBox(height: 24),
              if (_code != null) ...<Widget>[
                NeoPrimaryButton(
                  label: _copied ? 'Copiado ✓' : 'Copiar invitación completa',
                  icon: _copied ? Icons.check_rounded : Icons.ios_share_rounded,
                  onPressed: () => _copy(full: true),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => _copy(full: false),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar solo el código'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ],
              const SizedBox(height: 8),
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.textPrimary, width: 2.5),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: AppColors.textPrimary,
              blurRadius: 0,
              offset: Offset(4, 4),
            ),
          ],
        ),
        // Un código de 8 caracteres a 40 px con letterSpacing 10 no cabe en un
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
