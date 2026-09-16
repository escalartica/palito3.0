import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';

/// Pantalla de inicio de sesión — único método: Sign in with Apple. Se
/// muestra cuando `GoRouter`'s `redirect` detecta que no hay sesión
/// iniciada (ver `main.dart`).
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  static const String _privacyUrl =
      'https://palito-de-sabores.web.app/privacy.html';

  bool _isSigningIn = false;
  String? _errorMessage;

  void _copyPrivacyUrl() {
    Clipboard.setData(const ClipboardData(text: _privacyUrl));
    HapticFeedback.selectionClick();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Enlace copiado. Pégalo en tu navegador.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

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
                  // Sombra DURA, sin difuminar: es el lenguaje de toda la
                  // app (bordes negros y sombras sólidas desplazadas). La
                  // sombra difuminada anterior era el único elemento de
                  // estilo "material" en una interfaz neobrutalista, y se
                  // notaba: parecía un logo pegado encima de otra app.
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.textPrimary,
                          offset: Offset(6, 6),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 124,
                      // Sin `cacheWidth`, el PNG se descodifica a su tamaño
                      // original en memoria para pintarlo a 124 puntos. 372 =
                      // 124 × 3, el factor de pantalla más alto que hay en un
                      // iPhone; por encima de eso solo se guarda memoria que
                      // nadie va a ver.
                      cacheWidth: 372,
                      semanticLabel: 'Logotipo de Palito de Sabores',
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
              // `SingleChildScrollView`, no un `Column` a pelo: el panel de
              // marca de arriba se lleva un `flex` fijo, así que en un
              // teléfono bajo (o con la letra del sistema ampliada) este
              // contenido puede no caber. Antes de este cambio eso
              // reventaba el layout (`RenderFlex overflowed`); ahora
              // simplemente se desplaza, sin perder nada.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Palito de Sabores',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        height: 1.15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Guarda y comparte tus experiencias gastronómicas '
                      'con quien tú elijas.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // ── Puntos de valor ──────────────────────────────────
                    // Rellenan el espacio con contenido con sentido (no
                    // solo aire) y explican, antes del botón, qué gana el
                    // usuario al entrar — un patrón habitual en pantallas
                    // de login "profesionales".
                    const _ValuePoint(
                      icon: Icons.restaurant_menu_rounded,
                      text: 'Registra tus platos y experiencias favoritas',
                    ),
                    const SizedBox(height: 16),
                    const _ValuePoint(
                      icon: Icons.group_rounded,
                      text: 'Comparte tu diario con quien tú invites',
                    ),
                    const SizedBox(height: 16),
                    const _ValuePoint(
                      icon: Icons.map_rounded,
                      text: 'Ved juntos el mapa de todo lo que habéis probado',
                    ),
                    // `SizedBox`, no `Spacer()`: un hijo con flex necesita
                    // una altura acotada, y el `SingleChildScrollView` de
                    // más arriba le da altura infinita a propósito (ver su
                    // comentario). El hueco fijo se ve igual en pantallas
                    // normales y sigue sin romper el layout en las bajas.
                    const SizedBox(height: 32),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          // Tinte OPACO de la paleta, no el color de error al
                          // 8 %. Una sombra maciza sin difuminar se pinta
                          // ANTES que el fondo: con un fondo semitransparente
                          // la sombra se transparenta a través de él. Además,
                          // el resultado exacto de mezclar dependía de lo que
                          // hubiera detrás, así que el contraste del texto de
                          // error no era una cifra sino una suposición. Este
                          // tinte mide 4,54:1 con el rojo encima.
                          color: AppColors.tintError,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppColors.error,
                            width: AppBorder.thin,
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
                              // El botón oficial de Apple, no un componente de
                              // marca: se deja fuera de AppRadius a propósito.
                              borderRadius: BorderRadius.circular(14),
                            ),
                    ),
                    const SizedBox(height: 14),
                    // La única pantalla de registro de la app no decía nada
                    // sobre la política de privacidad, y es lo primero que
                    // mira App Review en una app que comparte contenido entre
                    // usuarios (guideline 5.1.1).
                    //
                    // Abrirla en el navegador necesitaría `url_launcher`, una
                    // dependencia más. Copiarla no: con un toque, la
                    // dirección está en el portapapeles y se pega en Safari.
                    // Es una frase que hasta ahora había que TECLEAR a mano,
                    // con guiones y todo, así que en la práctica nadie la
                    // leía nunca.
                    Center(
                      child: Semantics(
                        button: true,
                        label:
                            'Copiar la dirección de la política de privacidad',
                        child: GestureDetector(
                          onTap: _copyPrivacyUrl,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text.rich(
                              TextSpan(
                                children: <InlineSpan>[
                                  const TextSpan(
                                    text:
                                        'Al continuar aceptas nuestra política '
                                        'de privacidad.\n',
                                  ),
                                  TextSpan(
                                    text: 'Tocar para copiar el enlace',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
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
        // Amarillo solido con borde negro y sombra dura, igual que las
        // tarjetas del resto de la app. El amarillo al 35 % de opacidad
        // que habia antes no es un color de la paleta: era el unico sitio
        // de la app con un color "aguado", y hacia que la pantalla de
        // entrada —la primera que ve alguien que se descarga la app— no
        // se pareciera a lo que hay dentro.
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.textPrimary,
              width: AppBorder.normal,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: AppColors.textPrimary,
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
