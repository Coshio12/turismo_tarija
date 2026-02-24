import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A5276),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono / logo
                Image(
                  image: const AssetImage('assets/icon/icon_model.png'),
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.work_outline,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'TURISMO TARJA',
                  style: GoogleFonts.bungee(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 30,
                    fontWeight:
                        FontWeight.bold, // Añade peso para que sea llamativo
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Descubre lo mejor de Tarija',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 20),

                // Tarjeta de login
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Bienvenido',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A5276),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Inicia sesión para continuar',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Botón Google
                      SizedBox(
                        width: double.infinity,
                        child: auth.loading
                            ? const Center(child: CircularProgressIndicator())
                            : _GoogleSignInButton(
                                onPressed: () => context
                                    .read<AuthProvider>()
                                    .signInWithGoogle(),
                              ),
                      ),

                      // Error
                      if (auth.error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  auth.error!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      Text(
                        'Al iniciar sesión aceptas los términos\nde uso de la plataforma.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Gobierno Autónomo\n Departamental de Tarija',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bungee(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold, // Añade peso para que sea llamativo
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón estilo Google Sign-In con logo y texto estándar.
class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GoogleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo de Google dibujado con texto "G" coloreado
          // (no requiere asset externo)
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Text(
                'G',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF4285F4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Continuar con Google',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
