import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/household_provider.dart';
import '../../core/theme/components/neo_header.dart';
import '../../core/theme/tokens/app_colors.dart';

/// ===========================================================================
/// ¿CÓMO TE LLAMAS?
/// ===========================================================================
///
/// Apple solo entrega el nombre real la PRIMERA vez que un Apple ID autoriza
/// la app. En cualquier reinstalación llega vacío, y la versión anterior caía
/// entonces al prefijo del correo: con "Ocultar mi correo" eso producía
/// nombres como `gdvcgp2gdt`, que además no había ninguna pantalla en toda la
/// app para corregir.
///
/// Ahora el nombre es un dato nuestro: si no lo tenemos, lo preguntamos una
/// vez, aquí, y se puede cambiar cuando se quiera desde Perfil.
/// ===========================================================================
class NamePage extends ConsumerStatefulWidget {
  const NamePage({super.key});

  @override
  ConsumerState<NamePage> createState() => _NamePageState();
}

class _NamePageState extends ConsumerState<NamePage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Escribe cómo quieres que te llamemos.');
      return;
    }

    final String? uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await ref
          .read(authServiceProvider)
          .updateDisplayName(
            uid: uid,
            displayName: name,
            groupIds: ref.read(userGroupIdsProvider),
          );
      // El `redirect` del router se encarga de sacarnos de aquí en cuanto
      // `needsDisplayNameProvider` pase a falso.
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo guardar. Comprueba tu conexión e inténtalo otra vez.';
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Sin botón de volver: es el único paso obligatorio del alta.
      appBar: const NeoHeader(title: 'Tu nombre', onBack: null),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '¿Cómo te llamas?',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Es el nombre que verán las personas con las que compartas un '
                'grupo. Puedes cambiarlo cuando quieras desde tu perfil.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(40),
                ],
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Por ejemplo, Sharon',
                  errorText: _error,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.textPrimary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.textPrimary,
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.textPrimary,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              NeoPrimaryButton(
                label: 'Continuar',
                isBusy: _isBusy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
