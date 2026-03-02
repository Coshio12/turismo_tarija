import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/reservation_model.dart';

/// Pantalla del HOTEL para ver el comprobante de pago del turista.
class HotelReceiptScreen extends StatelessWidget {
  final ReservationModel reservation;
  const HotelReceiptScreen({super.key, required this.reservation});

  bool get _isPdf =>
      (reservation.paymentReceiptName ?? '').toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final res = reservation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprobante de pago'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Info reserva ───────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A5276),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                res.isPackage ? res.packageName : res.roomName,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(res.guestName,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Check-in',
                      style: TextStyle(
                          color: Colors.white60, fontSize: 11)),
                  Text(fmt.format(res.checkInDate),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                  const Text('Check-out',
                      style: TextStyle(
                          color: Colors.white60, fontSize: 11)),
                  Text(fmt.format(res.checkOutDate),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                  const Text('Total',
                      style: TextStyle(
                          color: Colors.white60, fontSize: 11)),
                  Text(
                    'Bs ${res.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ]),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Comprobante ────────────────────────────────────────
          const Text('Comprobante adjunto',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),

          if (!res.hasReceipt)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Icon(Icons.pending_outlined,
                    color: Colors.orange.shade700, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'El turista aún no subió su comprobante de pago.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ]),
            )
          else if (_isPdf)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(children: [
                const Icon(Icons.picture_as_pdf,
                    color: Colors.red, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Documento PDF',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      res.paymentReceiptName ?? 'comprobante.pdf',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
              ]),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                res.paymentReceiptUrl!,
                width: double.infinity,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, p) => p == null
                    ? child
                    : Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Icon(Icons.broken_image,
                        size: 50, color: Colors.grey),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // ── Estado del comprobante ─────────────────────────────
          if (res.hasReceipt)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'El turista subió su comprobante. '
                    'Verifica que el pago sea correcto antes de aceptar la reserva.',
                    style: TextStyle(
                        color: Colors.green.shade800, fontSize: 13),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}