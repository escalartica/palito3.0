import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/household_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/household_service.dart';
import '../../core/theme/components/neo_header.dart';
import '../../core/theme/tokens/app_colors.dart';

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
      ref.read(activeGroupIdOverrideProvider.notifier).state = groupId;

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
      ref.read(activeGroupIdOverrideProvider.notifier).state = result.groupId;

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
      'Pide el código a quien te quiera invitar. Son 8 letras y números.',
  };

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
      children: <Widget>[
        TextField(
          controller: _nameController,
          enabled: !_isBusy,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
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
            maxLength: 8,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _joinHousehold(),
            // El generador usa un alfabeto sin O/0/I/1; cualquier otra tecla
            // solo puede producir un código inválido.
            inputFormatters: <TextInputFormatter>[
              _UpperCaseFormatter(),
              FilteringTextInputFormatter.allow(RegExp('[A-HJ-NP-Z2-9]')),
              LengthLimitingTextInputFormatter(8),
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
        const SizedBox(height: 16),
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
      border: _border(2),
      enabledBorder: _border(2),
      focusedBorder: _border(2.5),
      errorBorder: _border(2, color: AppColors.error),
      focusedErrorBorder: _border(2.5, color: AppColors.error),
    );
  }

  OutlineInputBorder _border(double width, {Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: color ?? AppColors.textPrimary,
        width: width,
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
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.textPrimary, width: 2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: AppColors.textPrimary,
                blurRadius: 0,
                offset: Offset(3, 3),
              ),
            ],
          ),
          child: ExcludeSemantics(
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.textPrimary,
                      width: 1.5,
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
          ),
        ),
      ),
    );
  }
}
