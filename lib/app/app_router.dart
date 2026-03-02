import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/public/screens/home_screen.dart';
import '../features/public/screens/package_detail_screen.dart';
import '../features/public/screens/room_detail_screen.dart';
import '../features/public/screens/create_reservation_screen.dart';
import '../features/public/screens/my_reservations_screen.dart';
import '../features/public/screens/payment_screen.dart';            // ← NUEVO
import '../features/hotel/screens/hotel_home_screen.dart';
import '../features/hotel/screens/create_package_screen.dart';
import '../features/hotel/screens/reservation_requests_screen.dart';
import '../features/hotel/screens/inbox_screen.dart';
import '../features/hotel/screens/hotel_schedule_screen.dart';
import '../features/hotel/screens/hotel_profile_screen.dart';
import '../features/hotel/screens/hotel_qr_screen.dart';            // ← NUEVO
import '../features/hotel/screens/hotel_receipt_screen.dart';       // ← NUEVO
import '../features/hotel/screens/rooms_screen.dart';
import '../features/hotel/screens/create_room_screen.dart';
import '../features/admin/screens/admin_home_screen.dart';
import '../features/admin/screens/hotel_detail_screen.dart';
import '../core/models/package_model.dart';
import '../core/models/reservation_model.dart';
import '../core/models/room_model.dart';

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
        if (role == 'hotel' &&
            (loc.startsWith('/home') || loc.startsWith('/admin'))) {
          return '/hotel';
        }
        if (role == 'admin' &&
            (loc.startsWith('/home') || loc.startsWith('/hotel'))) {
          return '/admin';
        }
        if (role == 'public' &&
            (loc.startsWith('/hotel') || loc.startsWith('/admin'))) {
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
            path: 'room/:id',
            builder: (_, state) => RoomDetailScreen(
              room: state.extra as RoomModel,
            ),
            routes: [
              GoRoute(
                path: 'reserve',
                builder: (_, state) => CreateReservationScreen(
                  room: state.extra as RoomModel,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'my-reservations',
            builder: (_, __) => const MyReservationsScreen(),
          ),
          // ── NUEVA: pantalla de pago para el turista ─────────────
          GoRoute(
            path: 'payment',
            builder: (_, state) => PaymentScreen(
              reservation: state.extra as ReservationModel,
            ),
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
            path: 'rooms',
            builder: (_, __) => const RoomsScreen(),
          ),
          GoRoute(
            path: 'rooms/create',
            builder: (_, __) => const CreateRoomScreen(),
          ),
          GoRoute(
            path: 'rooms/edit',
            builder: (_, state) => CreateRoomScreen(
              roomToEdit: state.extra as RoomModel,
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
          // ── NUEVAS rutas del hotel ──────────────────────────────
          GoRoute(
            path: 'qr',
            builder: (_, __) => const HotelQrScreen(),
          ),
          GoRoute(
            path: 'receipt',
            builder: (_, state) => HotelReceiptScreen(
              reservation: state.extra as ReservationModel,
            ),
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