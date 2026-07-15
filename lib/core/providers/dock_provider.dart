import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider para controlar la visibilidad de la barra de navegación o elementos flotantes.
/// Se utiliza en HomePage dentro del NotificationListener para ocultar/mostrar al hacer scroll.
final dockVisibleProvider = StateProvider<bool>((ref) => true);