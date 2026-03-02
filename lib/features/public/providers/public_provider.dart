import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/package_model.dart';
import '../../../core/models/reservation_model.dart';
import '../../../core/models/room_model.dart';
import '../../../core/services/firestore_service.dart';

class PublicProvider extends ChangeNotifier {
  final _service = FirestoreService();

  StreamSubscription? _packagesSub;
  StreamSubscription? _roomsSub;
  StreamSubscription? _reservationsSub;

  List<PackageModel>     _packages     = [];
  List<RoomModel>        _allRooms     = [];
  List<ReservationModel> _reservations = [];
  bool    _loading = false;
  String? _error;

  List<PackageModel>     get packages     => _packages;
  List<ReservationModel> get reservations => _reservations;
  bool    get loading => _loading;
  String? get error   => _error;

  /// Habitaciones visibles en el catálogo público:
  /// solo las activas cuyo roomId NO está en ningún paquete activo.
  List<RoomModel> get rooms {
    final assignedIds = <String>{};
    for (final pkg in _packages) {
      if (pkg.isActive) {
        for (final r in pkg.rooms) {
          if (r.roomId.isNotEmpty) assignedIds.add(r.roomId);
        }
      }
    }
    return _allRooms
        .where((r) => !assignedIds.contains(r.roomId))
        .toList();
  }

  // ── Streams ──────────────────────────────────────────────────────

  void listenPackages() {
    _packagesSub?.cancel();
    _packagesSub = _service.activePackagesStream().listen((list) {
      _packages = list;
      notifyListeners();
    });
  }

  void listenRooms() {
    _roomsSub?.cancel();
    _roomsSub = _service.allActiveRoomsStream().listen((list) {
      _allRooms = list;
      notifyListeners();
    });
  }

  void listenReservations(String userId) {
    _reservationsSub?.cancel();
    _reservationsSub =
        _service.userReservationsStream(userId).listen((list) {
      _reservations = list;
      notifyListeners();
    });
  }

  // ── Crear reserva ────────────────────────────────────────────────

  Future<bool> createReservation({
    required ReservationType reservationType,
    PackageModel? package,
    RoomModel?    room,
    required String   userId,
    required String   guestName,
    required String   guestPhone,
    required int      numberOfPeople,
    required DateTime checkInDate,
    required DateTime checkOutDate,
  }) async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      if (reservationType == ReservationType.package) {
        if (package == null || package.packageId.isEmpty) {
          throw ArgumentError(
              'El paquete seleccionado no es válido. Vuelve al listado.');
        }
      } else {
        if (room == null || room.roomId.isEmpty) {
          throw ArgumentError(
              'La habitación seleccionada no es válida. Vuelve al listado.');
        }
        if (room.hotelId.isEmpty) {
          throw ArgumentError('La habitación no tiene hotel asociado.');
        }
      }
      if (userId.isEmpty) {
        throw ArgumentError(
            'Usuario no identificado. Cierra sesión y vuelve a entrar.');
      }

      final nights = checkOutDate
          .difference(checkInDate)
          .inDays
          .clamp(1, 9999);

      // ── Precio total correcto ────────────────────────────────────
      // Paquete turístico:
      //   total = Σ(hab.pricePerNight × noches reales) + guidePricePerPerson × personas
      // Habitación directa:
      //   total = pricePerNight × noches reales
      final double total;
      if (reservationType == ReservationType.package) {
        final roomsTotal = package!.rooms.fold<double>(
          0.0, (sum, r) => sum + r.pricePerNight * nights,
        );
        total = roomsTotal + package.guidePricePerPerson * numberOfPeople;
      } else {
        total = room!.pricePerNight * nights;
      }

      final res = ReservationModel(
        reservationId:   '',
        packageId:       package?.packageId   ?? '',
        packageName:     package?.packageName ?? '',
        roomId:          room?.roomId         ?? '',
        roomName:        room?.roomName       ?? '',
        hotelId:         package?.hotelId     ?? room!.hotelId,
        hotelName:       package?.hotelName   ?? room!.hotelName,
        userId:          userId,
        guestName:       guestName,
        guestPhone:      guestPhone,
        numberOfPeople:  numberOfPeople,
        checkInDate:     checkInDate,
        checkOutDate:    checkOutDate,
        tourGuideDate:   null,
        reservationType: reservationType,
        totalPrice:      total,
        status:          ReservationStatus.pending,
        hotelMessage:    '',
        createdAt:       DateTime.now(),
        updatedAt:       DateTime.now(),
      );

      await _service.createReservation(res);
      return true;
    } catch (e) {
      _error = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('ArgumentError: ', '');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Cancelar reserva ─────────────────────────────────────────────

  Future<bool> cancelReservation(String reservationId) async {
    if (reservationId.isEmpty) {
      _error = 'ID de reserva inválido';
      notifyListeners();
      return false;
    }
    try {
      await _service.updateReservationStatus(
        reservationId: reservationId,
        userId:        '',
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
    _roomsSub?.cancel();
    _reservationsSub?.cancel();
    super.dispose();
  }
}