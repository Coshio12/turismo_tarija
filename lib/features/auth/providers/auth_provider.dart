import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  UserModel?  _user;
  AuthStatus  _status  = AuthStatus.unknown;
  bool        _loading = false;
  String?     _error;

  // Flag para saber si hay un login en curso iniciado por signInWithGoogle().
  // Durante ese proceso, ignoramos el evento de authStateChanges para evitar
  // la race condition: Auth dispara el evento antes de que el doc exista.
  bool _signingIn = false;

  UserModel?  get user    => _user;
  AuthStatus  get status  => _status;
  bool        get loading => _loading;
  String?     get error   => _error;

  bool get isLoggedIn    => _status == AuthStatus.authenticated;
  bool get isInitialized => _status != AuthStatus.unknown;

  // ── Escucha Firebase Auth al arrancar ─────────────────────────────
  void listenAuth() {
    _service.authStateChanges.listen((firebaseUser) async {
      // Si estamos en medio de un signInWithGoogle() manual, no procesamos
      // este evento — lo maneja signInWithGoogle() directamente.
      if (_signingIn) return;

      if (firebaseUser == null) {
        _user   = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      // Hay sesión — buscar doc en Firestore (con reintentos)
      try {
        final userData = await _service.getCurrentUserData();

        if (userData == null) {
          // No encontró el doc después de los reintentos.
          // Puede pasar si la escritura del doc falló completamente.
          // En este caso cerramos sesión limpiamente.
          await _service.logout();
          _user   = null;
          _status = AuthStatus.unauthenticated;
          _error  = 'No se encontró tu perfil. Intenta iniciar sesión de nuevo.';
        } else if (!userData.isActive) {
          await _service.logout();
          _user   = null;
          _status = AuthStatus.unauthenticated;
          _error  = 'Tu cuenta está suspendida. Contacta al administrador.';
        } else {
          _user   = userData;
          _status = AuthStatus.authenticated;
          _error  = null;
        }
      } catch (_) {
        _user   = null;
        _status = AuthStatus.unauthenticated;
      }

      notifyListeners();
    });
  }

  // ── Login con Google ──────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    _loading   = true;
    _error     = null;
    _signingIn = true; // bloquear listener durante el proceso
    notifyListeners();
    try {
      // signInWithGoogle() en AuthService crea el doc si no existe,
      // luego retorna el UserModel — no hay race condition aquí.
      _user   = await _service.signInWithGoogle();
      _status = AuthStatus.authenticated;
      _error  = null;
    } catch (e) {
      _error  = e.toString().replaceAll('Exception: ', '');
      _status = AuthStatus.unauthenticated;
    } finally {
      _loading   = false;
      _signingIn = false;
      notifyListeners();
    }
  }


  // ── Actualizar perfil del hotel ───────────────────────────────────
  // Reemplaza _user localmente para que el AppBar refleje el cambio
  // al instante (mismo patrón de actualización optimista).
  void updateUserLocally(UserModel updated) {
    _user = updated;
    notifyListeners();
  }

  // ── Logout ────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _service.logout();
    _user   = null;
    _status = AuthStatus.unauthenticated;
    _error  = null;
    notifyListeners();
  }
}