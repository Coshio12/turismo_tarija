import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/hotel_provider.dart';
import '../../../core/models/package_model.dart';

class HotelHomeScreen extends StatefulWidget {
  const HotelHomeScreen({super.key});
  @override
  State<HotelHomeScreen> createState() => _HotelHomeScreenState();
}

class _HotelHomeScreenState extends State<HotelHomeScreen>
    with WidgetsBindingObserver {
  DateTime? _lastBackPress;
  String?   _currentUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListening();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startListening() {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null && uid != _currentUid) {
      _currentUid = uid;
      context.read<HotelProvider>().listenAll(uid);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _startListening();
  }

  Future<void> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presiona de nuevo para salir'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      await SystemNavigator.pop();
    }
  }

  void _snack(String msg, {Color color = Colors.green}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final hotel   = context.watch<AuthProvider>().user;
    final prov    = context.watch<HotelProvider>();
    final pending = prov.pendingReservations.length;
    final unread  = prov.unreadCount;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            (hotel?.hotelName ?? 'MI HOTEL').toUpperCase(),
            style: GoogleFonts.bungee(
              fontWeight: FontWeight.bold,
              // color: Colors.white, // Descomenta si tu AppBar es oscura
            ),
            ),
          automaticallyImplyLeading: false,
          actions: [
            // Badge de reservas pendientes en el AppBar
            _AppBarBadge(
              icon: Icons.notifications_outlined,
              count: pending,
              color: Colors.red,
              onTap: () => context.push('/hotel/reservations'),
            ),
            // Badge de mensajes no leídos en el AppBar
            _AppBarBadge(
              icon: Icons.mail_outlined,
              count: unread,
              color: const Color(0xFF1A5276),
              onTap: () => context.push('/hotel/inbox'),
            ),
            IconButton(
              tooltip: 'Perfil del hotel',
              icon: const Icon(Icons.manage_accounts_outlined),
              onPressed: () => context.push('/hotel/profile'),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Quick cards ──────────────────────────────────────
              Row(children: [
                Expanded(
                  child: _QuickCard(
                    icon: Icons.add_box_outlined,
                    label: 'Nuevo\npaquete',
                    color: const Color(0xFF1A5276),
                    badge: 0,
                    onTap: () async {
                      await context.push('/hotel/packages/create');
                      if (mounted) {
                        context.read<HotelProvider>().refreshPackages(
                            context.read<AuthProvider>().user!.uid);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.pending_actions_outlined,
                    label: 'Pendientes',
                    color: pending > 0 ? Colors.orange : Colors.grey,
                    badge: pending,
                    onTap: () => context.push('/hotel/reservations'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.calendar_month_outlined,
                    label: 'Agendadas',
                    color: const Color(0xFF1A5276),
                    badge: 0,
                    onTap: () => context.push('/hotel/schedule'),
                  ),
                ),
                const SizedBox(width: 8),
                // Buzón con badge de no leídos
                Expanded(
                  child: _QuickCard(
                    icon: unread > 0
                        ? Icons.mark_email_unread_outlined
                        : Icons.mail_outlined,
                    label: 'Buzón',
                    color: unread > 0
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF2E86C1),
                    badge: unread,
                    badgeColor: const Color(0xFFD32F2F),
                    onTap: () => context.push('/hotel/inbox'),
                  ),
                ),
              ]),

              // ── Banner de mensajes nuevos ────────────────────────
              if (unread > 0) ...[
                const SizedBox(height: 12),
                _UnreadBanner(
                  count: unread,
                  onTap: () => context.push('/hotel/inbox'),
                ),
              ],

              const SizedBox(height: 20),
              const Text('Mis paquetes',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (prov.packages.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Aún no tienes paquetes. ¡Crea el primero!',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...List.generate(prov.packages.length, (i) {
                  final pkg = prov.packages[i];
                  return _HotelPackageCard(
                    package: pkg,
                    onEdit: () async {
                      await context.push('/hotel/packages/edit', extra: pkg);
                      if (mounted) {
                        context.read<HotelProvider>().refreshPackages(
                            context.read<AuthProvider>().user!.uid);
                      }
                    },
                    onToggle: () => _handleToggle(context, prov, pkg),
                    onDelete: () => _handleDelete(context, prov, pkg),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  void _handleToggle(
      BuildContext context, HotelProvider prov, PackageModel pkg) {
    final willSuspend = pkg.isActive;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(willSuspend ? 'Suspender paquete' : 'Activar paquete'),
        content: Text(willSuspend
            ? '"${pkg.packageName}" dejará de ser visible.'
            : '"${pkg.packageName}" volverá a aparecer en el catálogo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: willSuspend ? Colors.orange : Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              final ok =
                  await prov.togglePackage(pkg.packageId, !pkg.isActive);
              _snack(
                ok
                    ? willSuspend
                        ? 'Paquete "${pkg.packageName}" suspendido'
                        : 'Paquete "${pkg.packageName}" activado'
                    : prov.error ?? 'Error al actualizar',
                color: ok
                    ? (willSuspend ? Colors.orange : Colors.green)
                    : Colors.red,
              );
            },
            child: Text(willSuspend ? 'Suspender' : 'Activar'),
          ),
        ],
      ),
    );
  }

  void _handleDelete(
      BuildContext context, HotelProvider prov, PackageModel pkg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar paquete'),
        content: Text(
            '¿Eliminar "${pkg.packageName}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final name = pkg.packageName;
              final ok   = await prov.deletePackage(pkg.packageId);
              _snack(
                ok
                    ? 'Paquete "$name" eliminado correctamente'
                    : prov.error ?? 'Error al eliminar',
                color: ok ? Colors.red.shade700 : Colors.red,
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ── AppBar badge (notificaciones + buzón) ─────────────────────────────
class _AppBarBadge extends StatelessWidget {
  final IconData icon;
  final int      count;
  final Color    color;
  final VoidCallback onTap;

  const _AppBarBadge({
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: Icon(icon), onPressed: onTap),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: _AnimatedBadge(count: count, color: color),
          ),
      ],
    );
  }
}

// ── Quick card con badge ──────────────────────────────────────────────
class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final int      badge;
  final Color?   badgeColor;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.badge,
    required this.onTap,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: badge > 0
                ? color.withOpacity(0.6)
                : color.withOpacity(0.25),
            width: badge > 0 ? 1.5 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 5),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ]),
            if (badge > 0)
              Positioned(
                top: -8,
                right: -4,
                child: _AnimatedBadge(
                  count: badge,
                  color: badgeColor ?? color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Badge animado reutilizable ────────────────────────────────────────
class _AnimatedBadge extends StatelessWidget {
  final int   count;
  final Color color;
  const _AnimatedBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: count > 0 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.elasticOut,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// ── Banner de mensajes nuevos ─────────────────────────────────────────
// Aparece debajo de los quick cards solo cuando hay mensajes sin leer.
class _UnreadBanner extends StatelessWidget {
  final int          count;
  final VoidCallback onTap;
  const _UnreadBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A5276), Color(0xFF2E86C1)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A5276).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(children: [
          // Icono con pulso visual
          Stack(alignment: Alignment.center, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
            const Icon(Icons.mark_email_unread_outlined,
                color: Colors.white, size: 20),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? 'Tienes 1 mensaje nuevo'
                      : 'Tienes $count mensajes nuevos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'Toca para leer',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: Colors.white70, size: 20),
        ]),
      ),
    );
  }
}

// ── Hotel Package Card ────────────────────────────────────────────────
class _HotelPackageCard extends StatelessWidget {
  final PackageModel package;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _HotelPackageCard({
    required this.package,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(package.packageName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: package.isActive
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                    package.isActive ? 'Activo' : 'Suspendido',
                    style: TextStyle(
                        color:
                            package.isActive ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(package.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
                'Bs ${package.pricePerPerson.toStringAsFixed(0)}/persona  ·  '
                '${package.totalReservations} reservas',
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 10),
            Row(children: [
              _btn(Icons.edit_outlined, 'Editar', Colors.blue, onEdit),
              const SizedBox(width: 8),
              _btn(
                  package.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  package.isActive ? 'Suspender' : 'Activar',
                  package.isActive ? Colors.orange : Colors.green,
                  onToggle),
              const SizedBox(width: 8),
              _btn(Icons.delete_outline, 'Eliminar', Colors.red,
                  onDelete),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _btn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4)),
    );
  }
}