import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/data/memory_awards.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

/// Los premios que se ha ganado un recuerdo.
///
/// Se pinta solo cuando hay alguno, y lo normal es que no lo haya: eso es
/// justo lo que hace que valga la pena cuando aparece. Un distintivo que
/// sale siempre deja de ser un distintivo a la segunda vez.
///
/// Va inmediatamente debajo de la nota porque es la misma pregunta —qué tal
/// estuvo— contestada de otra manera: la nota es lo que tú pusiste, y esto
/// es lo que se deduce de lo que contaste.
class AwardsCard extends StatelessWidget {
  const AwardsCard({super.key, required this.awards});

  final List<MemoryAward> awards;

  @override
  Widget build(BuildContext context) {
    if (awards.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.tintPrimary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.textPrimary, width: AppBorder.normal),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.textPrimary,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            awards.length == 1
                ? 'ESTE SITIO SE GANÓ ALGO'
                : 'ESTE SITIO SE GANÓ ${awards.length} COSAS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < awards.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 12),
            _AwardRow(award: awards[i]),
          ],
        ],
      ),
    );
  }
}

class _AwardRow extends StatelessWidget {
  const _AwardRow({required this.award});

  final MemoryAward award;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Distinción: ${award.title}. ${award.reason}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.textPrimary,
                  width: AppBorder.thin,
                ),
              ),
              child: Icon(award.icon, size: 20, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    award.title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    award.reason,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
