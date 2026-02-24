import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/package_model.dart';
import '../../../core/models/reservation_model.dart';
import '../../../core/services/firestore_service.dart';

class PublicProvider extends ChangeNotifier {
  final _service = FirestoreService();

  // FIX: guardar suscripciones para cancelarlas
  StreamSubscription? _packagesSub;
  StreamSubscription? _reservationsSub;

  List<PackageModel>     _packages     = [];
  List<ReservationModel> _reservations = [];
  bool    _loading = false;
  String? _error;

  List<PackageModel>     get packages     => _packages;
  List<ReservationModel> get reservations => _reservations;
  bool    get loading => _loading;
  String? get error   => _error;

  void listenPackages() {
    _packagesSub?.cancel();
    _packagesSub = _service.activePackagesStream().listen((list) {
      _packages = list;
      notifyListeners();
    });
  }

  void listenReservations(String userId) {
    _reservationsSub?.cancel();
    _reservationsSub = _service.userReservationsStream(userId).listen((list) {
      _reservations = list;
      notifyListeners();
    });
  }

  Future<bool> createReservation({
    required PackageModel package,
    required String userId,
    required String guestName,
    required String guestPhone,
    required int numberOfPeople,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    DateTime? tourGuideDate,
    required bool includesLodging,
    required bool includesTourGuide,
  }) async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      // FIX: validar que el packageId no sea vacío antes de continuar
      if (package.packageId.isEmpty) {
        throw ArgumentError(
            'El paquete seleccionado no tiene un ID válido. '
            'Vuelve al listado y selecciónalo de nuevo.');
      }

      final res = ReservationModel(
        reservationId:     '',
        packageId:         package.packageId,
        packageName:       package.packageName,
        hotelId:           package.hotelId,
        hotelName:         package.hotelName,
        userId:            userId,
        guestName:         guestName,
        guestPhone:        guestPhone,
        numberOfPeople:    numberOfPeople,
        checkInDate:       checkInDate,
        checkOutDate:      checkOutDate,
        tourGuideDate:     tourGuideDate,
        includesLodging:   includesLodging,
        includesTourGuide: includesTourGuide,
        totalPrice:        package.pricePerPerson * numberOfPeople,
        status:            ReservationStatus.pending,
        hotelMessage:      '',
        createdAt:         DateTime.now(),
        updatedAt:         DateTime.now(),
      );
      await _service.createReservation(res);
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

  // FIX: usa FirestoreService en lugar de acceder directamente a Firestore
  // con strings hardcodeados
  Future<bool> cancelReservation(String reservationId) async {
    if (reservationId.isEmpty) {
      _error = 'ID de reserva inválido';
      notifyListeners();
      return false;
    }
    try {
      await _service.updateReservationStatus(
        reservationId: reservationId,
        userId:        '',   // No se necesita para cancelar desde el usuario
        status:        ReservationStatus.cancelled,
        hotelMessage:  'Cancelada por el cliente.',
        hotelName:     '',
        packageName:   '',
      );
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('ArgumentError: ', '');
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _packagesSub?.cancel();
    _reservationsSub?.cancel();
    super.dispose();
  }
}