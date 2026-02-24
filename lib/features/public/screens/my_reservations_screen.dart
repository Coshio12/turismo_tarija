import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/reservation_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/public_provider.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});
  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) context.read<PublicProvider>().listenReservations(uid);
  }

  @override
  Widget build(BuildContext context) {
    final reservations = context.watch<PublicProvider>().reservations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reservas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: reservations.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No tienes reservas todavía.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reservations.length,
              itemBuilder: (_, i) =>
                  _ReservationCard(reservation: reservations[i]),
            ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;
  const _ReservationCard({required this.reservation});

  Color _statusColor() {
    switch (reservation.status) {
      case ReservationStatus.accepted:  return Colors.green;
      case ReservationStatus.rejected:  return Colors.red;
      case ReservationStatus.cancelled: return Colors.orange;
      case ReservationStatus.completed: return Colors.blue;
      default:                          return Colors.grey;
    }
  }

  IconData _statusIcon() {
    switch (reservation.status) {
      case ReservationStatus.accepted:  return Icons.check_circle;
      case ReservationStatus.rejected:  return Icons.cancel;
      case ReservationStatus.cancelled: return Icons.do_not_disturb;
      case ReservationStatus.completed: return Icons.star;
      default:                          return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt   = DateFormat('dd/MM/yyyy');
    final color = _statusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(_statusIcon(), color: color),
          title: Text(
            reservation.packageName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            reservation.hotelName,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              reservation.status.label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _row('Huésped',  reservation.guestName),
                  _row('Teléfono', reservation.guestPhone),
                  _row('Personas', '${reservation.numberOfPeople}'),
                  _row('Total',    'Bs ${reservation.totalPrice.toStringAsFixed(0)}'),
                  if (reservation.includesLodging &&
                      reservation.checkInDate != null) ...[
                    _row('Check-in',  fmt.format(reservation.checkInDate!)),
                    _row('Check-out', reservation.checkOutDate != null
                        ? fmt.format(reservation.checkOutDate!)
                        : '-'),
                  ],
                  if (reservation.includesTourGuide &&
                      reservation.tourGuideDate != null)
                    _row('Guía turística', fmt.format(reservation.tourGuideDate!)),
                  if (reservation.hotelMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.message_outlined,
                              size: 18, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reservation.hotelMessage,
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Creada: ${fmt.format(reservation.createdAt)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}