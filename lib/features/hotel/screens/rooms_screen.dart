import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/room_model.dart';
import '../providers/hotel_provider.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov  = context.watch<HotelProvider>();
    final rooms = prov.rooms;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mis habitaciones'.toUpperCase(),
          style: GoogleFonts.bungee(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Nueva habitación',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/hotel/rooms/create'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Resumen rápido ────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A5276), Color(0xFF2E86C1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Total', '${rooms.length}'),
                _stat('Activas', '${rooms.where((r) => r.isActive).length}'),
                _stat('Suspendidas', '${rooms.where((r) => !r.isActive).length}'),
              ],
            ),
          ),

          // ── Lista ─────────────────────────────────────────────────
          Expanded(
            child: rooms.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bed, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No tienes habitaciones registradas.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/hotel/rooms/create'),
                          icon: const Icon(Icons.add),
                          label: const Text('Registrar primera habitación'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: rooms.length,
                    itemBuilder: (_, i) => _RoomCard(
                      room: rooms[i],
                      onEdit: () => context.push(
                        '/hotel/rooms/edit',
                        extra: rooms[i],
                      ),
                      onToggle: () => _confirmToggle(context, prov, rooms[i]),
                      onDelete: () => _confirmDelete(context, prov, rooms[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: rooms.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/hotel/rooms/create'),
              icon: const Icon(Icons.add),
              label: const Text('Nueva habitación'),
              backgroundColor: const Color(0xFF1A5276),
            ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }

  void _confirmToggle(BuildContext ctx, HotelProvider prov, RoomModel room) {
    final willSuspend = room.isActive;
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(willSuspend ? 'Suspender habitación' : 'Activar habitación'),
        content: Text(willSuspend
            ? '"${room.roomName}" dejará de estar disponible para paquetes.'
            : '"${room.roomName}" volverá a estar disponible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willSuspend ? Colors.orange : Colors.green,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await prov.toggleRoom(room.roomId, !room.isActive);
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

  void _confirmDelete(BuildContext ctx, HotelProvider prov, RoomModel room) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar habitación'),
        content: Text(
          '¿Eliminar "${room.roomName}"? Esta acción no se puede deshacer.\n\n'
          'Los paquetes que incluyan esta habitación deberán ser actualizados.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await prov.deleteRoom(room.roomId);
            },
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Room Card ─────────────────────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final RoomModel    room;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RoomCard({
    required this.room,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Ícono por tipo
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A5276).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcon(room.roomType),
                    color: const Color(0xFF1A5276), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.roomName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(room.roomType.label,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              // Badge estado
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: room.isActive
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  room.isActive ? 'Activa' : 'Suspendida',
                  style: TextStyle(
                    color: room.isActive ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),

            // Detalles en fila
            Row(children: [
              _chip(Icons.people_outline, '${room.capacity} persona(s)'),
              const SizedBox(width: 12),
              _chip(Icons.attach_money,
                  'Bs ${room.pricePerNight.toStringAsFixed(0)}/noche'),
            ]),
            if (room.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                room.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),

            // Acciones
            Row(children: [
              _btn(Icons.edit_outlined, 'Editar', Colors.blue, onEdit),
              const SizedBox(width: 8),
              _btn(
                room.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                room.isActive ? 'Suspender' : 'Activar',
                room.isActive ? Colors.orange : Colors.green,
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

  Widget _chip(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.grey),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    ]);
  }

  Widget _btn(IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
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