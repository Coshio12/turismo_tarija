import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/models/reservation_model.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Pantalla del TURISTA:
///   • Carga el QR de pago en tiempo real desde el doc del hotel
///   • Permite subir comprobante (imagen o PDF)
class PaymentScreen extends StatefulWidget {
  final ReservationModel reservation;
  const PaymentScreen({super.key, required this.reservation});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _storage   = SupabaseStorageService();
  final _firestore = FirestoreService();
  final _picker    = ImagePicker();

  bool    _uploading = false;
  bool    _loadingQr = true;
  File?   _file;
  String? _fileName;
  String? _liveQrUrl;

  ReservationModel get _res => widget.reservation;

  @override
  void initState() {
    super.initState();
    _loadHotelQr();
  }

  /// Construye la URL del QR directamente desde el hotelId,
  /// sin hacer ninguna lectura a Firestore.
  /// El path es siempre predecible: hotels/{hotelId}/qr.jpg
  /// Luego verifica con un HEAD request si el archivo existe en Supabase.
  Future<void> _loadHotelQr() async {
    try {
      final candidateUrl = SupabaseConfig.publicUrl(
        SupabaseConfig.bucketQr,
        'hotels/${_res.hotelId}/qr.jpg',
      );

      // Verificamos si el archivo existe con un HEAD request ligero
      final res = await http.head(
        Uri.parse(candidateUrl),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
      );

      if (mounted) {
        setState(() {
          // 200 = existe, cualquier otro código = no existe todavía
          _liveQrUrl = (res.statusCode == 200) ? candidateUrl : null;
          _loadingQr = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago de reserva'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: _loadingQr
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            tooltip: 'Recargar QR',
            onPressed: _loadingQr
                ? null
                : () {
                    setState(() => _loadingQr = true);
                    _loadHotelQr();
                  },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Resumen de la reserva ──────────────────────────────
            _SummaryCard(reservation: _res),
            const SizedBox(height: 20),

            // ── QR del hotel ───────────────────────────────────────
            _sectionHeader('Código QR de pago', Icons.qr_code_2_outlined),
            const SizedBox(height: 10),
            _loadingQr
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _QrWidget(qrUrl: _liveQrUrl, total: _res.totalPrice),
            const SizedBox(height: 24),

            // ── Comprobante ────────────────────────────────────────
            _sectionHeader(
                'Comprobante de pago', Icons.receipt_long_outlined),
            const SizedBox(height: 10),

            if (_res.hasReceipt) ...[
              _ReceiptCard(
                url: _res.paymentReceiptUrl!,
                name: _res.paymentReceiptName ?? 'comprobante',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickOptions,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reemplazar comprobante'),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.pending_outlined,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Aún no subiste tu comprobante. Realiza el pago '
                        'al QR de arriba y luego adjunta la captura o PDF aquí.',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Preview del archivo seleccionado ──────────────────
            if (_file != null) ...[
              const SizedBox(height: 14),
              _FilePreview(
                file: _file!,
                fileName: _fileName ?? '',
                onRemove: () =>
                    setState(() { _file = null; _fileName = null; }),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _uploading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _uploadReceipt,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Subir comprobante'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                      ),
              ),
            ] else if (!_res.hasReceipt) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_camera_outlined, size: 16),
                    label: const Text('Foto / Galería'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(
                        Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('PDF'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Row(children: [
        Icon(icon, color: const Color(0xFF1A5276), size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
      ]);

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _file     = File(picked.path);
      _fileName = picked.name;
    });
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;
    setState(() {
      _file     = File(f.path!);
      _fileName = f.name;
    });
  }

  void _pickOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galería / Cámara'),
            onTap: () { Navigator.pop(context); _pickImage(); },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Archivo PDF'),
            onTap: () { Navigator.pop(context); _pickPdf(); },
          ),
        ]),
      ),
    );
  }

  Future<void> _uploadReceipt() async {
    if (_file == null) return;
    setState(() => _uploading = true);

    try {
      final user = context.read<AuthProvider>().user!;
      final url  = await _storage.uploadPaymentReceipt(
        reservationId: _res.reservationId,
        userId:        user.uid,
        file:          _file!,
      );
      await _firestore.updateReservationPayment(
        reservationId:      _res.reservationId,
        paymentReceiptUrl:  url,
        paymentReceiptName: _fileName ?? 'comprobante',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Comprobante subido correctamente ✓'),
          backgroundColor: Colors.green,
        ));
        context.pop();
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

// ══════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════

class _SummaryCard extends StatelessWidget {
  final ReservationModel reservation;
  const _SummaryCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A5276),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.isPackage ? r.packageName : r.roomName,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 2),
        Text(r.hotelName,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total a pagar',
              style: TextStyle(color: Colors.white70)),
          Text(
            'Bs ${r.totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
        ]),
      ]),
    );
  }
}

// ── QR Widget con estado para reintentos y cache-busting ──────────────
class _QrWidget extends StatefulWidget {
  final String? qrUrl;
  final double  total;
  const _QrWidget({required this.qrUrl, required this.total});

  @override
  State<_QrWidget> createState() => _QrWidgetState();
}

class _QrWidgetState extends State<_QrWidget> {
  int _cacheBust = DateTime.now().millisecondsSinceEpoch;

  @override
  Widget build(BuildContext context) {
    final qrUrl = widget.qrUrl;

    if (qrUrl == null || qrUrl.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(children: [
          Icon(Icons.qr_code_2, color: Colors.grey.shade400, size: 40),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'El hotel aún no cargó su QR. '
              'Usa el botón ↻ arriba para reintentar.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ]),
      );
    }

    // Cache-bust: evita que el SO sirva una versión cacheada
    final imageUrl = '$qrUrl&cb=$_cacheBust';

    return Center(
      child: Column(children: [
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            headers: const {
              'apikey': SupabaseConfig.anonKey,
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            },
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text('Cargando QR...',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              );
            },
            errorBuilder: (_, error, __) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_outlined,
                    size: 36, color: Colors.orange),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'No se pudo cargar el QR.\nVerifica tu conexión.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(
                      () => _cacheBust = DateTime.now().millisecondsSinceEpoch),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.qr_code_scanner, size: 14, color: Colors.teal),
          const SizedBox(width: 6),
          Text(
            'Escanea para pagar  •  Bs ${widget.total.toStringAsFixed(0)}',
            style: const TextStyle(
                color: Colors.teal,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ]),
      ]),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final String url;
  final String name;
  const _ReceiptCard({required this.url, required this.name});

  bool get _isPdf => name.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            _isPdf ? Icons.picture_as_pdf : Icons.check_circle_outline,
            color: Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text('Comprobante enviado',
              style: TextStyle(
                  color: Colors.green, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        if (_isPdf)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              headers: const {
                'apikey': SupabaseConfig.anonKey,
                'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
              },
              loadingBuilder: (_, child, p) => p == null
                  ? child
                  : const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator())),
              errorBuilder: (_, __, ___) => Container(
                height: 80,
                color: Colors.grey.shade100,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
      ]),
    );
  }
}

class _FilePreview extends StatelessWidget {
  final File         file;
  final String       fileName;
  final VoidCallback onRemove;
  const _FilePreview({
    required this.file,
    required this.fileName,
    required this.onRemove,
  });

  bool get _isPdf => fileName.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF2E86C1).withOpacity(0.4)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          const Text('Archivo seleccionado',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 18, color: Colors.grey),
          ),
        ]),
        const SizedBox(height: 8),
        if (_isPdf)
          Row(children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(fileName,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ])
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
      ]),
    );
  }
}