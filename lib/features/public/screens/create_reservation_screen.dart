import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/package_model.dart';
import '../../../core/models/reservation_model.dart';
import '../../../core/models/room_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/public_provider.dart';

class CreateReservationScreen extends StatefulWidget {
  final PackageModel? package;
  final RoomModel?    room;

  const CreateReservationScreen({super.key, this.package, this.room})
      : assert(package != null || room != null,
            'Debes pasar package o room');

  @override
  State<CreateReservationScreen> createState() =>
      _CreateReservationScreenState();
}

class _CreateReservationScreenState
    extends State<CreateReservationScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _guestName  = TextEditingController();
  final _guestPhone = TextEditingController();
  final _people     = TextEditingController(text: '1');

  DateTime? _checkIn;
  DateTime? _checkOut;

  // roomId → rangos ocupados (cargados vía Firestore stream)
  final Map<String, List<Map<String, DateTime>>> _occupiedByRoom = {};
  bool _loadingDates = false;

  final _firestoreService = FirestoreService();

  bool get _isPackage => widget.package != null;
  int  get _numPeople => int.tryParse(_people.text) ?? 1;
  int  get _nights {
    if (_checkIn == null || _checkOut == null) return 0;
    return _checkOut!.difference(_checkIn!).inDays.clamp(0, 9999);
  }

  // ── Total correcto ────────────────────────────────────────────────
  // Paquete:  Σ(pricePerNight × noches reales) + guía × personas
  // Directa:  pricePerNight × noches reales
  double get _total {
    if (_isPackage) {
      final pkg = widget.package!;
      // Si ya hay fechas, multiplicar cada habitación por las noches reales.
      // Si aún no hay fechas, usar las noches fijas del paquete como referencia.
      final n = _nights > 0 ? _nights : null;
      final roomsTotal = pkg.rooms.fold<double>(
        0.0,
        (sum, r) => sum + r.pricePerNight * (n ?? r.nights),
      );
      return roomsTotal + pkg.guidePricePerPerson * _numPeople;
    } else {
      return widget.room!.pricePerNight * _nights;
    }
  }

  @override
  void initState() {
    super.initState();
    _people.addListener(() => setState(() {}));
    _loadOccupied();
  }

  @override
  void dispose() {
    _guestName.dispose();
    _guestPhone.dispose();
    _people.dispose();
    super.dispose();
  }

  void _loadOccupied() {
    setState(() => _loadingDates = true);

    if (_isPackage) {
      // Para paquetes cargamos la disponibilidad de CADA habitación asignada
      for (final r in widget.package!.rooms) {
        if (r.roomId.isEmpty) continue;
        _firestoreService.roomOccupiedDatesStream(r.roomId).listen(
          (ranges) {
            if (mounted) setState(() { _occupiedByRoom[r.roomId] = ranges; _loadingDates = false; });
          },
          onError: (_) { if (mounted) setState(() => _loadingDates = false); },
        );
      }
      if (widget.package!.rooms.isEmpty) setState(() => _loadingDates = false);
    } else {
      final roomId = widget.room!.roomId;
      if (roomId.isEmpty) { setState(() => _loadingDates = false); return; }
      _firestoreService.roomOccupiedDatesStream(roomId).listen(
        (ranges) {
          if (mounted) setState(() { _occupiedByRoom[roomId] = ranges; _loadingDates = false; });
        },
        onError: (_) { if (mounted) setState(() => _loadingDates = false); },
      );
    }
  }

  /// Una fecha está ocupada si ALGUNA habitación relevante la tiene ocupada.
  bool _isOccupied(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    for (final ranges in _occupiedByRoom.values) {
      for (final range in ranges) {
        final ci = DateTime(range['checkIn']!.year,
            range['checkIn']!.month, range['checkIn']!.day);
        final co = DateTime(range['checkOut']!.year,
            range['checkOut']!.month, range['checkOut']!.day);
        if (!d.isBefore(ci) && d.isBefore(co)) return true;
      }
    }
    return false;
  }

  Future<DateTime?> _pickDate({DateTime? after}) async {
    final first = after ?? DateTime.now();
    // Buscar el primer día disponible a partir de first+1
    DateTime initial = first.add(const Duration(days: 1));
    while (_isOccupied(initial)) {
      initial = initial.add(const Duration(days: 1));
    }
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate:   first,
      lastDate:    DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (day) => !_isOccupied(day),
    );
  }

  /// Devuelve true si algún día dentro de [checkIn, checkOut) está ocupado.
  bool _rangeHasConflict(DateTime checkIn, DateTime checkOut) {
    DateTime cursor = checkIn;
    while (cursor.isBefore(checkOut)) {
      if (_isOccupied(cursor)) return true;
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_checkIn == null || _checkOut == null) {
      _snack('Selecciona las fechas de check-in y check-out');
      return;
    }
    if (!_checkOut!.isAfter(_checkIn!)) {
      _snack('El check-out debe ser posterior al check-in');
      return;
    }
    if (_rangeHasConflict(_checkIn!, _checkOut!)) {
      _snack(
        'El rango seleccionado incluye fechas ya reservadas. '
        'Por favor elige otras fechas.',
        color: Colors.orange,
      );
      return;
    }
    if (!_isPackage && _numPeople > widget.room!.capacity) {
      _snack(
        'Esta habitación tiene capacidad máxima de '
        '${widget.room!.capacity} persona(s)',
        color: Colors.orange,
      );
      return;
    }
    _showConfirm();
  }

  void _snack(String msg, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _showConfirm() {
    final fmt = DateFormat('dd/MM/yyyy');
    final pkg = widget.package;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.info_outline, color: Color(0xFF1A5276)),
          SizedBox(width: 8),
          Text('Confirmar reserva'),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isPackage ? pkg!.packageName : widget.room!.roomName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Check-in:   ${fmt.format(_checkIn!)}'),
              Text('Check-out:  ${fmt.format(_checkOut!)}'),
              Text('Noches:     $_nights'),
              const SizedBox(height: 10),

              // Desglose de precio
              if (_isPackage) ...[
                ...pkg!.rooms.map((r) {
                  final subtotal = r.pricePerNight * _nights;
                  return _confirmLine(
                    '${r.roomName} ($_nights n. × Bs ${r.pricePerNight.toStringAsFixed(0)})',
                    'Bs ${subtotal.toStringAsFixed(0)}',
                  );
                }),
                if (pkg.guidePricePerPerson > 0)
                  _confirmLine(
                    'Guía  (Bs ${pkg.guidePricePerPerson.toStringAsFixed(0)}'
                    ' × $_numPeople pers.)',
                    'Bs ${(pkg.guidePricePerPerson * _numPeople).toStringAsFixed(0)}',
                  ),
                const Divider(height: 16),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total estimado:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'Bs ${_total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16),
                  ),
                ],
              ),

              if (_isPackage && pkg!.guidePricePerPerson > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.tour_outlined,
                        size: 16, color: Colors.teal.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'El hotel coordinará la fecha de la guía '
                        'al confirmar tu reserva.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Los datos no podrán modificarse una vez enviados.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _send(); },
            child: const Text('Enviar reserva'),
          ),
        ],
      ),
    );
  }

  Widget _confirmLine(String label, String value) => Padding(
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

  Future<void> _send() async {
    final user = context.read<AuthProvider>().user!;
    final prov = context.read<PublicProvider>();
    final ok   = await prov.createReservation(
      reservationType: _isPackage
          ? ReservationType.package
          : ReservationType.room,
      package:        widget.package,
      room:           widget.room,
      userId:         user.uid,
      guestName:      _guestName.text.trim(),
      guestPhone:     _guestPhone.text.trim(),
      numberOfPeople: _numPeople,
      checkInDate:    _checkIn!,
      checkOutDate:   _checkOut!,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Reserva enviada! El hotel la revisará pronto.'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/home/my-reservations');
    } else {
      _snack(prov.error ?? 'Error al enviar la reserva');
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fmt     = DateFormat('dd/MM/yyyy');
    final loading = context.watch<PublicProvider>().loading;
    final pkg     = widget.package;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isPackage ? 'Reservar paquete' : 'Reservar habitación'),
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

              // ── Header ──────────────────────────────────────────
              _isPackage
                  ? _PackageHeader(package: pkg!)
                  : _RoomHeader(room: widget.room!),
              const SizedBox(height: 16),

              // ── Desglose de precio (paquete) ─────────────────────
              if (_isPackage) ...[
                _PackagePriceBreakdown(
                    package: pkg!, numPeople: _numPeople, nights: _nights),
                const SizedBox(height: 16),
              ],

              // ── Aviso guía ───────────────────────────────────────
              if (_isPackage && pkg!.guidePricePerPerson > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.tour_outlined,
                        color: Colors.teal.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Este paquete incluye guía turística. '
                        'El hotel coordinará contigo la fecha de '
                        'la excursión al confirmar tu reserva.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.teal.shade800),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── Datos del huésped ────────────────────────────────
              const Text('Datos del huésped',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guestName,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guestPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono de contacto',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _people,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad de personas',
                  prefixIcon: const Icon(Icons.group_outlined),
                  helperText: _isPackage && pkg!.guidePricePerPerson > 0
                      ? 'Afecta el costo de la guía turística'
                      : (!_isPackage
                          ? 'Máximo ${widget.room!.capacity} persona(s)'
                          : null),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'Número inválido';
                  if (!_isPackage && n > widget.room!.capacity) {
                    return 'Máximo ${widget.room!.capacity} pers.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Fechas ───────────────────────────────────────────
              const Text('Fechas de estadía',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _DateTile(
                    label: 'Check-in',
                    date: _checkIn,
                    fmt: fmt,
                    onTap: () async {
                      final d = await _pickDate();
                      if (d != null) {
                        setState(() {
                          _checkIn  = d;
                          if (_checkOut != null &&
                              !_checkOut!.isAfter(d)) {
                            _checkOut = null;
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateTile(
                    label: 'Check-out',
                    date: _checkOut,
                    fmt: fmt,
                    onTap: () async {
                      final d = await _pickDate(
                          after: _checkIn ?? DateTime.now());
                      if (d != null) setState(() => _checkOut = d);
                    },
                  ),
                ),
              ]),
              if (_nights > 0) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text('$_nights noche(s)',
                      style: const TextStyle(
                          color: Color(0xFF2E86C1),
                          fontWeight: FontWeight.w600)),
                ),
              ],

              // ── Calendario de disponibilidad ─────────────────────
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.calendar_month_outlined,
                    color: Color(0xFF1A5276), size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _isPackage
                        ? 'Disponibilidad de las habitaciones del paquete'
                        : 'Disponibilidad de la habitación',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              if (_loadingDates)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _AvailabilityCalendar(isOccupied: _isOccupied),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Las fechas mostradas arriba tienen reservas pendientes o confirmadas. El hotel revisará tu solicitud.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Total ────────────────────────────────────────────
              if (_isPackage || _nights > 0)
                _TotalBox(
                  isPackage: _isPackage,
                  package:   pkg,
                  room:      widget.room,
                  nights:    _nights,
                  numPeople: _numPeople,
                  total:     _total,
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        color: Colors.grey.shade500, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Selecciona las fechas para ver el total',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ]),
                ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.send),
                        label: const Text('Enviar reserva'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// DESGLOSE DE PRECIO DEL PAQUETE (reactivo al cambio de personas)
// ══════════════════════════════════════════════════════════════════════

class _PackagePriceBreakdown extends StatelessWidget {
  final PackageModel package;
  final int          numPeople;
  /// Noches reales elegidas por el usuario. 0 = aún no eligió fechas.
  final int          nights;

  const _PackagePriceBreakdown({
    required this.package,
    required this.numPeople,
    required this.nights,
  });

  @override
  Widget build(BuildContext context) {
    // Si el usuario ya eligió fechas, usar esas noches; si no, las del paquete.
    final n          = nights > 0 ? nights : null;
    final roomsTotal = package.rooms.fold<double>(
      0.0, (sum, r) => sum + r.pricePerNight * (n ?? r.nights),
    );
    final guideTotal = package.guidePricePerPerson * numPeople;
    final total      = roomsTotal + guideTotal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF2E86C1).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.receipt_long_outlined,
                color: Color(0xFF1A5276), size: 18),
            const SizedBox(width: 8),
            const Text('Desglose del precio',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A5276))),
            if (nights > 0) ...[
              const Spacer(),
              Text(
                '$nights noche(s)',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2E86C1),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ]),
          const SizedBox(height: 10),

          // Una línea por habitación usando noches reales
          ...package.rooms.map((r) {
            final effectiveNights = n ?? r.nights;
            final subtotal = r.pricePerNight * effectiveNights;
            return _line(
              '${r.roomName}  ($effectiveNights noche(s) × '
              'Bs ${r.pricePerNight.toStringAsFixed(0)})',
              'Bs ${subtotal.toStringAsFixed(0)}',
            );
          }),

          const Divider(height: 14),
          _line('Subtotal habitaciones',
              'Bs ${roomsTotal.toStringAsFixed(0)}'),

          if (package.guidePricePerPerson > 0)
            _line(
              'Guía turística  '
              '(Bs ${package.guidePricePerPerson.toStringAsFixed(0)}'
              ' × $numPeople pers.)',
              'Bs ${guideTotal.toStringAsFixed(0)}',
            ),

          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL',
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
          if (package.guidePricePerPerson > 0 || nights > 0) ...[
            const SizedBox(height: 4),
            Text(
              nights > 0
                  ? 'Calculado para $nights noche(s) y $numPeople persona(s).'
                  : 'Selecciona las fechas para ver el cálculo final.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
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

// ══════════════════════════════════════════════════════════════════════
// CALENDARIO DE DISPONIBILIDAD (tamaño fijo, sin AspectRatio)
// ══════════════════════════════════════════════════════════════════════

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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
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
                          color: Colors.green,
                          fontWeight: FontWeight.w500),
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
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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

  Widget _dot(Color bg, Color border, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );
}

// ══════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════

class _TotalBox extends StatelessWidget {
  final bool          isPackage;
  final PackageModel? package;
  final RoomModel?    room;
  final int           nights;
  final int           numPeople;
  final double        total;

  const _TotalBox({
    required this.isPackage,
    required this.package,
    required this.room,
    required this.nights,
    required this.numPeople,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    String subtitle;
    if (isPackage) {
      final pkg = package!;
      if (pkg.guidePricePerPerson > 0) {
        subtitle =
            'Hab. Bs ${pkg.roomsTotalPrice.toStringAsFixed(0)} + '
            'Guía Bs ${(pkg.guidePricePerPerson * numPeople).toStringAsFixed(0)}';
      } else {
        subtitle = 'Solo habitaciones incluidas';
      }
    } else {
      subtitle = nights == 1
          ? 'Bs ${room!.pricePerNight.toStringAsFixed(0)} × 1 noche'
          : 'Bs ${room!.pricePerNight.toStringAsFixed(0)} × $nights noches';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total estimado',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          Text(
            'Bs ${total.toStringAsFixed(0)}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.green),
          ),
        ],
      ),
    );
  }
}

class _PackageHeader extends StatelessWidget {
  final PackageModel package;
  const _PackageHeader({required this.package});

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF1A5276),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.tour_outlined, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(package.packageName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  Text(package.hotelName,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    package.guidePricePerPerson > 0
                        ? 'Hospedaje + guía turística'
                        : 'Solo hospedaje',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _RoomHeader extends StatelessWidget {
  final RoomModel room;
  const _RoomHeader({required this.room});

  IconData _icon(RoomType t) {
    switch (t) {
      case RoomType.single:      return Icons.single_bed_outlined;
      case RoomType.double_:     return Icons.bed_outlined;
      case RoomType.matrimonial: return Icons.king_bed_outlined;
      case RoomType.suite:       return Icons.hotel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF2E86C1),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(_icon(room.roomType), color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.roomName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  Text(
                    '${room.hotelName}  ·  ${room.roomType.shortLabel}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    'Bs ${room.pricePerNight.toStringAsFixed(0)}/noche  '
                    '·  Máx. ${room.capacity} pers.',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _DateTile extends StatelessWidget {
  final String       label;
  final DateTime?    date;
  final DateFormat   fmt;
  final VoidCallback onTap;
  const _DateTile({
    required this.label,
    required this.date,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = date != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF2FF) : Colors.white,
          border: Border.all(
            color: selected
                ? const Color(0xFF2E86C1)
                : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today,
              size: 18,
              color: selected ? const Color(0xFF1A5276) : Colors.grey),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(
              selected ? fmt.format(date!) : 'Seleccionar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? const Color(0xFF1A5276) : Colors.grey,
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}