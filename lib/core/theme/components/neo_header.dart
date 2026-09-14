import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';

/// Botón circular neobrutalista. Antes existía una copia privada en
/// `profile_page.dart` y las pantallas de grupo usaban un `IconButton` pelado
/// de Material, así que un mismo flujo tenía tres cabeceras distintas.
class NeoCircleButton extends StatelessWidget {
  const NeoCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          // 44x44: mínimo táctil de las HIG de Apple. Las copias anteriores
          // medían 32x32 y 34x34.
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textPrimary, width: 2),
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
        ),
      ),
    );
  }
}

/// Cabecera común de las pantallas que no son pestañas del dock.
class NeoHeader extends StatelessWidget implements PreferredSizeWidget {
  const NeoHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.showLogo = true,
  });

  final String title;
  final VoidCallback? onBack;
  final bool showLogo;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 60,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
      leading: onBack == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: NeoCircleButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Volver',
                  onTap: onBack,
                ),
              ),
            ),
      leadingWidth: 68,
      actions: <Widget>[
        if (showLogo)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textPrimary, width: 2),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: AppColors.textPrimary,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    cacheWidth: 120,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Botón principal de acción, con estado de carga dentro del propio botón.
/// Las pantallas de grupo sustituían TODO el formulario por un spinner
/// mientras enviaban: el texto que acababas de teclear desaparecía de la
/// pantalla.
class NeoPrimaryButton extends StatelessWidget {
  const NeoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isBusy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isBusy;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.textPrimary, width: 2),
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.onAccent,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (icon != null) ...<Widget>[
                          Icon(icon, size: 18, color: AppColors.onAccent),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
