import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/theme/components/app_feedback.dart';
import '../../core/theme/components/app_motion.dart';
import 'widgets/google_sign_in_button.dart';

/// Pantalla de inicio de sesión. Se muestra cuando el `redirect` de
/// `GoRouter` detecta que no hay sesión iniciada (ver `main.dart`).
///
/// ══ QUÉ BOTONES SALEN EN CADA SISTEMA, Y POR QUÉ ══
///
/// **iPhone**: Apple primero, Google debajo.
/// **Android**: solo Google.
///
/// La app nació solo con Sign in with Apple. En Android eso funciona, pero
/// como una ventana del navegador y pidiendo una cuenta de Apple que casi
/// nadie tiene ahí: publicar en Android sin Google era publicar una app en
/// la que la mayoría no puede ni entrar. De ahí el botón de Google.
///
/// ══ POR QUÉ APPLE NO SALE EN ANDROID (20/09) ══
///
/// Hubo un rato en que sí salía, con este razonamiento: quien se creó la
/// cuenta con Apple en su iPhone y luego se instala la app en un Android
/// tiene que poder volver a SU cuenta, porque sus recuerdos cuelgan de su
/// `uid`. El razonamiento sigue siendo bueno; el botón, no.
///
/// `sign_in_with_apple` en Android NO usa el sistema operativo —no hay tal
/// cosa ahí—: abre una página web de Apple, y para eso hay que pasarle
/// `webAuthenticationOptions` con un Service ID dado de alta en la cuenta de
/// desarrollador de Apple y una dirección de retorno en un dominio
/// verificado. Este código nunca lo pasó, porque se escribió para una app
/// que solo existía en iPhone. Resultado: el botón lanzaba una excepción
/// nada más tocarlo. Se comprobó en un OnePlus el 20/09; lo único que hacía
/// era enseñar «No se pudo añadir, inténtelo de nuevo».
///
/// Un botón que solo sabe fallar es peor que no tener botón: la persona cree
/// que la app está rota.
///
/// ══ CÓMO LLEGA A SU CUENTA ENTONCES QUIEN VIENE DE IPHONE ══
///
/// Añadiendo Google **desde el iPhone** —Perfil → «Añadir Google para
/// entrar»—, donde la identificación de Apple sí es nativa y funciona. Luego
/// entra con Google en el Android y cae en el mismo `uid`, con sus diarios,
/// sus grupos y sus puntos. La línea de texto bajo el botón lo explica, para
/// que nadie se quede mirando la pantalla sin entender por qué no está Apple.
///
/// Si algún día se monta el Service ID y el punto de retorno, el botón vuelve
/// y esta explicación se borra.
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
    // La háptica la dispara `AppFeedback`, en el mismo instante en que se
    // pide el aviso. Aquí había otra justo antes: dos golpecitos seguidos
    // para una sola acción se sienten como un fallo del móvil.
    AppFeedback.success(context, 'Enlace copiado. Pégalo en tu navegador.');
  }

  Future<void> _handleAppleSignIn() async {
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
        // "Inténtalo de nuevo" era un mal consejo, y comprobado en el
        // simulador: sin sesión de Apple en el dispositivo, iOS enseña su
        // propia alerta —"Debes iniciar sesión en tu cuenta de Apple en
        // Ajustes"— y en cuanto la cierras, la app decía que volvieras a
        // intentarlo. Intentarlo otra vez da exactamente la misma alerta,
        // para siempre. La app tenía la explicación delante y la cambiaba
        // por un consejo que no lleva a ninguna parte.
        //
        // Los dos motivos reales por los que esto falla son no tener sesión
        // de Apple en el dispositivo y no tener conexión. El mensaje nombra
        // los dos, porque desde aquí no se pueden distinguir con certeza.
        _errorMessage =
            'No se pudo iniciar sesión con Apple. Comprueba que tienes '
            'sesión iniciada con tu Apple ID en los Ajustes del teléfono y '
            'que hay conexión.';
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      // `signInWithGoogle` devuelve `null` cuando la persona cierra la
      // ventana de Google sin elegir cuenta. No es un error: no se pinta
      // nada, la pantalla se queda como estaba.
      await ref.read(authServiceProvider).signInWithGoogle();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return;
      }

      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo iniciar sesión con Google. Comprueba que hay '
            'conexión e inténtalo de nuevo.';
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

  /// Los dos botones, en el orden que toque, o la rueda mientras se entra.
  ///
  /// Se sustituyen los DOS por una sola rueda a propósito: con un botón
  /// girando y el otro vivo, tocar el segundo mientras el primero está a
  /// medias lanza dos inicios de sesión a la vez, y el segundo pisa al
  /// primero con otra cuenta.
  Widget _buildSignInButtons() {
    if (_isSigningIn) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.textPrimary),
        ),
      );
    }

    // Sin decoración propia (borde/sombra) alrededor del botón oficial de
    // Apple: además de no ser coherente con las guías de Apple para este
    // botón, competía visualmente con su propio estado de "pulsado".
    //
    // Se construye aunque en Android no se pinte: es un widget, no cuesta
    // nada, y así el `return` de abajo se lee de un vistazo.
    final Widget apple = SizedBox(
      height: 52,
      child: SignInWithAppleButton(
        onPressed: _handleAppleSignIn,
        style: SignInWithAppleButtonStyle.black,
        // El botón oficial de Apple, no un componente de marca: se deja
        // fuera de AppRadius a propósito.
        borderRadius: BorderRadius.circular(14),
      ),
    );

    final Widget google = GoogleSignInButton(onPressed: _handleGoogleSignIn);

    // `defaultTargetPlatform` y no `Platform.isIOS`: `dart:io` no existe en
    // web, y además esto sí se puede falsear en las pruebas de widgets.
    final bool esSistemaDeApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    // En Android, solo Google. El porqué está en la cabecera de la clase.
    if (!esSistemaDeApple) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          google,
          const SizedBox(height: 16),
          // No es decoración: sin esta frase, quien se hizo la cuenta en un
          // iPhone abre la app en su Android, no ve Apple por ningún lado y
          // no tiene forma de adivinar qué hacer. Le diría a cualquiera que
          // la app ha perdido sus cosas.
          Text(
            '¿Te hiciste la cuenta en un iPhone con Apple? Entra en el '
            'iPhone, ve a Perfil → «Añadir Google para entrar», y después '
            'podrás entrar aquí con Google en tu misma cuenta.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        apple,
        const SizedBox(height: 12),
        google,
      ],
    );
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
                  // ══ EL LOGO VA SOLO, SIN NADA DETRÁS ══
                  //
                  // Aquí hubo primero un contenedor con fondo blanco, borde y
                  // radio propios. Se quitó porque el PNG YA es una insignia
                  // completa —fondo amarillo, borde negro, esquinas
                  // redondeadas— recortada sobre transparencia: enmarcarla
                  // otra vez la enmarcaba dos veces.
                  //
                  // Quedó una sombra dura suelta, y era el mismo error un piso
                  // más abajo. Un `BoxShadow` sin forma pinta un RECTÁNGULO
                  // macizo del tamaño de la caja de la imagen. La insignia
                  // tiene las esquinas redondeadas, así que ese rectángulo
                  // asomaba por las cuatro esquinas: sobre el panel amarillo
                  // se leía como un fondo oscuro pegado al logo. Y encima era
                  // una sombra de más, porque el propio PNG lleva la suya
                  // dibujada dentro.
                  //
                  // Se vio en el primer arranque en Android, el 20/09. En el
                  // simulador de iPhone pasaba igual y nadie lo había mirado
                  // de cerca — y es la primera pantalla de la app.
                  //
                  // Si algún día se quiere una sombra de verdad aquí, no vale
                  // un `BoxShadow` a secas: tendría que seguir la silueta del
                  // PNG, o el PNG tendría que venir sin su sombra y con una
                  // forma que Flutter pueda recortar.
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 124,
                    // Sin `cacheWidth`, el PNG se descodifica a su tamaño
                    // original en memoria para pintarlo a 124 puntos. 372 =
                    // 124 × 3, el factor de pantalla más alto que hay en un
                    // móvil; por encima de eso solo se gasta memoria que nadie
                    // va a ver.
                    cacheWidth: 372,
                    semanticLabel: 'Logotipo de Palito de Sabores',
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
                // La primera pantalla de la app entraba de una pieza, como
                // un cartel que se enciende. Ahora se coloca de arriba abajo:
                // logo, titular, explicación, botón. Es la primera impresión
                // de Palito y era exactamente igual de estática que un PDF.
                child: MotionColumn(
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
                    _buildSignInButtons(),
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
                        child: PressScale(
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
