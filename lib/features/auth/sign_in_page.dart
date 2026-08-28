import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/tokens/app_colors.dart';

/// Pantalla de inicio de sesión — único método: Sign in with Apple. Se
/// muestra cuando `GoRouter`'s `redirect` detecta que no hay sesión
/// iniciada (ver `main.dart`).
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  bool _isSigningIn = false;
  String? _errorMessage;

  Future<void> _handleSignIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signInWithApple();
      // No navegamos manualmente: authStateChangesProvider emite el
      // nuevo usuario, el `redirect` de GoRouter reacciona solo.
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // El usuario cerró el diálogo de Apple — no es un error real.
        return;
      }

      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo iniciar sesión con Apple. Inténtalo de nuevo.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo iniciar sesión. Comprueba tu conexión e '
            'inténtalo de nuevo.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
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
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Palito de Sabores',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Guarda y comparte tus experiencias gastronómicas '
                'con quien tú elijas.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 44),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isSigningIn
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.textPrimary,
                        ),
                      )
                    : SignInWithAppleButton(
                        onPressed: _handleSignIn,
                        style: SignInWithAppleButtonStyle.black,
                        borderRadius: BorderRadius.circular(14),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
