import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/hotel_provider.dart';

class HotelProfileScreen extends StatefulWidget {
  const HotelProfileScreen({super.key});
  @override
  State<HotelProfileScreen> createState() => _HotelProfileScreenState();
}

class _HotelProfileScreenState extends State<HotelProfileScreen> {
  final _formKey   = GlobalKey<FormState>();
  bool  _loading   = false;
  bool  _hasChanges = false;

  // Controladores — se inicializan con los datos actuales del usuario
  late final TextEditingController _hotelName;
  late final TextEditingController _displayName;
  late final TextEditingController _phone;
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _hotelName   = TextEditingController(text: user.hotelName   ?? '');
    _displayName = TextEditingController(text: user.displayName);
    _phone       = TextEditingController(text: user.phone       ?? '');
    _address     = TextEditingController(text: user.address     ?? '');

    // Detectar cambios para habilitar el botón Guardar
    for (final c in [_hotelName, _displayName, _phone, _address]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() {
    final user = context.read<AuthProvider>().user!;
    final changed =
        _hotelName.text.trim()   != (user.hotelName   ?? '') ||
        _displayName.text.trim() != user.displayName           ||
        _phone.text.trim()       != (user.phone        ?? '') ||
        _address.text.trim()     != (user.address      ?? '');
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  @override
  void dispose() {
    for (final c in [_hotelName, _displayName, _phone, _address]) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    super.dispose();
  }

  // ── Guardar ───────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasChanges) return;

    setState(() => _loading = true);

    final authProv  = context.read<AuthProvider>();
    final hotelProv = context.read<HotelProvider>();
    final user      = authProv.user!;

    final hotelNameVal   = _hotelName.text.trim();
    final displayNameVal = _displayName.text.trim();
    final phoneVal       = _phone.text.trim();
    final addressVal     = _address.text.trim();

    final data = <String, dynamic>{
      'hotelName':   hotelNameVal.isEmpty   ? null : hotelNameVal,
      'displayName': displayNameVal,
      'phone':       phoneVal.isEmpty       ? null : phoneVal,
      'address':     addressVal.isEmpty     ? null : addressVal,
    };

    final ok = await hotelProv.updateHotelProfile(user.uid, data);

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      // Actualizar el modelo local en AuthProvider → AppBar se actualiza al instante
      final updated = user.copyWith(
        hotelName:   hotelNameVal.isEmpty   ? null : hotelNameVal,
        displayName: displayNameVal,
        phone:       phoneVal.isEmpty       ? null : phoneVal,
        address:     addressVal.isEmpty     ? null : addressVal,
      );
      authProv.updateUserLocally(updated);

      setState(() => _hasChanges = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Perfil actualizado correctamente'),
          ]),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hotelProv.error ?? 'Error al guardar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Perfil del hotel'.toUpperCase(),
          style: GoogleFonts.bungee(
            fontWeight: FontWeight.bold,
              // color: Colors.white, // Descomenta si tu AppBar es oscura
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Botón Guardar — activo solo cuando hay cambios
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _hasChanges
                ? TextButton.icon(
                    key: const ValueKey('save'),
                    onPressed: _loading ? null : _save,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined,
                            color: Colors.white, size: 18),
                    label: const Text('Guardar',
                        style: TextStyle(color: Colors.white)),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar con iniciales ──────────────────────────────
              Center(
                child: Column(children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFF1A5276),
                    child: Text(
                      _initials(user.hotelName ?? user.displayName),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: user.isActive
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: user.isActive
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Text(
                      user.isActive ? 'Cuenta activa' : 'Cuenta suspendida',
                      style: TextStyle(
                          fontSize: 12,
                          color: user.isActive
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 28),

              // ── Sección Información del hotel ─────────────────────
              _sectionHeader(
                  Icons.hotel_outlined, 'Información del hotel'),
              const SizedBox(height: 12),

              _field(
                controller: _hotelName,
                label: 'Nombre del hotel',
                hint: 'Ej. Hotel Las Palmas',
                icon: Icons.storefront_outlined,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ingresa el nombre del hotel'
                    : null,
              ),
              const SizedBox(height: 14),

              _field(
                controller: _address,
                label: 'Dirección',
                hint: 'Ej. Av. Principal #123, Zona Sur',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 14),

              _field(
                controller: _phone,
                label: 'Teléfono de contacto',
                hint: 'Ej. +591 77712345',
                icon: Icons.phone_outlined,
                keyboard: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (v.trim().length < 7) return 'Ingresa un teléfono válido';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Sección Cuenta ────────────────────────────────────
              _sectionHeader(
                  Icons.manage_accounts_outlined, 'Cuenta'),
              const SizedBox(height: 12),

              _field(
                controller: _displayName,
                label: 'Nombre de contacto',
                hint: 'Tu nombre completo',
                icon: Icons.person_outline,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ingresa tu nombre'
                    : null,
              ),
              const SizedBox(height: 14),

              // Email — solo lectura (viene de Google)
              _readOnlyField(
                label: 'Correo electrónico',
                value: user.email,
                icon: Icons.email_outlined,
                note: 'El correo no se puede cambiar',
              ),

              const SizedBox(height: 28),

              // ── QR de pago ────────────────────────────────────────
              _sectionHeader(Icons.qr_code_2_outlined, 'QR de pago'),
              const SizedBox(height: 12),

              _QrPaymentTile(
                qrUrl: user.qrUrl,
                onTap: () async {
                  await context.push('/hotel/qr');
                  // Refrescar para mostrar el QR actualizado
                  if (context.mounted) setState(() {});
                },
              ),

              const SizedBox(height: 28),

              // ── Estadísticas ──────────────────────────────────────
              _sectionHeader(Icons.bar_chart_outlined, 'Estadísticas'),
              const SizedBox(height: 12),

              _StatRow(
                icon: Icons.bookmark_border,
                label: 'Reservas totales',
                value: '${user.totalReservations}',
              ),
              if (user.location != null) ...[
                const SizedBox(height: 8),
                _StatRow(
                  icon: Icons.my_location_outlined,
                  label: 'Coordenadas',
                  value:
                      'Lat ${user.location!.latitude.toStringAsFixed(5)}, '
                      'Lng ${user.location!.longitude.toStringAsFixed(5)}',
                ),
              ],

              const SizedBox(height: 32),

              // ── Botón principal ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_loading || !_hasChanges) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5276),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _loading
                        ? 'Guardando...'
                        : _hasChanges
                            ? 'Guardar cambios'
                            : 'Sin cambios',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'H';
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(children: [
      Icon(icon, size: 18, color: const Color(0xFF1A5276)),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1A5276))),
      const SizedBox(width: 8),
      const Expanded(child: Divider()),
    ]);
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF1A5276), size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A5276), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _readOnlyField({
    required String label,
    required String value,
    required IconData icon,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontSize: 15)),
              if (note != null) ...[
                const SizedBox(height: 2),
                Text(note,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
        const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
      ]),
    );
  }
}

// ── Widget QR de pago ─────────────────────────────────────────────────
class _QrPaymentTile extends StatelessWidget {
  final String?      qrUrl;
  final VoidCallback onTap;
  const _QrPaymentTile({required this.qrUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasQr = qrUrl != null && qrUrl!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasQr ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasQr ? Colors.green.shade300 : Colors.grey.shade300),
        ),
        child: Row(children: [
          // Miniatura QR o placeholder
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasQr
                ? Image.network(
                    '$qrUrl?v=${DateTime.now().millisecondsSinceEpoch}',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.qr_code_2,
                        size: 32, color: Colors.grey.shade400),
                  )
                : Icon(Icons.qr_code_2,
                    size: 32, color: Colors.grey.shade400),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                hasQr ? 'QR cargado ✓' : 'Sin QR de pago',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasQr
                      ? Colors.green.shade700
                      : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hasQr
                    ? 'Los turistas ven tu QR al hacer una reserva. Toca para cambiarlo.'
                    : 'Sube tu QR para que los turistas puedan pagarte.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(
            hasQr ? Icons.edit_outlined : Icons.add_circle_outline,
            color: hasQr ? Colors.green : Colors.grey,
          ),
        ]),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _StatRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );
}