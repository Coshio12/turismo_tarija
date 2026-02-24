import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/message_model.dart';
import '../../../core/models/package_model.dart';
import '../../../core/models/reservation_model.dart';
import '../../../core/services/firestore_service.dart';

class HotelProvider extends ChangeNotifier {
  final _service = FirestoreService();

  final List<StreamSubscription> _subs = [];

  List<PackageModel>     _packages        = [];
  List<ReservationModel> _pending         = [];
  List<ReservationModel> _allReservations = [];
  List<MessageModel>     _inbox           = [];
  bool    _loading = false;
  String? _error;

  List<PackageModel>     get packages            => _packages;
  List<ReservationModel> get pendingReservations => _pending;
  List<ReservationModel> get allReservations     => _allReservations;
  List<MessageModel>     get inbox               => _inbox;
  bool    get loading => _loading;
  String? get error   => _error;

  /// Mensajes no leídos — usado para el badge del buzón
  int get unreadCount => _inbox.where((m) => !m.isRead).length;

  // ── Streams ───────────────────────────────────────────────────────
  void listenAll(String hotelId) {
    _cancelSubscriptions();
    _subs.addAll([
      _service.hotelPackagesStream(hotelId).listen((l) {
        _packages = l;
        notifyListeners();
      }),
      _service.hotelPendingReservationsStream(hotelId).listen((l) {
        _pending = l;
        notifyListeners();
      }),
      _service.hotelAllReservationsStream(hotelId).listen((l) {
        _allReservations = l;
        notifyListeners();
      }),
      _service.inboxStream(hotelId).listen((l) {
        _inbox = l;
        notifyListeners(); // dispara rebuild del badge automáticamente
      }),
    ]);
  }

  void refreshPackages(String hotelId) {
    if (_subs.isNotEmpty) {
      _subs[0].cancel();
      _subs[0] = _service.hotelPackagesStream(hotelId).listen((l) {
        _packages = l;
        notifyListeners();
      });
    } else {
      listenAll(hotelId);
    }
  }

  // ── Paquetes con actualización optimista ──────────────────────────
  Future<bool> createPackage(PackageModel pkg) =>
      _run(() => _service.createPackage(pkg));

  Future<bool> updatePackage(String id, Map<String, dynamic> data) async {
    _packages = _packages.map((p) {
      if (p.packageId != id) return p;
      return p.copyWith(
        packageName:    data['packageName']    as String?,
        description:    data['description']    as String?,
        pricePerPerson: data['pricePerPerson'] as double?,
        hotelAddress:   data['hotelAddress']   as String?,
        hotelLocation:  data['hotelLocation'],
      );
    }).toList();
    notifyListeners();
    return _run(() => _service.updatePackage(id, data));
  }

  Future<bool> deletePackage(String id) async {
    _packages = _packages.where((p) => p.packageId != id).toList();
    notifyListeners();
    return _run(() => _service.deletePackage(id));
  }

  Future<bool> togglePackage(String id, bool active) async {
    _packages = _packages.map((p) {
      if (p.packageId != id) return p;
      return p.copyWith(isActive: active);
    }).toList();
    notifyListeners();
    return _run(() => _service.togglePackageActive(id, active));
  }


  // ── Perfil del hotel ──────────────────────────────────────────────
  Future<bool> updateHotelProfile(String hotelId, Map<String, dynamic> data) =>
      _run(() => _service.updateHotelProfile(hotelId, data));

  // ── Reservas ──────────────────────────────────────────────────────
  Future<bool> updateReservationStatus({
    required String reservationId,
    required String userId,
    required ReservationStatus status,
    required String hotelMessage,
    required String hotelName,
    required String packageName,
  }) =>
      _run(() => _service.updateReservationStatus(
            reservationId: reservationId,
            userId:        userId,
            status:        status,
            hotelMessage:  hotelMessage,
            hotelName:     hotelName,
            packageName:   packageName,
          ));

  // ── Inbox ─────────────────────────────────────────────────────────
  Future<void> markRead(String hotelId, String messageId) async {
    // Actualización optimista: marcar como leído localmente al instante
    _inbox = _inbox.map((m) {
      if (m.messageId != messageId) return m;
      return MessageModel(
        messageId:   m.messageId,
        fromAdminId: m.fromAdminId,
        subject:     m.subject,
        body:        m.body,
        isRead:      true,
        createdAt:   m.createdAt,
      );
    }).toList();
    notifyListeners(); // badge se actualiza al instante
    await _service.markMessageRead(hotelId, messageId);
  }

  // ── Helper ────────────────────────────────────────────────────────
  Future<bool> _run(Future<void> Function() fn) async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      await fn();
      return true;
    } catch (e) {
      _error = e.toString()
          .replaceAll('Exception: ', '')
          .replaceAll('ArgumentError: ', '');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _cancelSubscriptions() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}