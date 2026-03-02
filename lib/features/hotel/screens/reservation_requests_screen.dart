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

// ══════════════════════════════════════════════════════════════════════

class _RequestCard extends StatefulWidget {
  final ReservationModel reservation;
  const _RequestCard({required this.reservation});
  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  final _msgCtrl  = TextEditingController();
  DateTime? _tourDate;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  // ── Bottom sheet para aceptar / rechazar / cancelar ───────────────
  void _showActionSheet(BuildContext context, ReservationStatus status) {
    final isAccept  = status == ReservationStatus.accepted;
    final label     = isAccept ? 'Aceptar'
        : status == ReservationStatus.rejected ? 'Rechazar' : 'Cancelar';
    final color     = isAccept ? Colors.green
        : status == ReservationStatus.rejected ? Colors.red : Colors.orange;
    final isPackage = widget.reservation.isPackage;

    // ── Capturamos todo ANTES de abrir el sheet ─────────────────────
    // El contexto del BottomSheet (ctx) se destruye al cerrarse.
    // Provider y messenger se resuelven aquí, en el contexto estable
    // del widget padre, para que la llamada a Firestore funcione siempre.
    final hotelProv = context.read<HotelProvider>();
    final authUser  = context.read<AuthProvider>().user!;
    final messenger = ScaffoldMessenger.of(context);

    _tourDate = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Text(
                  '$label reserva',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                const SizedBox(height: 16),

                // ── Fecha de guía (solo paquetes al aceptar) ─────────
                if (isPackage && isAccept) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.tour_outlined,
                              color: Colors.teal.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Fecha de la guía turística',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800),
                          ),
                          const Spacer(),
                          Text(
                            _tourDate == null ? 'Opcional' : '',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          'Asigna la fecha de la excursión. '
                          'Podrás modificarla más tarde desde el historial.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.teal.shade700),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now()
                                  .add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                            );
                            if (d != null) setSheet(() => _tourDate = d);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _tourDate != null
                                    ? Colors.teal
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: _tourDate != null
                                    ? Colors.teal
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _tourDate != null
                                    ? DateFormat('dd/MM/yyyy')
                                        .format(_tourDate!)
                                    : 'Seleccionar fecha (opcional)',
                                style: TextStyle(
                                  color: _tourDate != null
                                      ? Colors.teal.shade800
                                      : Colors.grey,
                                  fontWeight: _tourDate != null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              if (_tourDate != null)
                                GestureDetector(
                                  onTap: () =>
                                      setSheet(() => _tourDate = null),
                                  child: const Icon(Icons.close,
                                      size: 16, color: Colors.grey),
                                ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Mensaje al cliente ────────────────────────────────
                TextField(
                  controller: _msgCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje para el cliente (opcional)',
                    prefixIcon: Icon(Icons.message_outlined),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: color),
                    onPressed: () async {
                      // Guardamos los valores ANTES de cerrar el sheet
                      final reservationId =
                          widget.reservation.reservationId;
                      final userId      = widget.reservation.userId;
                      final hotelName   =
                          authUser.hotelName ?? authUser.displayName;
                      final packageName =
                          widget.reservation.packageName;
                      final tourDate =
                          (isPackage && isAccept) ? _tourDate : null;
                      final msgText  = _msgCtrl.text.trim();

                      // Cerramos el sheet
                      Navigator.of(ctx).pop();
                      _msgCtrl.clear();

                      // Ejecutamos con el provider resuelto antes del sheet
                      final ok = await hotelProv.updateReservationStatus(
                        reservationId: reservationId,
                        userId:        userId,
                        status:        status,
                        hotelMessage:  msgText,
                        hotelName:     hotelName,
                        packageName:   packageName,
                        tourGuideDate: tourDate,
                      );

                      // Feedback con el messenger capturado antes del sheet
                      messenger.showSnackBar(SnackBar(
                        content: Text(ok
                            ? '$label realizado correctamente'
                            : hotelProv.error ??
                                'Error al actualizar la reserva'),
                        backgroundColor: ok ? color : Colors.red,
                      ));
                    },
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
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
            // ── Cabecera ─────────────────────────────────────────
            Row(children: [
              const Icon(Icons.person, color: Color(0xFF1A5276)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(res.guestName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: res.isPackage
                      ? Colors.teal.shade50
                      : const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    res.isPackage
                        ? Icons.tour_outlined
                        : Icons.bed_outlined,
                    size: 11,
                    color: res.isPackage
                        ? Colors.teal.shade700
                        : const Color(0xFF2E86C1),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    res.reservationType.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: res.isPackage
                          ? Colors.teal.shade700
                          : const Color(0xFF2E86C1),
                    ),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 8),

            // ── Datos ────────────────────────────────────────────
            if (res.isPackage)
              _row('Paquete', res.packageName)
            else
              _row('Habitación', res.roomName),
            _row('Teléfono',  res.guestPhone),
            _row('Personas',  '${res.numberOfPeople}'),
            _row('Total',     'Bs ${res.totalPrice.toStringAsFixed(0)}'),
            _row('Check-in',  fmt.format(res.checkInDate)),
            _row('Check-out', fmt.format(res.checkOutDate)),
            _row('Noches',    '${res.nights}'),
            if (res.isPackage)
              _row('Guía', res.tourGuideAssigned
                  ? fmt.format(res.tourGuideDate!)
                  : 'Pendiente de asignar'),
            _row('Solicitado', fmt.format(res.createdAt)),

            const SizedBox(height: 14),

            // ── Acciones ─────────────────────────────────────────
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green),
                  onPressed: () => _showActionSheet(
                      context, ReservationStatus.accepted),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Aceptar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red),
                  onPressed: () => _showActionSheet(
                      context, ReservationStatus.rejected),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange),
                  onPressed: () => _showActionSheet(
                      context, ReservationStatus.cancelled),
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

  Widget _row(String label, String value) => Padding(
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