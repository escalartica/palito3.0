import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/data/invite_policy.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/household_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/household_service.dart';
import '../../core/theme/components/neo_header.dart';
import '../../core/theme/components/neo_pressable.dart';
import '../../core/theme/tokens/app_colors.dart';
import '../../core/theme/tokens/app_shape.dart';
import '../../core/providers/memory_provider.dart';

/// Pantalla para compartir el diario con alguien más: crear un grupo nuevo (y
/// a continuación compartir su código de invitación) o unirse a uno existente
/// con un código. Cada persona tiene siempre su propio grupo personal, así que
/// esta pantalla es opcional y no bloquea nada.
class HouseholdSetupPage extends ConsumerStatefulWidget {
  const HouseholdSetupPage({super.key, this.initialMode});

  /// Permite entrar directamente en "Unirme con un código" desde el banner de
  /// Inicio, sin obligar al invitado a adivinar el camino.
  final String? initialMode;

  @override
  ConsumerState<HouseholdSetupPage> createState() => _HouseholdSetupPageState();
}

enum _Mode { choose, naming, joining }

class _HouseholdSetupPageState extends ConsumerState<HouseholdSetupPage> {
  late _Mode _mode = widget.initialMode == 'join'
      ? _Mode.joining
      : _Mode.choose;

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

  String _myName() {
    return ref.read(currentDisplayNameProvider) ?? AuthService.unnamedMember;
  }

  Future<void> _createHousehold() async {
    final String? uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Ponle un nombre a este grupo.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final String groupId = await ref
          .read(householdServiceProvider)
          .createHousehold(uid: uid, displayName: _myName(), name: name);

      if (!mounted) return;

      // El grupo recién creado pasa a ser el activo: si no, lo creabas y la
      // app seguía mostrando "Mi diario" como si no hubiera pasado nada.
      switchActiveGroup(ref, groupId);

      context.pushReplacement('/invite-partner', extra: groupId);
    } catch (_) {
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
    final String? uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final String code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Introduce el código que te han dado.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final JoinResult result = await ref
          .read(householdServiceProvider)
          .joinHouseholdWithCode(code: code, uid: uid, displayName: _myName());

      if (!mounted) return;

      // Activar el grupo al que acabas de entrar y DECIRLO. Antes la pantalla
      // se cerraba en silencio y seguías viendo tu diario personal, así que
      // parecía que el código no había funcionado.
      switchActiveGroup(ref, result.groupId);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Ya estás en «${result.groupName}» 🎉'),
            behavior: SnackBarBehavior.floating,
          ),
        );

      context.go('/');
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
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

  void _back() {
    // El botón de volver retrocede DENTRO de la pantalla si estás en un
    // subpaso. Antes te sacaba del todo y había que empezar de cero.
    if (_mode != _Mode.choose) {
      setState(() {
        _mode = _Mode.choose;
        _errorMessage = null;
      });
      return;
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  String get _title => switch (_mode) {
    _Mode.choose => '¿Con quién vas a compartir?',
    _Mode.naming => 'Ponle un nombre a tu grupo',
    _Mode.joining => 'Únete a un grupo',
  };

  String get _subtitle => switch (_mode) {
    _Mode.choose =>
      'Crea un grupo para invitar a quien quieras, o únete a uno si ya te '
          'han pasado un código. Tu diario personal sigue siendo solo tuyo.',
    _Mode.naming =>
      'Por ejemplo "Con Marta" o "Amigos del curro" — te ayudará a '
          'distinguirlo cuando tengas varios.',
    _Mode.joining =>
      'Pide el código a quien te quiera invitar. Son '
          '${InvitePolicy.codeLength} letras y números. Si lo tienes copiado, '
          'toca "Pegar" y ya está.',
  };

  /// El error se borra en cuanto el usuario toca el campo. Antes se quedaba
  /// pegado debajo mientras escribías el código correcto, diciendo que no
  /// existe uno que ya habías corregido.
  void _clearError() {
    if (_errorMessage == null) return;
    setState(() => _errorMessage = null);
  }

  /// Rellena el campo con el código que haya en el portapapeles — sea el
  /// código pelado o el mensaje de invitación entero (ver
  /// [InvitePolicy.codeFromSharedText]).
  ///
  /// Quien recibe una invitación SIEMPRE la tiene copiada: es así como le ha
  /// llegado. Obligarle a teclear ocho caracteres a mano, con un alfabeto que
  /// además esconde la O y el 0, era pedirle que se equivocara.
  Future<void> _pasteCode() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? code = InvitePolicy.codeFromSharedText(data?.text);

    if (!mounted) return;

    if (code == null) {
      setState(() {
        _errorMessage = 'No hay ningún código en el portapapeles.';
      });
      return;
    }

    HapticFeedback.selectionClick();

    _codeController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );

    setState(() => _errorMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NeoHeader(title: 'Grupos', onBack: _isBusy ? null : _back),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          // Sin scroll, al abrir el teclado el contenido no cabía y salía la
          // franja amarilla y negra de overflow.
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
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
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
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
      children: <Widget>[
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
          title: 'Entrar con un código',
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
      children: <Widget>[
        TextField(
          controller: _nameController,
          enabled: !_isBusy,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onChanged: (_) => _clearError(),
          onSubmitted: (_) => _createHousehold(),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          decoration: _fieldDecoration(hint: 'Nombre del grupo'),
        ),
        const SizedBox(height: 16),
        NeoPrimaryButton(
          label: 'Crear grupo',
          isBusy: _isBusy,
          onPressed: _createHousehold,
        ),
      ],
    );
  }

  Widget _buildJoinForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          label: 'Código de invitación',
          textField: true,
          child: TextField(
            controller: _codeController,
            enabled: !_isBusy,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: InvitePolicy.codeLength,
            textInputAction: TextInputAction.done,
            onChanged: (_) => _clearError(),
            onSubmitted: (_) => _joinHousehold(),
            // El generador usa un alfabeto sin O/0/I/1; cualquier otra tecla
            // solo puede producir un código inválido.
            inputFormatters: <TextInputFormatter>[
              _UpperCaseFormatter(),
              FilteringTextInputFormatter.allow(
                RegExp('[${InvitePolicy.alphabet}]'),
              ),
              LengthLimitingTextInputFormatter(InvitePolicy.codeLength),
            ],
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
              color: AppColors.textPrimary,
            ),
            decoration: _fieldDecoration(hint: 'CÓDIGO'),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: _isBusy ? null : _pasteCode,
            icon: const Icon(Icons.content_paste_rounded, size: 18),
            label: const Text('Pegar el código que te han mandado'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(0, 48),
            ),
          ),
        ),
        const SizedBox(height: 6),
        NeoPrimaryButton(
          label: 'Unirme',
          isBusy: _isBusy,
          onPressed: _joinHousehold,
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      counterText: '',
      hintText: hint,
      // El error va pegado al campo que lo causa. Antes se pintaba arriba del
      // todo, a 32 px y un formulario entero de distancia.
      errorText: _errorMessage,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      // Un único grosor, el del sistema de tokens. Aquí había un 2 y un 2,5
      // escritos a mano: el 2,5 es el "quinto grosor" que el propio archivo de
      // tokens dice haber eliminado, y el foco ya se distingue por el cursor y
      // el teclado abierto sin necesidad de engordar el borde.
      border: _border(),
      enabledBorder: _border(),
      focusedBorder: _border(),
      errorBorder: _border(color: AppColors.error),
      focusedErrorBorder: _border(color: AppColors.error),
    );
  }

  OutlineInputBorder _border({Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(
        color: color ?? AppColors.textPrimary,
        width: AppBorder.normal,
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Las dos tarjetas de "¿Con quién vas a compartir?".
///
/// Antes eran un `InkWell` envolviendo un `Container` con su propio color
/// opaco. Eso no da NINGUNA señal al tocar: la onda del InkWell se pinta sobre
/// el `Material` que hay debajo, y el fondo opaco de la tarjeta la tapa
/// entera. En una pantalla que existe precisamente para elegir entre dos
/// caminos, tocar y que no pase nada visible durante el viaje a la red se lee
/// como que la app se ha quedado colgada.
///
/// [NeoPressable] es el componente que ya usa el resto de la app: se hunde
/// sobre su propia sombra al apoyar el dedo, vibra, respeta "reducir
/// movimiento" y garantiza los 44x44 de las guías de Apple.
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
    return NeoPressable(
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      shadowOffset: const Offset(3, 3),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.textPrimary,
                width: AppBorder.thin,
              ),
            ),
            child: Icon(icon, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
