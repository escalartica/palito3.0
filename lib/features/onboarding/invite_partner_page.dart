import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/household_provider.dart';
import '../../core/theme/tokens/app_colors.dart';

/// Muestra un código de invitación recién generado para el grupo
/// [groupId]. Se llega aquí justo después de crear un grupo, o desde el
/// selector de grupo para invitar a alguien más a uno ya existente —
/// siempre con el grupo explícito, nunca resuelto de forma ambigua (un
/// usuario puede pertenecer a varios a la vez).
class InvitePartnerPage extends ConsumerStatefulWidget {
  const InvitePartnerPage({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<InvitePartnerPage> createState() => _InvitePartnerPageState();
}

class _InvitePartnerPageState extends ConsumerState<InvitePartnerPage> {
  String? _code;
  String? _errorMessage;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateCode());
  }

  Future<void> _generateCode() async {
    final String? uid = ref.read(currentUidProvider);

    if (uid == null) {
      setState(() => _errorMessage = 'No se pudo determinar tu cuenta.');
      return;
    }

    try {
      final String code = await ref.read(householdServiceProvider).createInvite(
            groupId: widget.groupId,
            createdBy: uid,
          );

      if (!mounted) return;
      setState(() => _code = code);
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo generar el código. Comprueba tu conexión.';
      });
    }
  }

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!));
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
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
                'Pásale este código — lo introducirá al abrir la app '
                'por primera vez. Caduca en 7 días.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(color: AppColors.error),
                )
              else if (_code == null)
                const Center(child: CircularProgressIndicator())
              else
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.textPrimary,
                            width: 2.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.textPrimary,
                              blurRadius: 0,
                              offset: Offset(4, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _code!,
                          style: GoogleFonts.outfit(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 10,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _copyCode,
                        icon: Icon(
                          _copied
                              ? Icons.check_rounded
                              : Icons.copy_rounded,
                        ),
                        label: Text(_copied ? 'Copiado' : 'Copiar código'),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Continuar',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
