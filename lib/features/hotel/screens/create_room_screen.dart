import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/hotel_provider.dart';

class CreateRoomScreen extends StatefulWidget {
  final RoomModel? roomToEdit;
  const CreateRoomScreen({super.key, this.roomToEdit});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _roomName    = TextEditingController();
  final _description = TextEditingController();
  final _price       = TextEditingController();
  final _capacity    = TextEditingController(text: '2');

  RoomType _roomType = RoomType.matrimonial;

  bool get _isEdit => widget.roomToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final r = widget.roomToEdit!;
      _roomName.text    = r.roomName;
      _description.text = r.description;
      _price.text       = r.pricePerNight.toStringAsFixed(0);
      _capacity.text    = r.capacity.toString();
      _roomType         = r.roomType;
    }
  }

  @override
  void dispose() {
    _roomName.dispose();
    _description.dispose();
    _price.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().user!;
    final prov = context.read<HotelProvider>();

    if (_isEdit) {
      final ok = await prov.updateRoom(widget.roomToEdit!.roomId, {
        'roomName':      _roomName.text.trim(),
        'roomType':      _roomType.value,
        'capacity':      int.parse(_capacity.text),
        'pricePerNight': double.parse(_price.text),
        'description':   _description.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Habitación actualizada' : prov.error ?? 'Error'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
        if (ok) context.pop();
      }
    } else {
      final room = RoomModel(
        roomId:        '',
        hotelId:       user.uid,
        hotelName:     user.hotelName ?? user.displayName,
        roomName:      _roomName.text.trim(),
        roomType:      _roomType,
        capacity:      int.parse(_capacity.text),
        pricePerNight: double.parse(_price.text),
        description:   _description.text.trim(),
        isActive:      true,
        createdAt:     DateTime.now(),
        updatedAt:     DateTime.now(),
      );
      final ok = await prov.createRoom(room);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '¡Habitación registrada!' : prov.error ?? 'Error'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
        if (ok) context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<HotelProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar habitación' : 'Nueva habitación'),
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

              // ── Tipo de habitación ────────────────────────────────
              const Text(
                'Tipo de habitación',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: RoomType.values.map((type) {
                  final selected = _roomType == type;
                  return ChoiceChip(
                    label: Text(type.shortLabel),
                    selected: selected,
                    selectedColor: const Color(0xFF1A5276),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _roomType = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                _roomType.label,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // ── Nombre ────────────────────────────────────────────
              TextFormField(
                controller: _roomName,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la habitación',
                  hintText: 'Ej: Habitación 101 - Matrimonial',
                  prefixIcon: Icon(Icons.bed_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              // ── Descripción ───────────────────────────────────────
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Descripción (amenidades, vista, etc.)',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              // ── Capacidad y Precio (fila) ─────────────────────────
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _capacity,
                    decoration: const InputDecoration(
                      labelText: 'Capacidad (personas)',
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n != null && n > 0) ? null : 'Inválido';
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(
                      labelText: 'Precio por noche (Bs)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return (n != null && n > 0) ? null : 'Inválido';
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: prov.loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _save,
                        icon: Icon(_isEdit ? Icons.save : Icons.add),
                        label: Text(_isEdit ? 'Guardar cambios' : 'Registrar habitación'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}