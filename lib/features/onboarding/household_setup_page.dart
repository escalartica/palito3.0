import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/household_provider.dart';
import '../../core/theme/tokens/app_colors.dart';

/// Se muestra tras iniciar sesión cuando el usuario todavía no pertenece
/// a ningún hogar (`users/{uid}.householdId == null`) — ver el
/// `redirect` de `GoRouter` en `main.dart`. Ofrece crear un hogar nuevo
/// (y a continuación compartir su código de invitación) o unirse a uno
/// existente con un código que ya tenga.
class HouseholdSetupPage extends ConsumerStatefulWidget {
  const HouseholdSetupPage({super.key});

  @override
  ConsumerState<HouseholdSetupPage> createState() =>
      _HouseholdSetupPageState();
}

enum _Mode { choose, joining }

class _HouseholdSetupPageState extends ConsumerState<HouseholdSetupPage> {
  _Mode _mode = _Mode.choose;
  bool _isBusy = false;
  String? _errorMessage;
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final userDoc = await ref.read(currentUserDocProvider.future);
      final displayName = (userDoc?['displayName'] as String?)?.trim();

      final householdId = await ref.read(householdServiceProvider).createHousehold(
            uid: uid,
            displayName: displayName?.isNotEmpty == true ? displayName! : 'Yo',
          );

      if (!mounted) return;
      context.go('/invite-partner', extra: householdId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo crear el hogar. Comprueba tu conexión e '
            'inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _joinHousehold() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Introduce el código que te han dado.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final userDoc = await ref.read(currentUserDocProvider.future);
      final displayName = (userDoc?['displayName'] as String?)?.trim();

      await ref.read(householdServiceProvider).joinHouseholdWithCode(
            code: code,
            uid: uid,
            displayName: displayName?.isNotEmpty == true ? displayName! : 'Yo',
          );

      // No navegamos a mano: al fijarse users/{uid}.householdId, el
      // `redirect` de GoRouter nos saca solo de esta pantalla.
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo unir al hogar. Comprueba tu conexión e '
            'inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
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
                _mode == _Mode.choose
                    ? '¿Con quién vas a compartir?'
                    : 'Únete a un hogar',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == _Mode.choose
                    ? 'Crea tu propio hogar para invitar a tu pareja '
                        'luego, o únete al suyo si ya te ha pasado un '
                        'código.'
                    : 'Pide el código de invitación a quien quieras '
                        'unirte.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_isBusy)
                const Center(child: CircularProgressIndicator())
              else if (_mode == _Mode.choose)
                _buildChoices()
              else
                _buildJoinForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoices() {
    return Column(
      children: [
        _ActionCard(
          icon: Icons.home_rounded,
          title: 'Crear un hogar nuevo',
          subtitle: 'Empiezas tú sola; invitas a tu pareja después.',
          onTap: _createHousehold,
        ),
        const SizedBox(height: 14),
        _ActionCard(
          icon: Icons.key_rounded,
          title: 'Unirme con un código',
          subtitle: 'Alguien ya te ha invitado a su hogar.',
          onTap: () => setState(() => _mode = _Mode.joining),
        ),
      ],
    );
  }

  Widget _buildJoinForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'CÓDIGO',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.textPrimary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _joinHousehold,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Unirme',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _mode = _Mode.choose),
          child: const Text('Volver'),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.textPrimary, width: 2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.textPrimary,
              blurRadius: 0,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.textPrimary, width: 1.5),
              ),
              child: Icon(icon, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
