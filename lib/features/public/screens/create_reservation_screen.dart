import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/package_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/public_provider.dart';

class CreateReservationScreen extends StatefulWidget {
  final PackageModel package;
  const CreateReservationScreen({super.key, required this.package});
  @override
  State<CreateReservationScreen> createState() =>
      _CreateReservationScreenState();
}

class _CreateReservationScreenState extends State<CreateReservationScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _guestName  = TextEditingController();
  final _guestPhone = TextEditingController();
  final _people     = TextEditingController(text: '1');

  bool      _includesLodging   = false;
  bool      _includesTourGuide = false;
  DateTime? _checkIn;
  DateTime? _checkOut;
  DateTime? _tourDate;

  @override
  void dispose() {
    _guestName.dispose();
    _guestPhone.dispose();
    _people.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(BuildContext context) async {
    return showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_includesLodging && (_checkIn == null || _checkOut == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fechas de hospedaje')));
      return;
    }
    if (_includesTourGuide && _tourDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha para guía turística')));
      return;
    }
    _showConfirmDialog();
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.info_outline, color: Color(0xFF1A5276)),
          SizedBox(width: 8),
          Text('Confirmar reserva'),
        ]),
        content: const Text(
          'Los datos en la reserva no podrán ser cambiados una vez enviados.\n\n'
          '¿Deseas continuar?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendReservation();
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReservation() async {
    final user = context.read<AuthProvider>().user!;
    final prov = context.read<PublicProvider>();
    final ok   = await prov.createReservation(
      package:           widget.package,
      userId:            user.uid,
      guestName:         _guestName.text.trim(),
      guestPhone:        _guestPhone.text.trim(),
      numberOfPeople:    int.parse(_people.text),
      checkInDate:       _checkIn,
      checkOutDate:      _checkOut,
      tourGuideDate:     _tourDate,
      includesLodging:   _includesLodging,
      includesTourGuide: _includesTourGuide,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Reserva enviada! El hotel la revisará pronto.'),
          backgroundColor: Colors.green,
        ),
      );
      // go() para limpiar el stack y evitar volver al formulario con Back
      context.go('/home/my-reservations');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.error ?? 'Error al enviar la reserva'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt    = DateFormat('dd/MM/yyyy');
    final people = int.tryParse(_people.text) ?? 1;
    final total  = widget.package.pricePerPerson * people;
    final loading = context.watch<PublicProvider>().loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear reserva'),
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
              // Resumen del paquete
              Card(
                color: const Color(0xFF1A5276),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const Icon(Icons.luggage, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.package.packageName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.package.hotelName,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Datos del huésped',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guestName,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo del huésped',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guestPhone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono del huésped',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _people,
                decoration: const InputDecoration(
                  labelText: 'Cantidad de personas',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n != null && n > 0) ? null : 'Número inválido';
                },
              ),
              const SizedBox(height: 20),

              const Text(
                'Servicios',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),

              // Hospedaje
              SwitchListTile(
                title: const Text('Incluir hospedaje'),
                value: _includesLodging,
                onChanged: (v) => setState(() {
                  _includesLodging = v;
                  if (!v) {
                    _checkIn  = null;
                    _checkOut = null;
                  }
                }),
              ),
              if (_includesLodging) ...[
                Row(children: [
                  Expanded(
                    child: _dateTile('Check-in', _checkIn, fmt, () async {
                      final d = await _pickDate(context);
                      if (d != null) setState(() => _checkIn = d);
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dateTile('Check-out', _checkOut, fmt, () async {
                      final d = await _pickDate(context);
                      if (d != null) setState(() => _checkOut = d);
                    }),
                  ),
                ]),
                const SizedBox(height: 8),
              ],

              // Guía turística
              SwitchListTile(
                title: const Text('Incluir guía turística'),
                value: _includesTourGuide,
                onChanged: (v) => setState(() {
                  _includesTourGuide = v;
                  if (!v) _tourDate = null;
                }),
              ),
              if (_includesTourGuide) ...[
                _dateTile('Fecha de guía', _tourDate, fmt, () async {
                  final d = await _pickDate(context);
                  if (d != null) setState(() => _tourDate = d);
                }),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 16),
              // Total
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total estimado:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Bs ${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.send),
                        label: const Text('Continuar'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTile(
    String label,
    DateTime? date,
    DateFormat fmt,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 18, color: Color(0xFF1A5276)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(
                date != null ? fmt.format(date) : 'Seleccionar',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}