import 'package:flutter/material.dart';

/// Como [FloatingActionButtonLocation.endFloat], pero anclado a la esquina
/// de la columna de contenido (máximo 640px, el mismo límite que usan los
/// `body` de las páginas principales) en vez de a la del `Scaffold`
/// completo — si no, en la PWA de escritorio el FAB queda flotando lejos
/// del contenido centrado.
class ConstrainedEndFloatLocation extends FloatingActionButtonLocation {
  const ConstrainedEndFloatLocation();

  static const double _maxContentWidth = 640;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final defaultOffset = FloatingActionButtonLocation.endFloat.getOffset(
      scaffoldGeometry,
    );
    final screenWidth = scaffoldGeometry.scaffoldSize.width;
    if (screenWidth <= _maxContentWidth) {
      return defaultOffset;
    }
    final contentRight = (screenWidth + _maxContentWidth) / 2;
    final dx =
        contentRight - scaffoldGeometry.floatingActionButtonSize.width - 16;
    return Offset(dx, defaultOffset.dy);
  }
}
