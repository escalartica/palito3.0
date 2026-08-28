import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

/// ===========================================================================
/// AUTH PROVIDERS
/// ===========================================================================
///
/// Punto único de acceso al estado de autenticación de Firebase, usado por
/// el resto de la app (y por `household_provider.dart`) en vez de leer
/// `FirebaseAuth.instance.currentUser` directamente — así los widgets se
/// reconstruyen automáticamente cuando cambia la sesión (inicio de sesión,
/// cierre de sesión, eliminación de cuenta), en vez de quedarse con un
/// valor congelado del momento en que se leyó por primera vez.
/// ===========================================================================

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// El uid del usuario actual, o `null` si no ha iniciado sesión. Un
/// `Provider` derivado (no un `StreamProvider` propio) porque no necesita
/// su propio stream — simplemente proyecta el valor ya emitido por
/// [authStateChangesProvider].
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateChangesProvider).valueOrNull?.uid;
});
