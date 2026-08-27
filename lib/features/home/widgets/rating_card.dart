import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/memory_model.dart';
import 'animated_card.dart';
import 'icon_box.dart';

/// Card de puntuación del recuerdo: barra de progreso animada de 0 a 10
/// con la etiqueta textual correspondiente (Correcto, Excelente...).
class RatingCard extends StatelessWidget {
  final MemoryModel memory;

  const RatingCard({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    final rating = memory.rating.clamp(0.0, 10.0);
    final progress = rating / 10.0;

    return AnimatedCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const IconBox(
                    icon: Icons.star_rounded,
                    backgroundColor: Color(0xFFFFD400),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Puntuación',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              _buildRatingNumber(rating),
            ],
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFD400),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                _ratingLabel(rating),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                '10',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingNumber(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD400),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0F172A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0F172A),
            blurRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, size: 18, color: Color(0xFF0F172A)),
          const SizedBox(width: 5),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(double rating) {
    if (rating >= 9) {
      return 'Extraordinario';
    }

    if (rating >= 8) {
      return 'Excelente';
    }

    if (rating >= 7) {
      return 'Muy bueno';
    }

    if (rating >= 5) {
      return 'Correcto';
    }

    return 'Por mejorar';
  }
}
