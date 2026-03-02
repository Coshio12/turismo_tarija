import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../auth/providers/auth_provider.dart';

class HotelQrScreen extends StatefulWidget {
  const HotelQrScreen({super.key});
  @override
  State<HotelQrScreen> createState() => _HotelQrScreenState();
}

class _HotelQrScreenState extends State<HotelQrScreen> {
  final _storage   = SupabaseStorageService();
  final _firestore = FirestoreService();
  final _picker    = ImagePicker();

  bool  _uploading = false;
  File? _preview;

  @override
  Widget build(BuildContext context) {
    final user  = context.watch<AuthProvider>().user!;
    final qrUrl = user.qrUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR de pago'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Info ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF2E86C1).withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: Color(0xFF1A5276), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sube tu código QR de pago (Tigo Money, QR bancario, etc.). '
                      'Los turistas lo verán al hacer su reserva para realizar el pago.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Imagen QR ────────────────────────────────────────
            Center(
              child: Column(children: [

                // Preview local o imagen guardada
                if (_preview != null) ...[
                  const Text('Vista previa',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  _imageBox(child: Image.file(_preview!,
                      fit: BoxFit.contain)),
                ] else if (qrUrl != null && qrUrl.isNotEmpty) ...[
                  const Text('QR actual',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  _imageBox(
                    child: Image.network(
                      // cache-bust para mostrar siempre la versión más reciente
                      '$qrUrl?v=${DateTime.now().millisecondsSinceEpoch}',
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, p) => p == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) =>
                          _placeholder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('QR visible para los turistas',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ]),
                ] else
                  _imageBox(child: _placeholder()),

                const SizedBox(height: 20),

                // Botones
                if (_uploading)
                  const CircularProgressIndicator()
                else
                  Column(children: [
                    ElevatedButton.icon(
                      onPressed: _pick,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(qrUrl != null && qrUrl.isNotEmpty
                          ? 'Cambiar QR'
                          : 'Seleccionar imagen'),
                    ),
                    if (_preview != null) ...[
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _upload,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Subir QR'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _preview = null),
                        child: const Text('Cancelar',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ]),
              ]),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 12),

            // ── Consejos ─────────────────────────────────────────
            const Text('Consejos',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _tip(Icons.crop_outlined,
                'Recorta la imagen para que solo muestre el QR, sin bordes.'),
            _tip(Icons.light_mode_outlined,
                'Asegúrate de que la imagen sea nítida y bien iluminada.'),
            _tip(Icons.image_outlined,
                'Formatos aceptados: JPG, PNG. Tamaño recomendado: < 2 MB.'),
          ],
        ),
      ),
    );
  }

  Widget _imageBox({required Widget child}) => Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  Widget _placeholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text('Sin QR cargado',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13)),
        ],
      );

  Widget _tip(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12)),
          ),
        ]),
      );

  Future<void> _pick() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _preview = File(picked.path));
  }

  Future<void> _upload() async {
    if (_preview == null) return;
    setState(() => _uploading = true);

    try {
      final auth = context.read<AuthProvider>();
      final user = auth.user!;

      // 1. Subir imagen a Supabase
      final url = await _storage.uploadHotelQr(
          hotelId: user.uid, file: _preview!);

      // 2. Guardar URL en Firestore (doc del hotel)
      await _firestore.updateHotelProfile(user.uid, {'qrUrl': url});

      // 3. Actualizar provider local para reflejar el cambio en la UI
      auth.updateUserLocally(user.copyWith(qrUrl: url));

      if (mounted) {
        setState(() => _preview = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('QR subido correctamente ✓'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}