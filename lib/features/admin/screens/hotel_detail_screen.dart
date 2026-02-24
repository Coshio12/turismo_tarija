import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/package_model.dart';
import '../../../core/models/user_model.dart';
import '../providers/admin_provider.dart';

class HotelDetailScreen extends StatefulWidget {
  final String hotelId;
  const HotelDetailScreen({super.key, required this.hotelId});
  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  List<PackageModel>? _packages;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final prov = context.read<AdminProvider>();
    final pkgs = await prov.getHotelPackages(widget.hotelId);
    if (mounted) setState(() => _packages = pkgs);
  }

  @override
  Widget build(BuildContext context) {
    final prov  = context.watch<AdminProvider>();
    final UserModel? hotel = prov.hotels
        .where((h) => h.uid == widget.hotelId)
        .isNotEmpty
        ? prov.hotels.firstWhere((h) => h.uid == widget.hotelId)
        : null;

    // Si el hotel fue eliminado mientras esta pantalla está abierta
    if (hotel == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle de hotel'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hotel, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Hotel no encontrado',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(hotel.hotelName ?? hotel.displayName),
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
            // Info hotel
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información del hotel',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(),
                    _row('Email',         hotel.email),
                    _row('Teléfono',      hotel.phone ?? '-'),
                    _row('Dirección',     hotel.address ?? '-'),
                    _row('Estado',        hotel.isActive ? 'Activo' : 'Suspendido'),
                    _row('Total reservas','${hotel.totalReservations}'),
                    if (hotel.location != null)
                      _row(
                        'Coordenadas',
                        'Lat ${hotel.location!.latitude.toStringAsFixed(4)}, '
                        'Lng ${hotel.location!.longitude.toStringAsFixed(4)}',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Paquetes
            const Text(
              'Paquetes creados',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (_packages == null)
              const Center(child: CircularProgressIndicator())
            else if (_packages!.isEmpty)
              const Text(
                'Este hotel no tiene paquetes creados.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ..._packages!.map((pkg) => _PackageStatCard(package: pkg)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }
}

class _PackageStatCard extends StatelessWidget {
  final PackageModel package;
  const _PackageStatCard({required this.package});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              package.isActive ? const Color(0xFF1A5276) : Colors.grey,
          child: Text(
            '${package.totalReservations}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          package.packageName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Bs ${package.pricePerPerson}/persona  ·  '
          '${package.isActive ? "Activo" : "Suspendido"}',
          style: TextStyle(
            color: package.isActive ? Colors.green : Colors.red,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${package.totalReservations}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A5276),
              ),
            ),
            const Text(
              'reservas',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}