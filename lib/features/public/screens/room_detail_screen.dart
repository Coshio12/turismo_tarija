import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/room_model.dart';
import '../../../core/services/firestore_service.dart';

class RoomDetailScreen extends StatefulWidget {
  final RoomModel room;
  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final _firestoreService = FirestoreService();

  List<Map<String, DateTime>> _occupiedRanges = [];
  bool _loadingDates = true;

  @override
  void initState() {
    super.initState();
    _listenOccupied();
  }

  void _listenOccupied() {
    _firestoreService
        .roomOccupiedDatesStream(widget.room.roomId)
        .listen(
      (ranges) {
        if (mounted) {
          setState(() {
            _occupiedRanges = ranges;
            _loadingDates   = false;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _loadingDates = false);
      },
    );
  }

  bool _isOccupied(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    for (final range in _occupiedRanges) {
      final ci = DateTime(range['checkIn']!.year,
          range['checkIn']!.month, range['checkIn']!.day);
      final co = DateTime(range['checkOut']!.year,
          range['checkOut']!.month, range['checkOut']!.day);
      if (!d.isBefore(ci) && d.isBefore(co)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

    return Scaffold(
      appBar: AppBar(
        title: Text(room.roomName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Encabezado ─────────────────────────────────────────
            _RoomHero(room: room),
            const SizedBox(height: 20),

            // ── Descripción ────────────────────────────────────────
            if (room.description.isNotEmpty) ...[
              _sectionTitle('Descripción', Icons.description_outlined),
              const SizedBox(height: 8),
              Text(room.description,
                  style: const TextStyle(height: 1.6, fontSize: 14)),
              const SizedBox(height: 20),
            ],

            // ── Detalles ───────────────────────────────────────────
            _sectionTitle('Detalles', Icons.info_outline),
            const SizedBox(height: 10),
            _DetailGrid(room: room),
            const SizedBox(height: 20),

            // ── Disponibilidad ─────────────────────────────────────
            _sectionTitle(
              'Disponibilidad (próximos 60 días)',
              Icons.calendar_month_outlined,
            ),
            const SizedBox(height: 10),

            if (_loadingDates)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              _AvailabilityCalendar(isOccupied: _isOccupied),

            const SizedBox(height: 16),

            // ── Aviso ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Las fechas mostradas arriba tienen reservas pendientes o confirmadas. El hotel revisará tu solicitud y confirmará la disponibilidad definitiva.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Botón reservar ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(
                  '/home/room/${room.roomId}/reserve',
                  extra: room,
                ),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Reservar esta habitación'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF2E86C1),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Center(
              child: Text(
                'Ofrecida por ${room.hotelName}',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF1A5276)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(children: [
        Icon(icon, color: const Color(0xFF1A5276), size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ]);
}

// ══════════════════════════════════════════════════════════════════════
// DISPONIBILIDAD — lista de rangos ocupados (sin calendario/Stack)
// ══════════════════════════════════════════════════════════════════════

class _AvailabilityCalendar extends StatelessWidget {
  final bool Function(DateTime) isOccupied;

  const _AvailabilityCalendar({required this.isOccupied});

  /// Agrupa los días ocupados en rangos continuos dentro de los próximos 60 días.
  List<({DateTime from, DateTime to})> _occupiedRanges() {
    final today = DateTime.now();
    final days  = List.generate(
        60, (i) => DateTime(today.year, today.month, today.day + i));

    final result = <({DateTime from, DateTime to})>[];
    DateTime? start;
    DateTime? prev;

    for (final d in days) {
      if (isOccupied(d)) {
        start ??= d;
        prev = d;
      } else {
        if (start != null) {
          result.add((from: start, to: prev!));
          start = null;
          prev  = null;
        }
      }
    }
    if (start != null) result.add((from: start, to: prev!));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final fmt    = DateFormat('dd/MM/yyyy');
    final ranges = _occupiedRanges();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Encabezado ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A5276).withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              const Icon(Icons.event_busy_outlined,
                  size: 16, color: Color(0xFF1A5276)),
              const SizedBox(width: 8),
              Text(
                'Fechas NO disponibles (próximos 60 días)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ]),
          ),

          // ── Contenido ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: ranges.isEmpty
                ? Row(children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Todas las fechas están disponibles',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.w500),
                    ),
                  ])
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ranges.map((r) {
                      final label = r.from.isAtSameMomentAs(r.to)
                          ? fmt.format(r.from)
                          : '${fmt.format(r.from)} → ${fmt.format(r.to)}';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.block_outlined,
                              size: 14, color: Colors.red.shade600),
                          const SizedBox(width: 5),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// HERO / DETAIL
// ══════════════════════════════════════════════════════════════════════

class _RoomHero extends StatelessWidget {
  final RoomModel room;
  const _RoomHero({required this.room});

  IconData _icon(RoomType t) {
    switch (t) {
      case RoomType.single:      return Icons.single_bed_outlined;
      case RoomType.double_:     return Icons.bed_outlined;
      case RoomType.matrimonial: return Icons.king_bed_outlined;
      case RoomType.suite:       return Icons.hotel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A5276), Color(0xFF2E86C1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A5276).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon(room.roomType),
                  color: Colors.white, size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.roomName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(room.hotelName,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(Icons.bed_outlined,   room.roomType.shortLabel),
            _chip(Icons.people_outline, '${room.capacity} persona(s)'),
            _chip(Icons.attach_money,
                'Bs ${room.pricePerNight.toStringAsFixed(0)}/noche'),
          ]),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _DetailGrid extends StatelessWidget {
  final RoomModel room;
  const _DetailGrid({required this.room});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          _DetailRow(
              icon: Icons.king_bed_outlined,
              label: 'Tipo de habitación',
              value: room.roomType.label),
          const Divider(height: 20),
          _DetailRow(
              icon: Icons.people_outline,
              label: 'Capacidad máxima',
              value: '${room.capacity} persona(s)'),
          const Divider(height: 20),
          _DetailRow(
              icon: Icons.attach_money,
              label: 'Precio por noche',
              value: 'Bs ${room.pricePerNight.toStringAsFixed(0)}',
              valueColor: const Color(0xFF2E86C1)),
          const Divider(height: 20),
          _DetailRow(
              icon: Icons.hotel_outlined,
              label: 'Hotel',
              value: room.hotelName),
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13))),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: valueColor)),
      ]);
}