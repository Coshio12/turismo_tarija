import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/hotel_provider.dart';
import '../../../core/models/package_model.dart';
import '../../../core/models/room_model.dart';   // ← import tipado correcto

class HotelHomeScreen extends StatefulWidget {
  const HotelHomeScreen({super.key});
  @override
  State<HotelHomeScreen> createState() => _HotelHomeScreenState();
}

class _HotelHomeScreenState extends State<HotelHomeScreen>
    with WidgetsBindingObserver {
  DateTime? _lastBackPress;

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

  // FIX: eliminado el guard uid != _currentUid para que SIEMPRE
  // re-suscriba al volver de cualquier subpantalla.
  void _startListening() {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      context.read<HotelProvider>().listenAll(uid);
    }
  }

  // FIX: también refresca cuando la app vuelve de segundo plano
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

  // FIX: helper que navega con push y llama _startListening() al volver,
  // así cualquier pantalla hijo actualiza el home automáticamente.
  Future<void> _pushAndRefresh(String route, {Object? extra}) async {
    if (extra != null) {
      await context.push(route, extra: extra);
    } else {
      await context.push(route);
    }
    if (mounted) _startListening();
  }

  @override
  Widget build(BuildContext context) {
    final hotel   = context.watch<AuthProvider>().user;
    final prov    = context.watch<HotelProvider>();
    final pending = prov.pendingReservations.length;
    final unread  = prov.unreadCount;
    final rooms   = prov.rooms.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            (hotel?.hotelName ?? 'MI HOTEL').toUpperCase(),
            style: GoogleFonts.bungee(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          actions: [
            _AppBarBadge(
              icon: Icons.notifications_outlined,
              count: pending,
              color: Colors.red,
              onTap: () => _pushAndRefresh('/hotel/reservations'),
            ),
            _AppBarBadge(
              icon: Icons.mail_outlined,
              count: unread,
              color: const Color(0xFF1A5276),
              onTap: () => _pushAndRefresh('/hotel/inbox'),
            ),
            IconButton(
              tooltip: 'Perfil del hotel',
              icon: const Icon(Icons.manage_accounts_outlined),
              onPressed: () => _pushAndRefresh('/hotel/profile'),
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
                    icon: Icons.bed_outlined,
                    label: 'Mis\nHabitaciones',
                    color: const Color(0xFF2E86C1),
                    badge: rooms,
                    badgeColor: const Color(0xFF2E86C1),
                    onTap: () => _pushAndRefresh('/hotel/rooms'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.add_box_outlined,
                    label: 'Nuevo\nPaquete',
                    color: const Color(0xFF1A5276),
                    badge: 0,
                    onTap: () => _pushAndRefresh('/hotel/packages/create'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.pending_actions_outlined,
                    label: 'Pendientes',
                    color: pending > 0 ? Colors.orange : Colors.grey,
                    badge: pending,
                    onTap: () => _pushAndRefresh('/hotel/reservations'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickCard(
                    icon: Icons.calendar_month_outlined,
                    label: 'Agendadas',
                    color: const Color(0xFF1A5276),
                    badge: 0,
                    onTap: () => _pushAndRefresh('/hotel/schedule'),
                  ),
                ),
                const SizedBox(width: 8),
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
                    onTap: () => _pushAndRefresh('/hotel/inbox'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              // ── Fila 2: QR de pago ────────────────────────────────
              _QrBanner(
                hasQr: context.watch<AuthProvider>().user?.qrUrl != null &&
                    (context.watch<AuthProvider>().user!.qrUrl!.isNotEmpty),
                onTap: () => _pushAndRefresh('/hotel/qr'),
              ),

              // ── Banner: sin habitaciones ─────────────────────────
              if (rooms == 0) ...[
                const SizedBox(height: 12),
                _NoRoomsBanner(
                  onTap: () => _pushAndRefresh('/hotel/rooms'),
                ),
              ],

              // ── Banner mensajes no leídos ────────────────────────
              if (unread > 0) ...[
                const SizedBox(height: 12),
                _UnreadBanner(
                  count: unread,
                  onTap: () => _pushAndRefresh('/hotel/inbox'),
                ),
              ],

              const SizedBox(height: 20),

              // ── Habitaciones — carrusel ──────────────────────────
              _SectionHeader(
                title: 'Habitaciones registradas',
                trailing: TextButton.icon(
                  onPressed: () => _pushAndRefresh('/hotel/rooms'),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Ver todas'),
                ),
              ),
              const SizedBox(height: 8),

              // FIX: reemplazado ListView horizontal (que causa cuadro gris
              // dentro de SingleChildScrollView) por Wrap tipado con RoomModel
              if (prov.rooms.isEmpty)
                _EmptyCard(
                  icon: Icons.bed_outlined,
                  message:
                      'No tienes habitaciones. ¡Regístralas para poder crear paquetes!',
                  actionLabel: 'Registrar habitación',
                  onAction: () => _pushAndRefresh('/hotel/rooms/create'),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: prov.rooms
                      .map((r) => _RoomMiniCard(room: r))
                      .toList(),
                ),

              const SizedBox(height: 20),

              // ── Paquetes ─────────────────────────────────────────
              _SectionHeader(
                title: 'Mis paquetes',
                trailing: TextButton.icon(
                  onPressed: () => _pushAndRefresh('/hotel/packages/create'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nuevo'),
                ),
              ),
              const SizedBox(height: 8),

              if (prov.packages.isEmpty)
                _EmptyCard(
                  icon: Icons.luggage_outlined,
                  message: 'Aún no tienes paquetes. ¡Crea el primero!',
                  actionLabel: 'Crear paquete',
                  onAction: () => _pushAndRefresh('/hotel/packages/create'),
                )
              else
                ...prov.packages.map((pkg) => _HotelPackageCard(
                      package: pkg,
                      onEdit: () =>
                          _pushAndRefresh('/hotel/packages/edit', extra: pkg),
                      onToggle: () => _handleToggle(context, prov, pkg),
                      onDelete: () => _handleDelete(context, prov, pkg),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Diálogos ──────────────────────────────────────────────────────

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
                backgroundColor:
                    willSuspend ? Colors.orange : Colors.green),
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
            child: Text(
              willSuspend ? 'Suspender' : 'Activar',
              style: const TextStyle(color: Colors.white),
            ),
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
                    ? 'Paquete "$name" eliminado'
                    : prov.error ?? 'Error al eliminar',
                color: ok ? Colors.red.shade700 : Colors.red,
              );
            },
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String  title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData     icon;
  final String       message;
  final String       actionLabel;
  final VoidCallback onAction;
  const _EmptyCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(children: [
          Icon(icon, color: Colors.grey.shade300, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(actionLabel,
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// FIX: tipado correcto con RoomModel en lugar de dynamic
// FIX: widget de ancho fijo sin ListView horizontal (evita cuadro gris)
class _RoomMiniCard extends StatelessWidget {
  final RoomModel room;
  const _RoomMiniCard({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: room.isActive
            ? const Color(0xFFEAF2FF)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: room.isActive
              ? const Color(0xFF2E86C1).withOpacity(0.35)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tipo + estado
          Row(children: [
            Icon(
              _typeIcon(room.roomType),
              color: room.isActive
                  ? const Color(0xFF2E86C1)
                  : Colors.grey,
              size: 16,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                room.roomType.shortLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: room.isActive
                      ? const Color(0xFF2E86C1)
                      : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Punto de estado
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: room.isActive ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          // Nombre
          Text(
            room.roomName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          // Precio
          Text(
            'Bs ${room.pricePerNight.toStringAsFixed(0)}/noche',
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade600),
          ),
          // Capacidad
          Text(
            '${room.capacity} persona(s)',
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(RoomType type) {
    switch (type) {
      case RoomType.single:      return Icons.single_bed_outlined;
      case RoomType.double_:     return Icons.bed_outlined;
      case RoomType.matrimonial: return Icons.king_bed_outlined;
      case RoomType.suite:       return Icons.hotel_outlined;
    }
  }
}

class _NoRoomsBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _NoRoomsBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: Colors.amber, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Registra tus habitaciones antes de crear paquetes. '
              'Toca aquí para comenzar.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.amber),
        ]),
      ),
    );
  }
}

class _AppBarBadge extends StatelessWidget {
  final IconData     icon;
  final int          count;
  final Color        color;
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

class _QuickCard extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final int          badge;
  final Color?       badgeColor;
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
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
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

class _UnreadBanner extends StatelessWidget {
  final int          count;
  final VoidCallback onTap;
  const _UnreadBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A5276), Color(0xFF2E86C1)],
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
                const Text('Toca para leer',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 11)),
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
    final isLodging = package.packageType == PackageType.lodging;

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
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              // Badge tipo
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLodging
                      ? const Color(0xFF1A5276).withOpacity(0.1)
                      : Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isLodging
                        ? Icons.hotel_outlined
                        : Icons.tour_outlined,
                    size: 11,
                    color: isLodging
                        ? const Color(0xFF1A5276)
                        : Colors.teal,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    package.packageType.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isLodging
                          ? const Color(0xFF1A5276)
                          : Colors.teal,
                    ),
                  ),
                ]),
              ),
              // Badge activo/suspendido
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
                    color: package.isActive ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(package.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12)),
            if (package.occupants.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '👥 ${package.occupants.map((o) => o.role).join(", ")}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Bs ${package.pricePerPerson.toStringAsFixed(0)}/persona  ·  '
              '${package.totalReservations} reservas',
              style:
                  const TextStyle(color: Colors.grey, fontSize: 13),
            ),
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
                onToggle,
              ),
              const SizedBox(width: 8),
              _btn(Icons.delete_outline, 'Eliminar', Colors.red, onDelete),
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

// ── Banner de QR de pago ──────────────────────────────────────────────
class _QrBanner extends StatelessWidget {
  final bool         hasQr;
  final VoidCallback onTap;
  const _QrBanner({required this.hasQr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasQr ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasQr ? Colors.green.shade300 : Colors.orange.shade300,
          ),
        ),
        child: Row(children: [
          Icon(
            Icons.qr_code_2,
            color: hasQr ? Colors.green.shade600 : Colors.orange.shade700,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasQr ? 'QR de pago activo' : 'Sin QR de pago',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: hasQr
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                ),
                Text(
                  hasQr
                      ? 'Los turistas pueden ver tu QR al reservar'
                      : 'Toca aquí para subir tu QR y recibir pagos',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasQr
                        ? Colors.green.shade600
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            hasQr ? Icons.edit_outlined : Icons.add_circle_outline,
            color: hasQr ? Colors.green : Colors.orange,
            size: 20,
          ),
        ]),
      ),
    );
  }
}