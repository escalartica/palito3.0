import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/household_provider.dart';
import '../../core/theme/tokens/app_colors.dart';

/// Pantalla para compartir el diario con alguien más: crear un grupo nuevo
/// (y a continuación compartir su código de invitación) o unirse a uno
/// existente con un código que ya tenga. Cada persona tiene siempre su
/// propio grupo personal (creado automáticamente al iniciar sesión — ver
/// `AuthService`), así que esta pantalla es opcional y no bloquea nada:
/// se accede a ella desde Perfil, nunca por un `redirect` obligatorio.
class HouseholdSetupPage extends ConsumerStatefulWidget {
  const HouseholdSetupPage({super.key});

  @override
  ConsumerState<HouseholdSetupPage> createState() =>
      _HouseholdSetupPageState();
}

enum _Mode { choose, naming, joining }

class _HouseholdSetupPageState extends ConsumerState<HouseholdSetupPage> {
  _Mode _mode = _Mode.choose;
  bool _isBusy = false;
  String? _errorMessage;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Ponle un nombre a este grupo.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final userDoc = await ref.read(currentUserDocProvider.future);
      final displayName = (userDoc?['displayName'] as String?)?.trim();

      final groupId = await ref.read(householdServiceProvider).createHousehold(
            uid: uid,
            displayName: displayName?.isNotEmpty == true ? displayName! : 'Yo',
            name: name,
          );

      if (!mounted) return;
      context.push('/invite-partner', extra: groupId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo crear el grupo. Comprueba tu conexión e '
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

      if (!mounted) return;
      // A diferencia de antes, unirse a un grupo ya no dispara ningún
      // redirect automático (no hay puerta de onboarding) — hay que
      // volver explícitamente.
      context.pop();
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo unir al grupo. Comprueba tu conexión e '
            'inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String get _title => switch (_mode) {
        _Mode.choose => '¿Con quién vas a compartir?',
        _Mode.naming => 'Ponle un nombre a tu grupo',
        _Mode.joining => 'Únete a un grupo',
      };

  String get _subtitle => switch (_mode) {
        _Mode.choose =>
          'Crea un grupo para invitar a quien quieras, o únete a uno si '
              'ya te han pasado un código. Tu diario personal sigue '
              'siendo solo tuyo.',
        _Mode.naming =>
          'Por ejemplo "Con Marta" o "Amigos del curro" — te ayudará a '
              'distinguirlo cuando tengas varios.',
        _Mode.joining => 'Pide el código de invitación a quien quieras unirte.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
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
              else
                switch (_mode) {
                  _Mode.choose => _buildChoices(),
                  _Mode.naming => _buildNamingForm(),
                  _Mode.joining => _buildJoinForm(),
                },
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
          icon: Icons.group_add_rounded,
          title: 'Crear un grupo nuevo',
          subtitle: 'Le pones nombre e invitas a quien quieras después.',
          onTap: () => setState(() {
            _errorMessage = null;
            _mode = _Mode.naming;
          }),
        ),
        const SizedBox(height: 14),
        _ActionCard(
          icon: Icons.key_rounded,
          title: 'Unirme con un código',
          subtitle: 'Alguien ya te ha invitado a su grupo.',
          onTap: () => setState(() {
            _errorMessage = null;
            _mode = _Mode.joining;
          }),
        ),
      ],
    );
  }

  Widget _buildNamingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Nombre del grupo',
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
          onPressed: _createHousehold,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Crear grupo',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _errorMessage = null;
            _mode = _Mode.choose;
          }),
          child: const Text('Volver'),
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
          onPressed: () => setState(() {
            _errorMessage = null;
            _mode = _Mode.choose;
          }),
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
