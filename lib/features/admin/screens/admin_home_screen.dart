import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import '../../../core/models/user_model.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with WidgetsBindingObserver {
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Iniciar stream al montar
    context.read<AdminProvider>().listenHotels();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-suscribir cuando la app vuelve de segundo plano
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AdminProvider>().listenHotels();
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch garantiza rebuild cada vez que el provider notifica
    final prov = context.watch<AdminProvider>();
    final hotels = prov.hotels;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Administración'.toUpperCase(),
              style: GoogleFonts.bungee(
                fontWeight: FontWeight.bold,
                // color: Colors.white, // Descomenta si tu AppBar es oscura
              )),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Estadísticas ──────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8), // Espacio para que luzca la sombra
              padding: const EdgeInsets.all(16),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment
                    .spaceAround, // Distribuye mejor los badges
                children: [
                  _StatBadge(
                    label: 'Hoteles registrados',
                    value: '${hotels.length}',
                  ),
                  _StatBadge(
                    label: 'Activos',
                    value: '${hotels.where((h) => h.isActive).length}',
                  ),
                  _StatBadge(
                    label: 'Suspendidos',
                    value: '${hotels.where((h) => !h.isActive).length}',
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Hoteles (por reservas)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),

            Expanded(
              child: hotels.isEmpty
                  ? const Center(
                      child: Text('No hay hoteles registrados',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: hotels.length,
                      // CLAVE: generar cards con índice para que siempre
                      // reciban el objeto actualizado del provider
                      itemBuilder: (_, i) => _HotelAdminCard(
                        hotel: hotels[i],
                        rank: i + 1,
                        onToggle: () => _handleToggle(context, prov, hotels[i]),
                        onDelete: () => _handleDelete(context, prov, hotels[i]),
                        onMessage: () =>
                            _handleMessage(context, prov, hotels[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Acciones con feedback inmediato ──────────────────────────────

  void _handleToggle(
      BuildContext context, AdminProvider prov, UserModel hotel) {
    final willSuspend = hotel.isActive;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(willSuspend ? 'Suspender hotel' : 'Reactivar hotel'),
        content: Text(willSuspend
            ? 'La cuenta de "${hotel.hotelName ?? hotel.displayName}" '
                'quedará suspendida y no podrá iniciar sesión.'
            : 'La cuenta de "${hotel.hotelName ?? hotel.displayName}" '
                'será reactivada.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willSuspend ? Colors.orange : Colors.green,
            ),
            onPressed: () async {
              Navigator.pop(context);
              // Actualización optimista — UI cambia al instante
              final ok = await prov.toggleHotel(hotel.uid, !hotel.isActive);
              _snack(
                ok
                    ? willSuspend
                        ? 'Cuenta de "${hotel.hotelName ?? hotel.displayName}" suspendida'
                        : 'Cuenta de "${hotel.hotelName ?? hotel.displayName}" reactivada'
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
      BuildContext context, AdminProvider prov, UserModel hotel) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar hotel'),
        content: Text(
          'Esto eliminará permanentemente la cuenta de '
          '"${hotel.hotelName ?? hotel.displayName}". '
          'También se cancelarán sus reservas activas.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final name = hotel.hotelName ?? hotel.displayName;
              // Actualización optimista — desaparece al instante
              final ok = await prov.deleteHotel(hotel.uid);
              _snack(
                ok
                    ? 'Hotel "$name" eliminado correctamente'
                    : prov.error ?? 'Error al eliminar',
                color: ok ? Colors.red.shade700 : Colors.red,
              );
            },
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleMessage(
      BuildContext context, AdminProvider prov, UserModel hotel) {
    final subject = TextEditingController();
    final body = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final adminId = context.read<AuthProvider>().user!.uid;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mensaje a "${hotel.hotelName ?? hotel.displayName}"',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subject,
                decoration: const InputDecoration(
                    labelText: 'Asunto', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (subject.text.isEmpty || body.text.isEmpty) {
                      return;
                    }
                    Navigator.pop(context);
                    final ok = await prov.sendMessage(
                      hotelId: hotel.uid,
                      adminId: adminId,
                      subject: subject.text.trim(),
                      body: body.text.trim(),
                    );
                    _snack(
                      ok
                          ? 'Mensaje enviado correctamente'
                          : prov.error ?? 'Error al enviar',
                      color: ok ? Colors.green : Colors.red,
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar mensaje'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Stat Badge ────────────────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final String label, value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Hotel Admin Card ──────────────────────────────────────────────────
// Recibe los callbacks desde el padre que tiene context.watch,
// igual que _HotelPackageCard en hotel_home_screen.
// Así los cambios de isActive se reflejan inmediatamente.
class _HotelAdminCard extends StatelessWidget {
  final UserModel hotel;
  final int rank;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onMessage;

  const _HotelAdminCard({
    required this.hotel,
    required this.rank,
    required this.onToggle,
    required this.onDelete,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final name = hotel.hotelName ?? hotel.displayName;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hotel.isActive
              ? Colors.transparent
              : Colors.orange.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────
          Row(children: [
            // Badge de ranking
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: rank == 1
                    ? Colors.amber
                    : rank == 2
                        ? Colors.grey.shade400
                        : rank == 3
                            ? Colors.brown.shade300
                            : const Color(0xFFEAF2FF),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('#$rank',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: rank <= 3 ? Colors.white : Colors.grey)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(hotel.email,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            // Badge de estado — se actualiza con el rebuild del padre
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hotel.isActive
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hotel.isActive
                      ? Colors.green.shade200
                      : Colors.orange.shade300,
                ),
              ),
              child: Text(
                hotel.isActive ? 'Activo' : 'Suspendido',
                style: TextStyle(
                    color: hotel.isActive ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // ── Estadísticas ────────────────────────────────────────
          Row(children: [
            const Icon(Icons.bookmark_border, size: 15, color: Colors.grey),
            const SizedBox(width: 4),
            Text('${hotel.totalReservations} reservas totales',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            if (!hotel.isActive) ...[
              const SizedBox(width: 12),
              const Icon(Icons.warning_amber_outlined,
                  size: 15, color: Colors.orange),
              const SizedBox(width: 4),
              const Text('Cuenta suspendida',
                  style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ]),
          const SizedBox(height: 12),

          // ── Acciones ────────────────────────────────────────────
          Column(
            children: [
              // Primera fila (2 botones)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/admin/hotel/${hotel.uid}'),
                      icon: const Icon(Icons.info_outline, size: 15),
                      label:
                          const Text('Detalle', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            hotel.isActive ? Colors.orange : Colors.green,
                        side: BorderSide(
                            color:
                                hotel.isActive ? Colors.orange : Colors.green),
                      ),
                      onPressed: onToggle,
                      icon: Icon(
                          hotel.isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          size: 15),
                      label: Text(hotel.isActive ? 'Suspender' : 'Activar',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6), // Espacio vertical entre filas

              // Segunda fila (2 botones)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue)),
                      onPressed: onMessage,
                      icon: const Icon(Icons.send, size: 15),
                      label:
                          const Text('Mensaje', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 15),
                      label: const Text('Eliminar',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          )
        ]),
      ),
    );
  }
}
