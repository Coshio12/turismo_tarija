import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/package_model.dart';
import '../../../core/models/room_model.dart';
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
  final _guidePrice  = TextEditingController(); // precio guía/persona
  final _address     = TextEditingController();
  final _latCtrl     = TextEditingController();
  final _lngCtrl     = TextEditingController();

  PackageType _packageType = PackageType.tourist;

  final List<OccupantEntry>    _occupants     = [];
  final List<PackageRoomEntry> _selectedRooms = [];
  List<RoomModel> _availableRooms = [];
  bool _loadingRooms = false;

  final Set<String> _selectedServices = {};

  bool _geoLoading = false;
  String? _geoError;

  bool get _isEdit => widget.packageToEdit != null;

  // ── Totales reactivos ─────────────────────────────────────────────
  double get _roomsTotal =>
      _selectedRooms.fold(0.0, (s, r) => s + r.subtotal);

  double get _guideTotal {
    if (_packageType != PackageType.tourist) return 0;
    final g = double.tryParse(_guidePrice.text.trim()) ?? 0;
    return g * _occupants.length;
  }

  @override
  void initState() {
    super.initState();
    _guidePrice.addListener(() => setState(() {}));

    if (_isEdit) {
      final pkg = widget.packageToEdit!;
      _pkgName.text     = pkg.packageName;
      _description.text = pkg.description;
      _guidePrice.text  = pkg.guidePricePerPerson > 0
          ? pkg.guidePricePerPerson.toStringAsFixed(0)
          : '';
      _address.text = pkg.hotelAddress;
      _latCtrl.text = pkg.hotelLocation.latitude.toStringAsFixed(6);
      _lngCtrl.text = pkg.hotelLocation.longitude.toStringAsFixed(6);
      _packageType  = pkg.packageType;
      _occupants.addAll(pkg.occupants);
      _selectedRooms.addAll(pkg.rooms);
      _selectedServices.addAll(pkg.includedServices);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRooms());
  }

  @override
  void dispose() {
    _pkgName.dispose();
    _description.dispose();
    _guidePrice.dispose();
    _address.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    final user = context.read<AuthProvider>().user!;
    setState(() => _loadingRooms = true);
    try {
      final rooms =
          await context.read<HotelProvider>().getActiveRooms(user.uid);
      setState(() => _availableRooms = rooms);
    } finally {
      setState(() => _loadingRooms = false);
    }
  }

  Future<void> _detectLocation() async {
    setState(() { _geoLoading = true; _geoError = null; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _geoError = 'Permiso denegado permanentemente.');
        return;
      }
      if (perm == LocationPermission.denied) {
        setState(() => _geoError = 'Permiso de ubicación denegado.');
        return;
      }
      // ignore: deprecated_member_use
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
        _geoError     = null;
      });
    } catch (_) {
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

  // ── Agregar ocupante ──────────────────────────────────────────────
  void _addOccupant() {
    String role     = '';
    String ageGroup = AppConstants.ageGroupAdult;
    final roleCtrl  = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) {
        return Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 20,
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Agregar ocupante',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 14),
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(
                labelText: 'Rol del ocupante',
                hintText: 'Ej: padre, madre, hijo, abuela…',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => role = v.trim(),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Grupo de edad:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final (val, label) in [
                (AppConstants.ageGroupAdult,  'Adulto'),
                (AppConstants.ageGroupChild,  'Niño'),
                (AppConstants.ageGroupInfant, 'Infante'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: ageGroup == val,
                  selectedColor: const Color(0xFF1A5276),
                  labelStyle: TextStyle(
                      color: ageGroup == val ? Colors.white : Colors.black87),
                  onSelected: (_) => setS(() => ageGroup = val),
                ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (role.isEmpty) return;
                  setState(() =>
                      _occupants.add(OccupantEntry(role: role, ageGroup: ageGroup)));
                  Navigator.pop(ctx2);
                },
                child: const Text('Agregar'),
              ),
            ),
          ]),
        );
      }),
    );
  }

  // ── Agregar habitación ────────────────────────────────────────────
  void _addRoom() {
    if (_availableRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'No tienes habitaciones activas. Primero regístralas en "Mis Habitaciones".'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    RoomModel? selected = _availableRooms.first;
    int nights    = 1;
    int extraBeds = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) {
        final subtotal = (selected?.pricePerNight ?? 0) * nights;

        return Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 20,
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Asignar habitación',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 14),

            // Selector de habitación
            DropdownButtonFormField<RoomModel>(
              value: selected,
              decoration: const InputDecoration(
                labelText: 'Habitación',
                prefixIcon: Icon(Icons.bed_outlined),
                border: OutlineInputBorder(),
              ),
              items: _availableRooms
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(
                          '${r.roomName}  ·  ${r.roomType.shortLabel}'
                          '  ·  Bs ${r.pricePerNight.toStringAsFixed(0)}/noche',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setS(() => selected = v),
            ),
            const SizedBox(height: 12),

            // Noches
            Row(children: [
              const Expanded(
                  child: Text('Noches incluidas:',
                      style: TextStyle(fontWeight: FontWeight.w500))),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: nights > 1 ? () => setS(() => nights--) : null,
              ),
              Text('$nights',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setS(() => nights++),
              ),
            ]),

            // Camas adicionales
            Row(children: [
              const Expanded(
                  child: Text('Camas adicionales:',
                      style: TextStyle(fontWeight: FontWeight.w500))),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed:
                    extraBeds > 0 ? () => setS(() => extraBeds--) : null,
              ),
              Text('$extraBeds',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setS(() => extraBeds++),
              ),
            ]),

            // Subtotal de esta habitación
            if (selected != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bs ${selected!.pricePerNight.toStringAsFixed(0)}'
                      ' × $nights noche(s)',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                    ),
                    Text(
                      'Bs ${subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A5276),
                          fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (selected == null) return;
                  setState(() => _selectedRooms.add(PackageRoomEntry(
                    roomId:        selected!.roomId,
                    roomName:      selected!.roomName,
                    roomType:      selected!.roomType.value,
                    nights:        nights,
                    extraBeds:     extraBeds,
                    pricePerNight: selected!.pricePerNight, // ← capturado
                  )));
                  Navigator.pop(ctx2);
                },
                child: const Text('Agregar al paquete'),
              ),
            ),
          ]),
        );
      }),
    );
  }

  // ── Guardar ───────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final geo = _buildGeoPoint();
    if (geo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ingresa coordenadas válidas'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (_occupants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Agrega al menos un ocupante al paquete'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final guidePrice = double.tryParse(_guidePrice.text.trim()) ?? 0;
    final user = context.read<AuthProvider>().user!;
    final prov = context.read<HotelProvider>();

    final dataMap = {
      'packageName':         _pkgName.text.trim(),
      'description':         _description.text.trim(),
      'pricePerPerson':      guidePrice,       // alias legacy
      'guidePricePerPerson': guidePrice,
      'hotelAddress':        _address.text.trim(),
      'hotelLocation':       geo,
      'packageType':         _packageType.value,
      'occupants':           _occupants.map((e) => e.toMap()).toList(),
      'rooms':               _selectedRooms.map((e) => e.toMap()).toList(),
      'includedServices':    _selectedServices.toList(),
      'totalNights':         _selectedRooms.isEmpty
          ? 0
          : _selectedRooms.map((r) => r.nights).reduce((a, b) => a > b ? a : b),
      'minPeople': _occupants.length,
      'maxPeople': _occupants.length,
    };

    if (_isEdit) {
      final ok =
          await prov.updatePackage(widget.packageToEdit!.packageId, dataMap);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Paquete actualizado' : prov.error ?? 'Error'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
        if (ok) context.pop();
      }
    } else {
      final pkg = PackageModel(
        packageId:            '',
        hotelId:              user.uid,
        hotelName:            user.hotelName ?? user.displayName,
        hotelLocation:        geo,
        hotelAddress:         _address.text.trim(),
        packageName:          _pkgName.text.trim(),
        description:          _description.text.trim(),
        guidePricePerPerson:  guidePrice,
        isActive:             true,
        totalReservations:    0,
        createdAt:            DateTime.now(),
        updatedAt:            DateTime.now(),
        packageType:          _packageType,
        occupants:            _occupants,
        rooms:                _selectedRooms,
        includedServices:     _selectedServices.toList(),
        totalNights:          _selectedRooms.isEmpty
            ? 0
            : _selectedRooms
                .map((r) => r.nights)
                .reduce((a, b) => a > b ? a : b),
        minPeople: _occupants.length,
        maxPeople: _occupants.length,
      );
      final ok = await prov.createPackage(pkg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '¡Paquete creado!' : prov.error ?? 'Error'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
        if (ok) context.pop();
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────
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

              // ── Tipo de paquete ───────────────────────────────────
              const Text('Tipo de paquete',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              Row(
                children: PackageType.values.map((type) {
                  final sel = _packageType == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _packageType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF1A5276)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF1A5276)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(children: [
                          Icon(
                            type == PackageType.lodging
                                ? Icons.hotel_outlined
                                : Icons.tour_outlined,
                            color: sel ? Colors.white : Colors.grey,
                            size: 26,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            type.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.grey,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Datos básicos ─────────────────────────────────────
              _field(_pkgName, 'Nombre del paquete', Icons.luggage),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Descripción general',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              // ── Precio guía turística ─────────────────────────────
              if (_packageType == PackageType.tourist) ...[
                _field(
                  _guidePrice,
                  'Precio del servicio de guía turística (Bs/persona)',
                  Icons.tour_outlined,
                  type: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.trim());
                    return (n != null && n >= 0) ? null : 'Precio inválido';
                  },
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Se suma al costo de las habitaciones. '
                    'Se cobra por persona.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              _field(_address, 'Dirección del hotel',
                  Icons.location_on_outlined),
              const SizedBox(height: 16),

              // ── Coordenadas ───────────────────────────────────────
              _coordSection(),
              const SizedBox(height: 20),

              // ── Ocupantes ─────────────────────────────────────────
              _sectionHeader(
                  'Ocupantes del paquete', Icons.people_alt_outlined,
                  onAdd: _addOccupant),
              if (_occupants.isEmpty)
                _emptyHint(
                    'Agrega los integrantes del paquete (ej: padre, madre, hijo).')
              else
                ..._occupants
                    .asMap()
                    .entries
                    .map((e) => _occupantChip(e.key, e.value)),
              const SizedBox(height: 20),

              // ── Habitaciones ──────────────────────────────────────
              _sectionHeader('Habitaciones asignadas', Icons.bed_outlined,
                  onAdd: _addRoom),
              if (_loadingRooms)
                const Center(child: CircularProgressIndicator())
              else if (_selectedRooms.isEmpty)
                _emptyHint(
                    'Asigna habitaciones de tu inventario. '
                    'El precio de cada una se calcula automáticamente.')
              else ...[
                ..._selectedRooms
                    .asMap()
                    .entries
                    .map((e) => _roomChip(e.key, e.value)),
                const SizedBox(height: 10),
                _PriceBreakdown(
                  roomsTotal:  _roomsTotal,
                  guideTotal:  _guideTotal,
                  guidePrice:  double.tryParse(_guidePrice.text.trim()) ?? 0,
                  numPeople:   _occupants.length,
                  packageType: _packageType,
                  rooms:       _selectedRooms,
                ),
              ],
              const SizedBox(height: 20),

              // ── Servicios incluidos ───────────────────────────────
              _sectionHeader(
                  'Servicios incluidos', Icons.room_service_outlined),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: AppConstants.defaultServices.map((svc) {
                  final sel = _selectedServices.contains(svc);
                  return FilterChip(
                    label: Text(svc),
                    selected: sel,
                    selectedColor:
                        const Color(0xFF1A5276).withOpacity(0.15),
                    checkmarkColor: const Color(0xFF1A5276),
                    labelStyle: TextStyle(
                      color: sel
                          ? const Color(0xFF1A5276)
                          : Colors.black87,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setState(() {
                      sel
                          ? _selectedServices.remove(svc)
                          : _selectedServices.add(svc);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── Botón guardar ─────────────────────────────────────
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

  // ── Widgets auxiliares ────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon,
      {VoidCallback? onAdd}) =>
      Row(children: [
        Icon(icon, color: const Color(0xFF1A5276), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        if (onAdd != null)
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar'),
          ),
      ]);

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
      );

  Widget _occupantChip(int index, OccupantEntry occ) => Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor:
                const Color(0xFF1A5276).withOpacity(0.12),
            child: Icon(
              occ.ageGroup == AppConstants.ageGroupChild ||
                      occ.ageGroup == AppConstants.ageGroupInfant
                  ? Icons.child_care
                  : Icons.person_outline,
              size: 18,
              color: const Color(0xFF1A5276),
            ),
          ),
          title: Text(occ.role,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(occ.ageLabel,
              style: const TextStyle(fontSize: 12)),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: () =>
                setState(() => _occupants.removeAt(index)),
          ),
        ),
      );

  Widget _roomChip(int index, PackageRoomEntry entry) {
    final typeLabel =
        RoomTypeX.fromString(entry.roomType).shortLabel;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor:
              const Color(0xFF2E86C1).withOpacity(0.12),
          child: const Icon(Icons.bed_outlined,
              size: 18, color: Color(0xFF2E86C1)),
        ),
        title: Text(entry.roomName,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          '$typeLabel  ·  ${entry.nights} noche(s)  ·  '
          'Bs ${entry.pricePerNight.toStringAsFixed(0)}/noche'
          '${entry.extraBeds > 0 ? "  ·  ${entry.extraBeds} cama(s) extra" : ""}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Bs ${entry.subtotal.toStringAsFixed(0)}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A5276),
                fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: () =>
                setState(() => _selectedRooms.removeAt(index)),
          ),
        ]),
      ),
    );
  }

  Widget _coordSection() => Container(
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
            const Row(children: [
              Icon(Icons.my_location,
                  color: Color(0xFF1A5276), size: 18),
              SizedBox(width: 8),
              Text('Coordenadas del hotel',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A5276))),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _geoLoading ? null : _detectLocation,
                icon: _geoLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.gps_fixed),
                label: Text(_geoLoading
                    ? 'Obteniendo…'
                    : 'Usar mi ubicación actual'),
              ),
            ),
            if (_geoError != null) ...[
              const SizedBox(height: 6),
              Text(_geoError!,
                  style: const TextStyle(
                      color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 12),
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
          ],
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        decoration:
            InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        keyboardType: type,
        validator: validator ?? (v) => v!.isEmpty ? 'Requerido' : null,
      );
}

// ── Desglose de precio ────────────────────────────────────────────────

class _PriceBreakdown extends StatelessWidget {
  final double             roomsTotal;
  final double             guideTotal;
  final double             guidePrice;
  final int                numPeople;
  final PackageType        packageType;
  final List<PackageRoomEntry> rooms;

  const _PriceBreakdown({
    required this.roomsTotal,
    required this.guideTotal,
    required this.guidePrice,
    required this.numPeople,
    required this.packageType,
    required this.rooms,
  });

  @override
  Widget build(BuildContext context) {
    final isTourist = packageType == PackageType.tourist;
    final total     = roomsTotal + guideTotal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF2E86C1).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calculate_outlined,
                color: Color(0xFF1A5276), size: 18),
            const SizedBox(width: 8),
            const Text('Desglose del precio',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A5276))),
          ]),
          const SizedBox(height: 10),

          // Una línea por habitación
          ...rooms.map((r) => _line(
                '${r.roomName}  (${r.nights} noche(s) × '
                'Bs ${r.pricePerNight.toStringAsFixed(0)})',
                'Bs ${r.subtotal.toStringAsFixed(0)}',
              )),

          const Divider(height: 14),
          _line('Subtotal habitaciones',
              'Bs ${roomsTotal.toStringAsFixed(0)}'),

          if (isTourist && guidePrice > 0)
            _line(
              'Guía turística  '
              '(Bs ${guidePrice.toStringAsFixed(0)} × $numPeople pers.)',
              'Bs ${guideTotal.toStringAsFixed(0)}',
            ),

          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL ESTIMADO',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                'Bs ${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF1A5276)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13))),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
}