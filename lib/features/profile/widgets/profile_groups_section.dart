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

    // ── LO QUE TIENES ARRIBA, LO QUE PUEDES HACER DEBAJO ──
    //
    // El rótulo del botón decía "Ver tus diarios y quién está en cada uno":
    // once palabras que en un iPhone parten en dos líneas y dejan "uno"
    // solo en la segunda. Y encima del botón había un párrafo explicando qué
    // es un diario… que **ya está dentro de la hoja que abre este botón**, y
    // mejor escrito ("cada diario guarda sus propios platos, su mapa y su
    // ruleta"). Dos explicaciones de lo mismo en dos sitios, ya divergiendo:
    // una habla de libretas y la otra de platos, mapa y ruleta.
    //
    // La explicación se queda donde se puede actuar sobre ella. Aquí el
    // botón dice **lo que tienes** —que es el dato, y cambia— y debajo, en
    // pequeño, lo que se hace ahí dentro. De siete líneas de prosa a tres.
    final bool soloElTuyo = count <= 1;
    final String tienes = soloElTuyo
        ? 'Solo tienes tu diario privado'
        : (count == 2
              ? 'Tu diario y uno compartido'
              : 'Tu diario y ${count - 1} compartidos');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          kSeccionTusDiarios,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        NeoActionButton(
          label: tienes,
          hint: soloElTuyo
              ? 'Crea uno compartido o entra con un código'
              : 'Mira quién está en cada uno, invita, entra con un código '
                    'o crea otro',
          icon: Icons.menu_book_rounded,
          background: AppColors.primary,
          onTap: () => openGroupSwitcher(context, ref),
        ),
      ],
    );
  }
}
