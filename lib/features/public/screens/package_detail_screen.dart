import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/package_model.dart';
import '../../../core/models/room_model.dart';

class PackageDetailScreen extends StatelessWidget {
  final PackageModel package;
  const PackageDetailScreen({super.key, required this.package});

  @override
  Widget build(BuildContext context) {
    final loc       = package.hotelLocation;
    final isLodging = package.packageType == PackageType.lodging;

    return Scaffold(
      appBar: AppBar(
        title: Text(package.packageName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                isLodging ? Icons.hotel_outlined : Icons.tour_outlined,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                package.packageType.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ]),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Info del hotel ──────────────────────────────────────
            Card(
              child: ListTile(
                leading: const Icon(Icons.hotel,
                    color: Color(0xFF1A5276), size: 32),
                title: Text(package.hotelName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(package.hotelAddress),
              ),
            ),
            const SizedBox(height: 16),

            // ── Precio ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A5276),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.attach_money, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Bs ${package.pricePerPerson.toStringAsFixed(0)} por persona',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${package.minPeople} a ${package.maxPeople} pers.',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Descripción ─────────────────────────────────────────
            const Text('Descripción del paquete',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(package.description,
                style: const TextStyle(height: 1.6)),
            const SizedBox(height: 20),

            // ── Ocupantes ───────────────────────────────────────────
            if (package.occupants.isNotEmpty) ...[
              _sectionTitle('Composición del paquete',
                  Icons.people_alt_outlined),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: package.occupants
                        .map((occ) => _OccupantBadge(occupant: occ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Habitaciones ────────────────────────────────────────
            if (package.rooms.isNotEmpty) ...[
              _sectionTitle('Habitaciones incluidas', Icons.bed_outlined),
              const SizedBox(height: 10),
              ...package.rooms.map((room) => _RoomDetailCard(room: room)),
              const SizedBox(height: 10),
            ],

            // ── Servicios ───────────────────────────────────────────
            if (package.includedServices.isNotEmpty) ...[
              _sectionTitle('Servicios incluidos', Icons.room_service_outlined),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: package.includedServices.map((svc) => Chip(
                  avatar: const Icon(Icons.check_circle,
                      size: 16, color: Colors.green),
                  label: Text(svc,
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.green.shade50,
                  side: BorderSide(color: Colors.green.shade200),
                )).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // ── Ubicación ───────────────────────────────────────────
            _sectionTitle('Ubicación del hotel', Icons.location_on_outlined),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF2E86C1).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Icon(Icons.location_on,
                        color: Color(0xFF1A5276), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(package.hotelAddress,
                          style: const TextStyle(fontSize: 14, height: 1.4)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.my_location,
                        color: Color(0xFF2E86C1), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Lat: ${loc.latitude.toStringAsFixed(6)},  '
                      'Lng: ${loc.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2E86C1),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Copia las coordenadas y búscalas en Google Maps o Waze.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Botón reservar ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(
                  '/home/package/${package.packageId}/reserve',
                  extra: package,
                ),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Hacer una reserva'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: const Color(0xFF1A5276), size: 20),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ]);
  }
}

// ── Badge de ocupante ─────────────────────────────────────────────────
class _OccupantBadge extends StatelessWidget {
  final OccupantEntry occupant;
  const _OccupantBadge({required this.occupant});

  @override
  Widget build(BuildContext context) {
    final isChild = occupant.ageGroup == AppConstants.ageGroupChild ||
        occupant.ageGroup == AppConstants.ageGroupInfant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A5276).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF1A5276).withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          isChild ? Icons.child_care : Icons.person,
          size: 18,
          color: const Color(0xFF1A5276),
        ),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(occupant.role,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1A5276))),
          Text(occupant.ageLabel,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ]),
    );
  }
}

// ── Tarjeta de habitación del paquete ─────────────────────────────────
class _RoomDetailCard extends StatelessWidget {
  final PackageRoomEntry room;
  const _RoomDetailCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final roomType = RoomTypeX.fromString(room.roomType);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E86C1).withOpacity(0.12),
          child: Icon(_typeIcon(roomType),
              color: const Color(0xFF2E86C1), size: 22),
        ),
        title: Text(room.roomName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${roomType.label}  ·  ${room.nights} noche(s)'
          '${room.extraBeds > 0 ? "  ·  ${room.extraBeds} cama(s) adicional(es)" : ""}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2E86C1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${room.nights} noche(s)',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2E86C1),
                  fontWeight: FontWeight.bold)),
        ),
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