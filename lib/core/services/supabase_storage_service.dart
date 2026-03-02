import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class SupabaseConfig {
  static const String url = 'https://owvsiwnkimhrbxzqfzsl.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93dnNpd25raW1ocmJ4enFmenNsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzAxODksImV4cCI6MjA4NzkwNjE4OX0.SSAG4FsQwewiK2ujrvugxNWhdk1ipYR47qcwm4hVg9Q';

  static const String bucketQr       = 'hotel-qr';
  static const String bucketReceipts = 'payment-receipts';

  /// URL pública con apikey como query param.
  /// Funciona aunque el bucket tenga RLS activo.
  static String publicUrl(String bucket, String storagePath) =>
      '$url/storage/v1/object/public/$bucket/$storagePath?apikey=$anonKey';
}

class SupabaseStorageService {
  String get _base => '${SupabaseConfig.url}/storage/v1/object';

  Map<String, String> get _h => {
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'apikey': SupabaseConfig.anonKey,
      };

  /// Sube el QR del hotel. Siempre .jpg porque image_picker
  /// con imageQuality convierte todo a JPEG internamente.
  Future<String> uploadHotelQr({
    required String hotelId,
    required File file,
  }) async {
    final storagePath = 'hotels/$hotelId/qr.jpg';
    await _upload(
      bucket: SupabaseConfig.bucketQr,
      path: storagePath,
      bytes: await file.readAsBytes(),
      mime: 'image/jpeg',
    );
    return SupabaseConfig.publicUrl(SupabaseConfig.bucketQr, storagePath);
  }

  /// Sube el comprobante de pago del turista.
  Future<String> uploadPaymentReceipt({
    required String reservationId,
    required String userId,
    required File file,
  }) async {
    final ext = _ext(file.path);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'reservations/$reservationId/${userId}_$ts.$ext';
    await _upload(
      bucket: SupabaseConfig.bucketReceipts,
      path: storagePath,
      bytes: await file.readAsBytes(),
      mime: _mime(ext),
    );
    return SupabaseConfig.publicUrl(
        SupabaseConfig.bucketReceipts, storagePath);
  }

  Future<void> _upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mime,
  }) async {
    final res = await http.put(
      Uri.parse('$_base/$bucket/$path'),
      headers: {
        ..._h,
        'Content-Type': mime,
        'x-upsert': 'true',
        'Cache-Control': '3600',
      },
      body: bytes,
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Error Supabase ${res.statusCode}: ${res.body}');
    }
  }

  String _ext(String p) {
    final parts = p.toLowerCase().split('.');
    return parts.length > 1 ? parts.last : 'jpg';
  }

  String _mime(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}