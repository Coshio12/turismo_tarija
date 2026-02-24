import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'app/app_router.dart';
import 'app/app_theme.dart';
import 'core/services/notification_service.dart';
import 'features/admin/providers/admin_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/hotel/providers/hotel_provider.dart';
import 'features/public/providers/public_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().init();
  runApp(const TurismoTarijaApp());
}

class TurismoTarijaApp extends StatelessWidget {
  const TurismoTarijaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          // listenAuth() se llama UNA SOLA VEZ al crear el provider
          create: (_) => AuthProvider()..listenAuth(),
        ),
        ChangeNotifierProvider(create: (_) => PublicProvider()),
        ChangeNotifierProvider(create: (_) => HotelProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      // ── Router como instancia fija ────────────────────────────────
      // Se crea con Consumer para poder pasarle el AuthProvider,
      // pero el GoRouter resultante NO se recrea en cada rebuild —
      // solo se recrea si AuthProvider cambia de instancia (nunca).
      // El refreshListenable interno del router reacciona a los
      // notifyListeners() de AuthProvider.
      child: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          // buildRouter crea el router solo en el primer build.
          // Usamos un patrón con _RouterHolder para que el GoRouter
          // sea una instancia estable durante toda la vida del widget.
          return _AppWithRouter(auth: auth);
        },
      ),
    );
  }
}

/// Widget que mantiene el GoRouter como instancia estable (solo se
/// crea una vez). Si se pusiera directamente en el Builder del
/// Consumer, se recrearía con cada notifyListeners → bug de navegación.
class _AppWithRouter extends StatefulWidget {
  final AuthProvider auth;
  const _AppWithRouter({required this.auth});

  @override
  State<_AppWithRouter> createState() => _AppWithRouterState();
}

class _AppWithRouterState extends State<_AppWithRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // El router se crea UNA SOLA VEZ aquí
    _router = buildRouter(widget.auth);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title:                      'Turismo Tarija',
      theme:                      AppTheme.theme,
      routerConfig:               _router,
      debugShowCheckedModeBanner: false,
    );
  }
}