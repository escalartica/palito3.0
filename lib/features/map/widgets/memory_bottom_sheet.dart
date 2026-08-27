import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/memory_model.dart';

/// Hoja inferior con el resumen de un recuerdo, abierta al tocar un
/// marcador (normal o dentro de un grupo "spiderfy") en el mapa.
///
/// No mantiene estado propio: recibe mediante callbacks todo lo que
/// depende de `_MapPageState` (color por categoría, coordenada resuelta,
/// nombre de ubicación inverso) para poder vivir fuera de esa clase sin
/// cambiar ningún comportamiento.
class MemoryBottomSheet {
  const MemoryBottomSheet._();

  static void show({
    required BuildContext context,
    required MemoryModel memory,
    required Color Function(String category) getCategoryColor,
    required LatLng? Function(String memoryId) getCoordinates,
    required Future<String> Function(
      double lat,
      double lng,
      String currentAddress,
    )
    resolveLocationName,
  }) {
    final categoryColor =
        getCategoryColor(
      memory.category,
    );

    final coordinates =
        getCoordinates(
      memory.id,
    );

    final double? lat =
        coordinates?.latitude;

    final double? lng =
        coordinates?.longitude;

    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled:
          true,
      builder: (context) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            36,
          ),
          decoration:
              const BoxDecoration(
            color: Color(0xFFFFFDF5),
            borderRadius:
                BorderRadius.vertical(
              top:
                  Radius.circular(
                32,
              ),
            ),
            border: Border(
              top: BorderSide(
                color: Color(0xFF0F172A),
                width: 3,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black26,
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin:
                      const EdgeInsets.only(
                    bottom: 20,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      2,
                    ),
                  ),
                ),
              ),

              // --------------------------------------------------
              // TÍTULO + RATING
              // --------------------------------------------------

              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      memory.title,
                      style:
                          GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            const Color(
                          0xFF0F172A,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          categoryColor
                              .withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: Text(
                      '${memory.rating.toStringAsFixed(1)} ★',
                      style:
                          GoogleFonts.outfit(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 15,
                        color:
                            categoryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              // --------------------------------------------------
              // UBICACIÓN
              // --------------------------------------------------

              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color:
                        Colors.grey.shade500,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                    child:
                        lat != null &&
                                lng != null
                            ? FutureBuilder<
                                String>(
                                future:
                                    resolveLocationName(
                                  lat,
                                  lng,
                                  memory.location
                                      .address,
                                ),
                                builder:
                                    (
                                  context,
                                  snapshot,
                                ) {
                                  final text =
                                      snapshot.data ??
                                          memory
                                              .location
                                              .address;

                                  return Text(
                                    text.isNotEmpty
                                        ? text
                                        : 'Ubicación no disponible',
                                    style:
                                        GoogleFonts
                                            .inter(
                                      fontSize:
                                          14,
                                      color: Colors
                                          .grey
                                          .shade600,
                                    ),
                                    maxLines:
                                        1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                  );
                                },
                              )
                            : Text(
                                memory.location
                                        .address
                                        .isNotEmpty
                                    ? memory
                                        .location
                                        .address
                                    : 'Ubicación no disponible',
                                style:
                                    GoogleFonts.inter(
                                  fontSize:
                                      14,
                                  color: Colors
                                      .grey
                                      .shade600,
                                ),
                                maxLines:
                                    1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                  ),
                ],
              ),

              const SizedBox(
                height: 16,
              ),

              // --------------------------------------------------
              // CHIPS
              // --------------------------------------------------

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      memory.category,
                    ),
                    backgroundColor:
                        categoryColor
                            .withValues(
                      alpha: 0.15,
                    ),
                    labelStyle:
                        GoogleFonts.inter(
                      fontWeight:
                          FontWeight.w600,
                      fontSize: 13,
                      color:
                          categoryColor,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                    side: BorderSide(
                      color:
                          categoryColor,
                      width: 1.5,
                    ),
                  ),
                  Chip(
                    label: Text(
                      memory.wouldReturn
                          ? '¡Volvería!'
                          : 'No volvería',
                    ),
                    backgroundColor:
                        (memory.wouldReturn
                                ? Colors.green
                                : Colors.red)
                            .withValues(
                      alpha: 0.12,
                    ),
                    labelStyle:
                        GoogleFonts.inter(
                      fontWeight:
                          FontWeight.w600,
                      fontSize: 13,
                      color: memory.wouldReturn
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                    side: BorderSide(
                      color: memory.wouldReturn
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      width: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 24,
              ),

              // --------------------------------------------------
              // BOTÓN DETALLE
              // --------------------------------------------------

              SizedBox(
                width:
                    double.infinity,
                height: 52,
                child:
                    ElevatedButton(
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        const Color(
                      0xFFFFD400,
                    ),
                    foregroundColor:
                        const Color(
                      0xFF0F172A,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      side: const BorderSide(
                        color: Color(0xFF0F172A),
                        width: 2,
                      ),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();

                    Navigator.pop(
                      context,
                    );

                    context.push(
                      '/memory-detail',
                      extra: memory,
                    );
                  },
                  child: Text(
                    'Ver Experiencia Completa',
                    style:
                        GoogleFonts.outfit(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
