
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZonaGamerCard
    extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final VoidCallback onTap;

  const ZonaGamerCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:
            double.infinity,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        decoration:
            BoxDecoration(
          gradient:
              LinearGradient(
            colors: [
              backgroundColor,
              backgroundColor
                  .withValues(
                alpha: 0.8,
              ),
            ],
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
          ),
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  backgroundColor
                      .withValues(
                alpha: 0.35,
              ),
              blurRadius:
                  12,
              offset:
                  const Offset(
                0,
                5,
              ),
            ),
          ],
        ),
        child:
            Row(
          mainAxisAlignment:
              MainAxisAlignment
                  .spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(
                    10,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white
                            .withValues(
                      alpha: 0.2,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      const Icon(
                    Icons
                        .auto_awesome_rounded,
                    color:
                        Colors.white,
                    size:
                        22,
                  ),
                ),
                const SizedBox(
                  width: 14,
                ),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          GoogleFonts.outfit(
                        fontSize:
                            18,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Colors.white,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      subtitle,
                      style:
                          GoogleFonts.inter(
                        fontSize:
                            12,
                        color:
                            Colors.white
                                .withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding:
                  const EdgeInsets.all(
                8,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white
                        .withValues(
                  alpha: 0.15,
                ),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                color:
                    Colors.white,
                size:
                    16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

