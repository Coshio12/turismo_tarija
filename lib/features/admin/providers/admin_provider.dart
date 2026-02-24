import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/package_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';

class AdminProvider extends ChangeNotifier {
  final _service = FirestoreService();

  StreamSubscription? _hotelsSub;

  List<UserModel> _hotels  = [];
  bool    _loading = false;
  String? _error;

  List<UserModel> get hotels  => _hotels;
  bool    get loading => _loading;
  String? get error   => _error;

  void listenHotels() {
    _hotelsSub?.cancel();
    _hotelsSub = _service.hotelsStream().listen((list) {
      // Ordenar por totalReservations descendente
      list.sort((a, b) => b.totalReservations.compareTo(a.totalReservations));
      _hotels = list;
      notifyListeners();
    });
  }

  // Actualización optimista: cambia el estado local al instante,
  // Firestore confirma después via stream.
  Future<bool> toggleHotel(String hotelId, bool active) async {
    _hotels = _hotels.map((h) {
      if (h.uid != hotelId) return h;
      return h.copyWith(isActive: active);
    }).toList();
    notifyListeners();
    return _run(() => _service.toggleHotelActive(hotelId, active));
  }

  Future<bool> deleteHotel(String hotelId) async {
    _hotels = _hotels.where((h) => h.uid != hotelId).toList();
    notifyListeners();
    return _run(() => _service.deleteHotel(hotelId));
  }

  Future<bool> sendMessage({
    required String hotelId,
    required String adminId,
    required String subject,
    required String body,
  }) =>
      _run(() => _service.sendMessageToHotel(
            hotelId: hotelId,
            adminId: adminId,
            subject: subject,
            body:    body,
          ));

  Future<List<PackageModel>> getHotelPackages(String hotelId) =>
      _service.hotelPackagesFuture(hotelId);

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

  @override
  void dispose() {
    _hotelsSub?.cancel();
    super.dispose();
  }
}