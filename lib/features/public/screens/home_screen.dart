import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/public_provider.dart';
import '../../../core/models/package_model.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    context.read<PublicProvider>().listenPackages();
  }

  Future<void> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presiona de nuevo para salir'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PublicProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'TURISMO TARIJA',
            style: GoogleFonts.bungee(
              fontWeight: FontWeight.bold,
              // color: Colors.white, // Descomenta si tu AppBar es oscura
            ),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              tooltip: 'Mis reservas'.toUpperCase(),
              // push para apilar sobre /home y poder volver
              onPressed: () => context.push('/home/my-reservations'),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Expanded(
              child: prov.packages.isEmpty
                  ? const Center(
                      child:
                          Text('No hay paquetes disponibles por el momento.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: prov.packages.length,
                      itemBuilder: (_, i) =>
                          _PackageCard(package: prov.packages[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final PackageModel package;
  const _PackageCard({required this.package});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/home/package/${package.packageId}',
          extra: package,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.hotel, color: Color(0xFF1A5276)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    package.hotelName,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                package.packageName,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                package.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bs ${package.pricePerPerson.toStringAsFixed(0)}/persona',
                    style: const TextStyle(
                      color: Color(0xFF1A5276),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
