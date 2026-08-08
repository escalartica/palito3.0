// Punto de entrada multiplataforma: usa la implementación real (dart:io)
// en iOS/Android/desktop, y un stub sin operación en Flutter Web, donde
// dart:io no existe. Ver legacy_photo_migration_io.dart para la lógica.
export 'legacy_photo_migration_stub.dart'
    if (dart.library.io) 'legacy_photo_migration_io.dart';
