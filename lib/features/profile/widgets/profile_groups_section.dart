import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/household_provider.dart';
import '../../../core/theme/components/group_switcher.dart';
import '../../../core/theme/components/neo_pressable.dart';
import '../../../core/theme/tokens/app_colors.dart';

/// ===========================================================================
/// TUS DIARIOS — la puerta desde el Perfil
/// ===========================================================================
///
/// UNA HABITACIÓN, DOS PUERTAS.
///
/// Esto era una segunda copia, a medias, de lo que ya hacía el selector de
/// Inicio. En Inicio podías cambiar de diario pero no gestionar gente; aquí
/// podías gestionar gente pero no cambiar de diario. Dos sitios distintos,
/// cada uno con la mitad del trabajo, y ninguno de los dos completo.
///
/// Eso no es "estar en dos sitios por comodidad": es tener que aprenderse
/// cuál de los dos sirve para lo que quieres hacer ahora. Que es justo lo
/// que la gente que se descargó la app decía que no entendía.
///
/// Ahora hay UN solo sitio donde vive todo —la hoja de diarios, con la lista,
/// quién está en cada uno, invitar, entrar con un código y crear uno nuevo—
/// y dos maneras de llegar: el titular de Inicio y esta fila. Las puertas
/// pueden ser varias. La habitación tiene que ser una.
/// ===========================================================================
class ProfileGroupsSection extends ConsumerWidget {
  const ProfileGroupsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> groupIds = ref.watch(userGroupIdsProvider);
    final int count = groupIds.length;

    final String resumen = count <= 1
        ? 'Ahora mismo solo tienes tu diario privado'
        : (count == 2
              ? 'Tu diario y uno compartido'
              : 'Tu diario y ${count - 1} compartidos');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Tus diarios',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Cada diario es una libreta aparte. Lo que guardas en uno no se ve '
          'en los demás.',
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        NeoActionButton(
          // El rótulo nombra las tres cosas que la gente viene a buscar. Un
          // "Gestionar grupos" no dice ninguna de ellas.
          label: 'Ver tus diarios y quién está en cada uno',
          hint: '$resumen. Aquí también invitas, entras con un código o creas '
              'uno nuevo.',
          icon: Icons.menu_book_rounded,
          background: AppColors.primary,
          onTap: () => openGroupSwitcher(context, ref),
        ),
      ],
    );
  }
}
