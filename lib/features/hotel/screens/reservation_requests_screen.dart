import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/reservation_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/hotel_provider.dart';

class ReservationRequestsScreen extends StatelessWidget {
  const ReservationRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov    = context.watch<HotelProvider>();
    final pending = prov.pendingReservations;

    return Scaffold(
      appBar: AppBar(
        title: Text('Reservas pendientes (${pending.length})'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: pending.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.green),
                  SizedBox(height: 12),
                  Text('No hay reservas pendientes',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              itemBuilder: (_, i) => _RequestCard(reservation: pending[i]),
            ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  final ReservationModel reservation;
  const _RequestCard({required this.reservation});
  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _showActionSheet(BuildContext context, ReservationStatus status) {
    final label = status == ReservationStatus.accepted
        ? 'Aceptar'
        : status == ReservationStatus.rejected
            ? 'Rechazar'
            : 'Cancelar';
    final color = status == ReservationStatus.accepted
        ? Colors.green
        : status == ReservationStatus.rejected
            ? Colors.red
            : Colors.orange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label reserva',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _msgCtrl,
                decoration: const InputDecoration(
                  labelText:
                      'Mensaje personalizado para el cliente (opcional)',
                  prefixIcon: Icon(Icons.message_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  onPressed: () async {
                    Navigator.pop(context);
                    final user = context.read<AuthProvider>().user!;
                    await context.read<HotelProvider>().updateReservationStatus(
                          reservationId: widget.reservation.reservationId,
                          userId:        widget.reservation.userId,
                          status:        status,
                          hotelMessage:  _msgCtrl.text.trim(),
                          hotelName:     user.hotelName ?? user.displayName,
                          packageName:   widget.reservation.packageName,
                        );
                    _msgCtrl.clear();
                  },
                  child: Text(label,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final res = widget.reservation;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person, color: Color(0xFF1A5276)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  res.guestName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                fmt.format(res.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ]),
            const SizedBox(height: 6),
            _row('Paquete',  res.packageName),
            _row('Teléfono', res.guestPhone),
            _row('Personas', '${res.numberOfPeople}'),
            _row('Total',    'Bs ${res.totalPrice.toStringAsFixed(0)}'),
            if (res.includesLodging && res.checkInDate != null)
              _row('Hospedaje',
                  '${fmt.format(res.checkInDate!)} → '
                  '${res.checkOutDate != null ? fmt.format(res.checkOutDate!) : "?"}'),
            if (res.includesTourGuide && res.tourGuideDate != null)
              _row('Guía', fmt.format(res.tourGuideDate!)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green),
                  onPressed: () =>
                      _showActionSheet(context, ReservationStatus.accepted),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Aceptar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red),
                  onPressed: () =>
                      _showActionSheet(context, ReservationStatus.rejected),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange),
                  onPressed: () =>
                      _showActionSheet(context, ReservationStatus.cancelled),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancelar'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
          width: 90,
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