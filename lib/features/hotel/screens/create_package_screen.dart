import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/package_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/hotel_provider.dart';

class CreatePackageScreen extends StatefulWidget {
  final PackageModel? packageToEdit;
  const CreatePackageScreen({super.key, this.packageToEdit});
  @override
  State<CreatePackageScreen> createState() => _CreatePackageScreenState();
}

class _CreatePackageScreenState extends State<CreatePackageScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _pkgName     = TextEditingController();
  final _description = TextEditingController();
  final _price       = TextEditingController();
  final _address     = TextEditingController();
  final _latCtrl     = TextEditingController();
  final _lngCtrl     = TextEditingController();

  bool    _geoLoading = false;
  String? _geoError;
  bool get _isEdit => widget.packageToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final pkg = widget.packageToEdit!;
      _pkgName.text     = pkg.packageName;
      _description.text = pkg.description;
      _price.text       = pkg.pricePerPerson.toStringAsFixed(0);
      _address.text     = pkg.hotelAddress;
      _latCtrl.text     = pkg.hotelLocation.latitude.toStringAsFixed(6);
      _lngCtrl.text     = pkg.hotelLocation.longitude.toStringAsFixed(6);
    }
  }

  @override
  void dispose() {
    _pkgName.dispose();
    _description.dispose();
    _price.dispose();
    _address.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _geoLoading = true;
      _geoError   = null;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _geoError =
            'Permiso denegado permanentemente. Actívalo en ajustes del dispositivo.');
        return;
      }
      if (perm == LocationPermission.denied) {
        setState(() => _geoError = 'Permiso de ubicación denegado.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
        _geoError     = null;
      });
    } catch (e) {
      setState(() => _geoError = 'No se pudo obtener la ubicación.');
    } finally {
      setState(() => _geoLoading = false);
    }
  }

  GeoPoint? _buildGeoPoint() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return GeoPoint(lat, lng);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final geo = _buildGeoPoint();
    if (geo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ingresa coordenadas válidas o usa el geolocalizador'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final user = context.read<AuthProvider>().user!;
    final prov = context.read<HotelProvider>();

    if (_isEdit) {
      final ok = await prov.updatePackage(widget.packageToEdit!.packageId, {
        'packageName':    _pkgName.text.trim(),
        'description':    _description.text.trim(),
        'pricePerPerson': double.parse(_price.text),
        'hotelAddress':   _address.text.trim(),
        'hotelLocation':  geo,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Paquete actualizado' : prov.error ?? 'Error'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
        if (ok) context.pop(); // volver al hotel home
      }
    } else {
      final pkg = PackageModel(
        packageId:         '',
        hotelId:           user.uid,
        hotelName:         user.hotelName ?? user.displayName,
        hotelLocation:     geo,
        hotelAddress:      _address.text.trim(),
        packageName:       _pkgName.text.trim(),
        description:       _description.text.trim(),
        pricePerPerson:    double.parse(_price.text),
        isActive:          true,
        totalReservations: 0,
        createdAt:         DateTime.now(),
        updatedAt:         DateTime.now(),
      );
      final ok = await prov.createPackage(pkg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '¡Paquete creado exitosamente!' : prov.error ?? 'Error'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
        if (ok) context.pop(); // volver al hotel home
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<HotelProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar paquete' : 'Nuevo paquete'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_pkgName, 'Nombre del paquete', Icons.luggage),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Descripción (servicios incluidos)',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              _field(
                _price,
                'Costo por persona (Bs)',
                Icons.attach_money,
                type: TextInputType.number,
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return (n != null && n > 0) ? null : 'Precio inválido';
                },
              ),
              const SizedBox(height: 12),
              _field(_address, 'Dirección (calle, barrio, ciudad)',
                  Icons.location_on_outlined),
              const SizedBox(height: 16),

              // Coordenadas
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
                    const Row(children: [
                      Icon(Icons.my_location,
                          color: Color(0xFF1A5276), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Coordenadas del hotel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A5276),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    const Text(
                      'Usa el geolocalizador para detectar tu posición actual, '
                      'o escribe las coordenadas manualmente.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _geoLoading ? null : _detectLocation,
                        icon: _geoLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.gps_fixed),
                        label: Text(_geoLoading
                            ? 'Obteniendo ubicación…'
                            : 'Usar mi ubicación actual'),
                      ),
                    ),
                    if (_geoError != null) ...[
                      const SizedBox(height: 8),
                      Text(_geoError!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'O ingresa las coordenadas manualmente:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Latitud',
                            hintText: '-21.535500',
                            prefixIcon: Icon(Icons.south, size: 18),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              signed: true, decimal: true),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final n = double.tryParse(v?.trim() ?? '');
                            if (n == null) return 'Inválida';
                            if (n < -90 || n > 90) return '-90 a 90';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lngCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Longitud',
                            hintText: '-64.729600',
                            prefixIcon: Icon(Icons.west, size: 18),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              signed: true, decimal: true),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final n = double.tryParse(v?.trim() ?? '');
                            if (n == null) return 'Inválida';
                            if (n < -180 || n > 180) return '-180 a 180';
                            return null;
                          },
                        ),
                      ),
                    ]),
                    if (_latCtrl.text.isNotEmpty &&
                        _lngCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Lat ${_latCtrl.text}, Lng ${_lngCtrl.text}',
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: prov.loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _save,
                        icon: Icon(_isEdit ? Icons.save : Icons.add),
                        label: Text(
                            _isEdit ? 'Guardar cambios' : 'Crear paquete'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      keyboardType: type,
      validator: validator ?? (v) => v!.isEmpty ? 'Requerido' : null,
    );
  }
}