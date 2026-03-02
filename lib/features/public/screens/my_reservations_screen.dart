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
  State<MyReservationsScreen> createState() =>
      _MyReservationsScreenState();
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
                  Text('No tienes reservas todavía.',
                      style: TextStyle(color: Colors.grey)),
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

// ══════════════════════════════════════════════════════════════════════

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
    final res   = reservation;
    final title = res.isPackage ? res.packageName : res.roomName;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(_statusIcon(), color: color),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Row(children: [
            Text(res.hotelName,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: res.isPackage
                    ? Colors.teal.shade50
                    : const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                res.reservationType.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: res.isPackage
                      ? Colors.teal.shade700
                      : const Color(0xFF2E86C1),
                ),
              ),
            ),
          ]),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              res.status.label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _row('Huésped',   res.guestName),
                  _row('Teléfono',  res.guestPhone),
                  _row('Personas',  '${res.numberOfPeople}'),
                  _row('Total',     'Bs ${res.totalPrice.toStringAsFixed(0)}'),
                  _row('Check-in',  fmt.format(res.checkInDate)),
                  _row('Check-out', fmt.format(res.checkOutDate)),
                  _row('Noches',    '${res.nights}'),

                  if (res.isPackage) ...[
                    const SizedBox(height: 6),
                    res.tourGuideAssigned
                        ? _tourRow(fmt.format(res.tourGuideDate!), assigned: true)
                        : _tourRow('Pendiente — el hotel asignará la fecha',
                            assigned: false),
                  ],

                  if (res.hotelMessage.isNotEmpty) ...[
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
                            child: Text(res.hotelMessage,
                                style: const TextStyle(color: Colors.blue)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // ── Botón de pago ─────────────────────────────────
                  // Se muestra siempre que la reserva no esté cancelada/rechazada
                  if (res.status != ReservationStatus.cancelled &&
                      res.status != ReservationStatus.rejected) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/home/payment', extra: res),
                        icon: Icon(
                          res.hasReceipt
                              ? Icons.receipt_long
                              : Icons.qr_code_2,
                          size: 18,
                        ),
                        label: Text(res.hasReceipt
                            ? 'Ver comprobante'
                            : 'Ver QR / Subir comprobante'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: res.hasReceipt
                              ? Colors.green
                              : const Color(0xFF1A5276),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  Text(
                    'Solicitada: ${fmt.format(res.createdAt)}',
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

  Widget _tourRow(String value, {required bool assigned}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
            width: 110,
            child: Row(children: [
              Icon(Icons.tour_outlined,
                  size: 14, color: assigned ? Colors.teal : Colors.grey),
              const SizedBox(width: 4),
              const Text('Guía',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: assigned ? Colors.teal.shade700 : Colors.grey,
                fontStyle: assigned ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ]),
      );

  Widget _row(String label, String value) => Padding(
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