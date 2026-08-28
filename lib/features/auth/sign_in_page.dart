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
      body: Column(
        children: [
          // ── Panel superior de marca ──────────────────────────────────
          // A pantalla completa (incluida la barra de estado) en vez de
          // dejar el logo flotando sobre fondo plano — le da al login el
          // mismo peso visual "de marca" que el resto de la app, en vez
          // de sentirse como una pantalla de sistema genérica.
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: AppColors.primary,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.textPrimary,
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.textPrimary,
                          blurRadius: 0,
                          offset: Offset(6, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Contenido ─────────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: Column(
                  children: [
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
                    const Spacer(),
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
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
                      child: _isSigningIn
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.textPrimary,
                              ),
                            )
                          : SignInWithAppleButton(
                              onPressed: _handleSignIn,
                              style: SignInWithAppleButtonStyle.black,
                              borderRadius: BorderRadius.circular(11),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
