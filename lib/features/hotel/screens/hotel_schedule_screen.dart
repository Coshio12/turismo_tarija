import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/reservation_model.dart';
import '../providers/hotel_provider.dart';

class HotelScheduleScreen extends StatefulWidget {
  const HotelScheduleScreen({super.key});
  @override
  State<HotelScheduleScreen> createState() => _HotelScheduleScreenState();
}

class _HotelScheduleScreenState extends State<HotelScheduleScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  String _query = '';

  // Pestañas: Aceptadas | Canceladas | Completadas | Rechazadas
  static const _tabs = [
    (label: 'Aceptadas',   status: ReservationStatus.accepted,  color: Colors.green),
    (label: 'Completadas', status: ReservationStatus.completed, color: Colors.blue),
    (label: 'Canceladas',  status: ReservationStatus.cancelled, color: Colors.orange),
    (label: 'Rechazadas',  status: ReservationStatus.rejected,  color: Colors.red),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ReservationModel> _filtered(ReservationStatus status) {
    final all = context.read<HotelProvider>().allReservations;
    return all.where((r) {
      if (r.status != status) return false;
      if (_query.isEmpty) return true;
      return r.guestName.toLowerCase().contains(_query) ||
             r.guestPhone.contains(_query) ||
             r.packageName.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // watch para que la lista se actualice en tiempo real
    context.watch<HotelProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reservas agendadas'.toUpperCase(),
          style: GoogleFonts.bungee(
            fontWeight: FontWeight.bold,
          )
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
          unselectedLabelStyle: const TextStyle(fontSize: 13, color: Color(0xB3FFFFFF)),
          tabs: _tabs.map((t) {
            final count = _filtered(t.status).length;
            return Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t.label),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: t.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$count',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11)),
                  ),
                ],
              ]),
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          // ── Buscador ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre del huésped o paquete…',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1A5276)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ── Pestañas con reservas ──────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: _tabs.map((t) {
                final list = _filtered(t.status);
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty
                              ? 'No hay reservas ${t.label.toLowerCase()}'
                              : 'Sin resultados para "$_query"',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) =>
                      _ScheduleCard(reservation: list[i], accentColor: t.color),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de reserva agendada ───────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final ReservationModel reservation;
  final Color accentColor;
  const _ScheduleCard(
      {required this.reservation, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final r   = reservation;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withOpacity(0.3), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: accentColor.withOpacity(0.15),
            child: Icon(_statusIcon(r.status), color: accentColor, size: 20),
          ),
          title: Text(r.guestName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.packageName,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.people_outline,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text('${r.numberOfPeople} persona(s)',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(width: 10),
                Icon(Icons.attach_money,
                    size: 13, color: Colors.grey.shade500),
                Text('Bs ${r.totalPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12)),
              ]),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(r.status.label,
                style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _row(Icons.phone_outlined,   'Teléfono', r.guestPhone),
                  _row(Icons.luggage_outlined, 'Paquete',  r.packageName),
                  _row(Icons.calendar_today,
                      'Solicitada', fmt.format(r.createdAt)),
                  if (r.includesLodging && r.checkInDate != null) ...[
                    _row(Icons.login_outlined,  'Check-in',
                        fmt.format(r.checkInDate!)),
                    _row(Icons.logout_outlined, 'Check-out',
                        r.checkOutDate != null
                            ? fmt.format(r.checkOutDate!)
                            : '-'),
                  ],
                  if (r.includesTourGuide && r.tourGuideDate != null)
                    _row(Icons.tour_outlined, 'Guía turística',
                        fmt.format(r.tourGuideDate!)),
                  if (r.hotelMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: accentColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.message_outlined,
                              size: 16, color: accentColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(r.hotelMessage,
                                style: TextStyle(
                                    color: accentColor.withOpacity(0.8),
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
    );
  }

  IconData _statusIcon(ReservationStatus s) {
    switch (s) {
      case ReservationStatus.accepted:  return Icons.check_circle_outline;
      case ReservationStatus.completed: return Icons.star_outline;
      case ReservationStatus.cancelled: return Icons.cancel_outlined;
      case ReservationStatus.rejected:  return Icons.block_outlined;
      default:                          return Icons.hourglass_empty;
    }
  }
}