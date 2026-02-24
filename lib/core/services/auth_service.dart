import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class AuthService {
  final _auth         = FirebaseAuth.instance;
  final _db           = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Login con Google ──────────────────────────────────────────────
  Future<UserModel> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Inicio de sesión cancelado.');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken:     googleAuth.idToken,
    );
    final cred         = await _auth.signInWithCredential(credential);
    final firebaseUser = cred.user!;

    final docRef = _db.collection(AppConstants.colUsers).doc(firebaseUser.uid);
    final doc    = await docRef.get();

    if (!doc.exists) {
      // ── Primer login: crear doc con role 'public' ─────────────────
      final token = await NotificationService().getToken();
      final newUser = UserModel(
        uid:         firebaseUser.uid,
        email:       firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? 'Usuario',
        role:        AppConstants.rolePublic,
        isActive:    true,
        fcmToken:    token,
        createdAt:   DateTime.now(),
        updatedAt:   DateTime.now(),
      );
      await docRef.set(newUser.toMap());
      return newUser;
    }

    // ── Doc existente ─────────────────────────────────────────────
    final user = UserModel.fromDoc(doc);

    if (!user.isActive) {
      await _auth.signOut();
      await _googleSignIn.signOut();
      throw Exception('Tu cuenta está suspendida. Contacta al administrador.');
    }

    // Actualizar FCM token si cambió
    final token = await NotificationService().getToken();
    if (token != null && token != user.fcmToken) {
      await docRef.update({
        'fcmToken':  token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return user;
  }

  // ── Logout ────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Obtener datos del usuario actual desde Firestore ─────────────
  // FIX: reintentos para evitar race condition entre authStateChanges
  // y la escritura del doc en Firestore al registrar un usuario nuevo.
  // Firebase Auth dispara authStateChanges ANTES de que el doc exista.
  Future<UserModel?> getCurrentUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    // Hasta 5 intentos con espera exponencial (50ms, 100ms, 200ms, 400ms, 800ms)
    for (int attempt = 0; attempt < 5; attempt++) {
      final doc = await _db
          .collection(AppConstants.colUsers)
          .doc(uid)
          .get();

      if (doc.exists) return UserModel.fromDoc(doc);

      // Doc aún no existe — esperar antes de reintentar
      await Future.delayed(Duration(milliseconds: 50 * (1 << attempt)));
    }

    // Después de 5 intentos el doc no existe: usuario sin perfil
    return null;
  }
}