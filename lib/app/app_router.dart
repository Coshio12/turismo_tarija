import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/public/screens/home_screen.dart';
import '../features/public/screens/package_detail_screen.dart';
import '../features/public/screens/create_reservation_screen.dart';
import '../features/public/screens/my_reservations_screen.dart';
import '../features/hotel/screens/hotel_home_screen.dart';
import '../features/hotel/screens/create_package_screen.dart';
import '../features/hotel/screens/reservation_requests_screen.dart';
import '../features/hotel/screens/inbox_screen.dart';
import '../features/hotel/screens/hotel_schedule_screen.dart';
import '../features/hotel/screens/hotel_profile_screen.dart';
import '../features/admin/screens/admin_home_screen.dart';
import '../features/admin/screens/hotel_detail_screen.dart';
import '../core/models/package_model.dart';

/// Rutas raíz (home de cada rol) — se navega con go(), reemplazan el stack.
/// Rutas secundarias (detalle, crear, editar) — se navega con push(),
/// se apilan sobre la raíz y el botón Back funciona correctamente.
GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/splash',

    redirect: (context, state) {
      final loc = state.matchedLocation;

      if (!auth.isInitialized) {
        return loc == '/splash' ? null : '/splash';
      }

      final loggedIn = auth.isLoggedIn;
      final onLogin  = loc == '/login';
      final onSplash = loc == '/splash';

      if (!loggedIn && !onLogin) return '/login';

      if (loggedIn && (onLogin || onSplash)) {
        return _homeForRole(auth.user!.role);
      }

      if (loggedIn) {
        final role = auth.user!.role;
        // Impedir que un rol acceda a rutas de otro rol
        if (role == 'hotel' && (loc.startsWith('/home') || loc.startsWith('/admin'))) {
          return '/hotel';
        }
        if (role == 'admin' && (loc.startsWith('/home') || loc.startsWith('/hotel'))) {
          return '/admin';
        }
        if (role == 'public' && (loc.startsWith('/hotel') || loc.startsWith('/admin'))) {
          return '/home';
        }
      }

      return null;
    },

    routes: [
      // ── Splash ───────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _SplashScreen(),
      ),

      // ── Login ────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),

      // ── Público ──────────────────────────────────────────────────
      // /home es la raíz del rol público. Las sub-rutas se anidan
      // dentro para que GoRouter gestione el back stack correctamente.
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'package/:id',
            builder: (_, state) => PackageDetailScreen(
              package: state.extra as PackageModel,
            ),
            routes: [
              GoRoute(
                path: 'reserve',
                builder: (_, state) => CreateReservationScreen(
                  package: state.extra as PackageModel,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'my-reservations',
            builder: (_, __) => const MyReservationsScreen(),
          ),
        ],
      ),

      // ── Hotel ────────────────────────────────────────────────────
      GoRoute(
        path: '/hotel',
        builder: (_, __) => const HotelHomeScreen(),
        routes: [
          GoRoute(
            path: 'packages/create',
            builder: (_, __) => const CreatePackageScreen(),
          ),
          GoRoute(
            path: 'packages/edit',
            builder: (_, state) => CreatePackageScreen(
              packageToEdit: state.extra as PackageModel,
            ),
          ),
          GoRoute(
            path: 'reservations',
            builder: (_, __) => const ReservationRequestsScreen(),
          ),
          GoRoute(
            path: 'inbox',
            builder: (_, __) => const InboxScreen(),
          ),
          GoRoute(
            path: 'schedule',
            builder: (_, __) => const HotelScheduleScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (_, __) => const HotelProfileScreen(),
          ),
        ],
      ),

      // ── Admin ────────────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminHomeScreen(),
        routes: [
          GoRoute(
            path: 'hotel/:id',
            builder: (_, state) => HotelDetailScreen(
              hotelId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
}

String _homeForRole(String role) {
  switch (role) {
    case 'hotel': return '/hotel';
    case 'admin': return '/admin';
    default:      return '/home';
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A5276),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.travel_explore, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Turismo Tarija',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}