import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/package_model.dart';

class PackageDetailScreen extends StatelessWidget {
  final PackageModel package;
  const PackageDetailScreen({super.key, required this.package});

  @override
  Widget build(BuildContext context) {
    final loc = package.hotelLocation;
    return Scaffold(
      appBar: AppBar(
        title: Text(package.packageName),
        // El leading se genera automáticamente porque esta pantalla
        // está en el stack (se llegó con push). Se sobreescribe solo
        // para usar el ícono consistente con el resto de la app.
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
            // Info del hotel
            Card(
              child: ListTile(
                leading: const Icon(Icons.hotel, color: Color(0xFF1A5276), size: 32),
                title: Text(
                  package.hotelName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(package.hotelAddress),
              ),
            ),
            const SizedBox(height: 16),

            // Precio
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A5276),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Bs ${package.pricePerPerson.toStringAsFixed(0)} por persona',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Descripción
            const Text(
              'Descripción del paquete',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(package.description, style: const TextStyle(height: 1.6)),
            const SizedBox(height: 20),

            // Ubicación
            const Text(
              'Ubicación del hotel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF2E86C1).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on,
                          color: Color(0xFF1A5276), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          package.hotelAddress,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
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
                  const SizedBox(height: 10),
                  const Text(
                    'Puedes copiar las coordenadas y buscarlas en Google Maps o Waze.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botón reservar — push para apilar /reserve sobre este detalle
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
}