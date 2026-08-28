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
          // Proporción más pequeña que el primer intento: un panel de
          // marca demasiado alto con el logo "flotando" en medio de
          // mucho espacio vacío se leía como una pantalla a medio hacer,
          // no como una decisión de diseño.
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: AppColors.primary,
              child: SafeArea(
                bottom: false,
                child: Center(
                  // El propio PNG ya es una insignia completa (esquinas
                  // redondeadas, fondo amarillo, borde) recortada sobre
                  // transparencia — envolverla en OTRO contenedor con su
                  // propio fondo blanco/borde/radio la enmarcaba dos
                  // veces, y el ligero recorte de `BoxFit.contain` (la
                  // imagen no es perfectamente cuadrada) dejaba asomar
                  // ese fondo blanco como un borde feo. Solo una sombra,
                  // sin relleno ni borde propios, para que se note que
                  // "flota" sin duplicar el marco que ya trae la imagen.
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 116,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Contenido ─────────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SizedBox(height: 40),
                    // ── Puntos de valor ──────────────────────────────────
                    // Rellenan el espacio con contenido con sentido (no
                    // solo aire) y explican, antes del botón, qué gana el
                    // usuario al entrar — un patrón habitual en pantallas
                    // de login "profesionales".
                    _ValuePoint(
                      icon: Icons.restaurant_menu_rounded,
                      text: 'Registra tus platos y experiencias favoritas',
                    ),
                    const SizedBox(height: 14),
                    _ValuePoint(
                      icon: Icons.group_rounded,
                      text: 'Comparte tu diario con quien tú invites',
                    ),
                    const SizedBox(height: 14),
                    _ValuePoint(
                      icon: Icons.map_rounded,
                      text: 'Ved juntos el mapa de todo lo que habéis probado',
                    ),
                    const Spacer(),
                    if (_errorMessage != null) ...[
                      Container(
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
                    // Sin decoración propia (borde/sombra) alrededor del
                    // botón oficial: además de no ser coherente con las
                    // guías de Apple para este botón, competía visualmente
                    // con el propio estado de "pulsado" del widget.
                    SizedBox(
                      height: 52,
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
          ),
        ],
      ),
    );
  }
}

class _ValuePoint extends StatelessWidget {
  const _ValuePoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
