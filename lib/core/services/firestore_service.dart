import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/message_model.dart';
import '../models/package_model.dart';
import '../models/reservation_model.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

class FirestoreService {
  final _db    = FirebaseFirestore.instance;
  final _notif = NotificationService();

  // ════════════════════════════════════════════════════════════════
  // PACKAGES
  // ════════════════════════════════════════════════════════════════

  Future<void> createPackage(PackageModel pkg) async {
    final ref = _db.collection(AppConstants.colPackages).doc();
    await ref.set({...pkg.toMap(), 'packageId': ref.id});
  }

  Future<void> updatePackage(String packageId, Map<String, dynamic> data) async {
    if (packageId.isEmpty) throw ArgumentError('packageId vacío');
    await _db.collection(AppConstants.colPackages).doc(packageId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deletePackage(String packageId) async {
    if (packageId.isEmpty) throw ArgumentError('packageId vacío');
    await _db.collection(AppConstants.colPackages).doc(packageId).delete();
  }

  Future<void> togglePackageActive(String packageId, bool isActive) async {
    if (packageId.isEmpty) throw ArgumentError('packageId vacío');
    await _db.collection(AppConstants.colPackages).doc(packageId).update({
      'isActive': isActive, 'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<PackageModel>> activePackagesStream() => _db
      .collection(AppConstants.colPackages)
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(PackageModel.fromDoc).toList());

  Stream<List<PackageModel>> hotelPackagesStream(String hotelId) => _db
      .collection(AppConstants.colPackages)
      .where('hotelId', isEqualTo: hotelId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(PackageModel.fromDoc).toList());

  Future<List<PackageModel>> hotelPackagesFuture(String hotelId) async {
    final snap = await _db.collection(AppConstants.colPackages)
        .where('hotelId', isEqualTo: hotelId).get();
    return snap.docs.map(PackageModel.fromDoc).toList();
  }

  // ════════════════════════════════════════════════════════════════
  // ROOMS
  // ════════════════════════════════════════════════════════════════

  Future<void> createRoom(RoomModel room) async {
    final ref = _db.collection(AppConstants.colRooms).doc();
    await ref.set({...room.toMap(), 'roomId': ref.id});
  }

  Future<void> updateRoom(String roomId, Map<String, dynamic> data) async {
    if (roomId.isEmpty) throw ArgumentError('roomId vacío');
    await _db.collection(AppConstants.colRooms).doc(roomId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteRoom(String roomId) async {
    if (roomId.isEmpty) throw ArgumentError('roomId vacío');
    await _db.collection(AppConstants.colRooms).doc(roomId).delete();
  }

  Future<void> toggleRoomActive(String roomId, bool isActive) async {
    if (roomId.isEmpty) throw ArgumentError('roomId vacío');
    await _db.collection(AppConstants.colRooms).doc(roomId).update({
      'isActive': isActive, 'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<RoomModel>> allActiveRoomsStream() => _db
      .collection(AppConstants.colRooms)
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(RoomModel.fromDoc).toList());

  Stream<List<RoomModel>> hotelRoomsStream(String hotelId) => _db
      .collection(AppConstants.colRooms)
      .where('hotelId', isEqualTo: hotelId)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(RoomModel.fromDoc).toList());

  Stream<List<RoomModel>> hotelActiveRoomsStream(String hotelId) => _db
      .collection(AppConstants.colRooms)
      .where('hotelId', isEqualTo: hotelId)
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(RoomModel.fromDoc).toList());

  Future<List<RoomModel>> hotelActiveRoomsFuture(String hotelId) async {
    final snap = await _db.collection(AppConstants.colRooms)
        .where('hotelId', isEqualTo: hotelId)
        .where('isActive', isEqualTo: true).get();
    return snap.docs.map(RoomModel.fromDoc).toList();
  }

  Stream<List<Map<String, DateTime>>> roomOccupiedDatesStream(String roomId) {
    return _db
        .collection(AppConstants.colReservations)
        .where('roomId', isEqualTo: roomId)
        .where('status', whereIn: ['pending', 'accepted'])
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) {
              final d       = doc.data();
              final checkIn = (d['checkInDate']  as Timestamp?)?.toDate();
              final checkOut= (d['checkOutDate'] as Timestamp?)?.toDate();
              if (checkIn == null || checkOut == null) return null;
              return {'checkIn': checkIn, 'checkOut': checkOut};
            })
            .whereType<Map<String, DateTime>>()
            .toList());
  }

  // ════════════════════════════════════════════════════════════════
  // RESERVATIONS
  // ════════════════════════════════════════════════════════════════

  Future<void> createReservation(ReservationModel res) async {
    if (res.isPackage && res.packageId.isEmpty) {
      throw ArgumentError(
          'El paquete no tiene ID. Vuelve al listado y selecciónalo de nuevo.');
    }
    if (res.isRoomOnly && res.roomId.isEmpty) {
      throw ArgumentError('La habitación no tiene ID válido.');
    }
    if (res.hotelId.isEmpty) {
      throw ArgumentError('El hotel asociado no es válido.');
    }
    if (res.userId.isEmpty) {
      throw ArgumentError(
          'Usuario no identificado. Cierra sesión y vuelve a entrar.');
    }

    // Obtener el QR del hotel y copiarlo en la reserva
    String? hotelQrUrl;
    try {
      final hotelDoc = await _db
          .collection(AppConstants.colUsers).doc(res.hotelId).get();
      hotelQrUrl = hotelDoc.data()?['qrUrl'] as String?;
    } catch (_) {}

    final ref = _db.collection(AppConstants.colReservations).doc();
    await ref.set({
      ...res.toMap(),
      'reservationId': ref.id,
      if (hotelQrUrl != null && hotelQrUrl.isNotEmpty)
        'hotelQrUrl': hotelQrUrl,
    });

    try {
      final hotelDoc = await _db
          .collection(AppConstants.colUsers).doc(res.hotelId).get();
      final token = hotelDoc.data()?['fcmToken'] as String?;
      if (token != null && token.isNotEmpty) {
        await _notif.sendPushNotification(
          toToken: token,
          title:   res.isPackage
              ? '¡Nueva reserva de paquete!'
              : '¡Nueva reserva de habitación!',
          body:    res.isPackage
              ? '${res.guestName} reservó ${res.packageName}'
              : '${res.guestName} quiere reservar ${res.roomName}',
          data:    {'type': 'new_reservation', 'reservationId': ref.id},
        );
      }
    } catch (_) {}
  }

  Future<void> updateReservationStatus({
    required String reservationId,
    required String userId,
    required ReservationStatus status,
    required String hotelMessage,
    required String hotelName,
    required String packageName,
    DateTime?       tourGuideDate,
  }) async {
    if (reservationId.isEmpty) throw ArgumentError('reservationId vacío');
    if (userId.isEmpty && status != ReservationStatus.cancelled) {
      throw ArgumentError('userId vacío');
    }

    final update = <String, dynamic>{
      'status':       status.value,
      'hotelMessage': hotelMessage,
      'updatedAt':    FieldValue.serverTimestamp(),
    };
    if (tourGuideDate != null) {
      update['tourGuideDate'] = Timestamp.fromDate(tourGuideDate);
    }

    await _db.collection(AppConstants.colReservations)
        .doc(reservationId).update(update);

    if (userId.isNotEmpty) {
      try {
        final userDoc = await _db
            .collection(AppConstants.colUsers).doc(userId).get();
        final userToken = userDoc.data()?['fcmToken'] as String?;
        if (userToken != null && userToken.isNotEmpty) {
          final messages = {
            ReservationStatus.accepted:  ('¡Reserva aceptada! ✅',
                'Tu reserva en $hotelName fue aceptada.'),
            ReservationStatus.rejected:  ('Reserva rechazada ❌',
                'Tu reserva en $hotelName fue rechazada.'),
            ReservationStatus.cancelled: ('Reserva cancelada',
                'Tu reserva en $hotelName fue cancelada.'),
            ReservationStatus.completed: ('Reserva completada ⭐',
                'Tu estadía en $hotelName fue marcada como completada.'),
          };
          final msg = messages[status];
          if (msg != null) {
            await _notif.sendPushNotification(
              toToken: userToken,
              title:   msg.$1,
              body:    msg.$2,
              data: {
                'type':          'reservation_${status.value}',
                'reservationId': reservationId,
              },
            );
          }
        }
      } catch (_) {}
    }

    if (status == ReservationStatus.accepted) {
      try {
        final resDoc = await _db
            .collection(AppConstants.colReservations).doc(reservationId).get();
        final d         = resDoc.data()!;
        final hotelId   = d['hotelId']   as String?;
        final packageId = d['packageId'] as String?;
        if (hotelId != null && hotelId.isNotEmpty) {
          await _db.collection(AppConstants.colUsers).doc(hotelId)
              .update({'totalReservations': FieldValue.increment(1)});
        }
        if (packageId != null && packageId.isNotEmpty) {
          await _db.collection(AppConstants.colPackages).doc(packageId)
              .update({'totalReservations': FieldValue.increment(1)});
        }
      } catch (_) {}
    }
  }

  // ── NUEVO: guardar comprobante de pago ─────────────────────────────
  /// Llamado por el turista después de subir su comprobante a Supabase.
  Future<void> updateReservationPayment({
    required String reservationId,
    required String paymentReceiptUrl,
    required String paymentReceiptName,
  }) async {
    if (reservationId.isEmpty) throw ArgumentError('reservationId vacío');
    await _db.collection(AppConstants.colReservations)
        .doc(reservationId)
        .update({
      'paymentReceiptUrl':  paymentReceiptUrl,
      'paymentReceiptName': paymentReceiptName,
      'updatedAt':          FieldValue.serverTimestamp(),
    });
  }

  Future<void> assignTourGuideDate({
    required String   reservationId,
    required DateTime tourGuideDate,
  }) async {
    if (reservationId.isEmpty) throw ArgumentError('reservationId vacío');
    await _db.collection(AppConstants.colReservations).doc(reservationId)
        .update({
      'tourGuideDate': Timestamp.fromDate(tourGuideDate),
      'updatedAt':     FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ReservationModel>> userReservationsStream(String userId) => _db
      .collection(AppConstants.colReservations)
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ReservationModel.fromDoc).toList());

  Stream<List<ReservationModel>> hotelPendingReservationsStream(
      String hotelId) => _db
      .collection(AppConstants.colReservations)
      .where('hotelId', isEqualTo: hotelId)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ReservationModel.fromDoc).toList());

  Stream<List<ReservationModel>> hotelAllReservationsStream(
      String hotelId) => _db
      .collection(AppConstants.colReservations)
      .where('hotelId', isEqualTo: hotelId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ReservationModel.fromDoc).toList());

  // ════════════════════════════════════════════════════════════════
  // USERS (admin)
  // ════════════════════════════════════════════════════════════════

  Stream<List<UserModel>> hotelsStream() => _db
      .collection(AppConstants.colUsers)
      .where('role', isEqualTo: AppConstants.roleHotel)
      .orderBy('totalReservations', descending: true)
      .snapshots()
      .map((s) => s.docs.map(UserModel.fromDoc).toList());

  /// Devuelve los datos del documento de un usuario (hotel, turista, admin).
  /// Usado por el turista para leer el QR actual del hotel en tiempo real.
  Future<Map<String, dynamic>?> getUserDoc(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _db.collection(AppConstants.colUsers).doc(uid).get();
    return doc.data();
  }

  Future<void> updateHotelProfile(
      String hotelId, Map<String, dynamic> data) async {
    if (hotelId.isEmpty) throw ArgumentError('hotelId vacío');
    await _db.collection(AppConstants.colUsers).doc(hotelId).update({
      ...data, 'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleHotelActive(String hotelId, bool isActive) async {
    if (hotelId.isEmpty) throw ArgumentError('hotelId vacío');
    await _db.collection(AppConstants.colUsers).doc(hotelId).update({
      'isActive': isActive, 'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      final doc   = await _db.collection(AppConstants.colUsers).doc(hotelId).get();
      final token = doc.data()?['fcmToken'] as String?;
      if (token != null && token.isNotEmpty) {
        await _notif.sendPushNotification(
          toToken: token,
          title: isActive ? 'Cuenta reactivada ✅' : 'Cuenta suspendida ⚠️',
          body:  isActive
              ? 'Tu cuenta fue reactivada por el administrador.'
              : 'Tu cuenta fue suspendida. Contacta al administrador.',
          data: {'type': 'account_status'},
        );
      }
    } catch (_) {}
  }

  Future<void> deleteHotel(String hotelId) async {
    if (hotelId.isEmpty) throw ArgumentError('hotelId vacío');

    final inbox = await _db.collection(AppConstants.colUsers)
        .doc(hotelId).collection(AppConstants.colInbox).get();
    for (final doc in inbox.docs) { await doc.reference.delete(); }

    final pkgs = await _db.collection(AppConstants.colPackages)
        .where('hotelId', isEqualTo: hotelId).get();
    for (final doc in pkgs.docs) {
      await doc.reference.update({'isActive': false});
    }

    final rooms = await _db.collection(AppConstants.colRooms)
        .where('hotelId', isEqualTo: hotelId).get();
    for (final doc in rooms.docs) {
      await doc.reference.update({'isActive': false});
    }

    final reservations = await _db.collection(AppConstants.colReservations)
        .where('hotelId', isEqualTo: hotelId)
        .where('status', whereIn: ['pending', 'accepted']).get();
    for (final doc in reservations.docs) {
      await doc.reference.update({
        'status':       ReservationStatus.cancelled.value,
        'hotelMessage': 'El hotel ha sido eliminado de la plataforma.',
        'updatedAt':    FieldValue.serverTimestamp(),
      });
    }

    await _db.collection(AppConstants.colUsers).doc(hotelId).delete();
  }

  // ════════════════════════════════════════════════════════════════
  // INBOX
  // ════════════════════════════════════════════════════════════════

  Future<void> sendMessageToHotel({
    required String hotelId,
    required String adminId,
    required String subject,
    required String body,
  }) async {
    if (hotelId.isEmpty) throw ArgumentError('hotelId vacío');
    final msg = MessageModel(
      messageId:   '',
      fromAdminId: adminId,
      subject:     subject,
      body:        body,
      isRead:      false,
      createdAt:   DateTime.now(),
    );
    await _db.collection(AppConstants.colUsers).doc(hotelId)
        .collection(AppConstants.colInbox).add(msg.toMap());
    try {
      final hotelDoc = await _db
          .collection(AppConstants.colUsers).doc(hotelId).get();
      final token = hotelDoc.data()?['fcmToken'] as String?;
      if (token != null && token.isNotEmpty) {
        await _notif.sendPushNotification(
          toToken: token,
          title:   '📩 Nuevo mensaje del administrador',
          body:    subject,
          data:    {'type': 'new_message'},
        );
      }
    } catch (_) {}
  }

  Stream<List<MessageModel>> inboxStream(String hotelId) => _db
      .collection(AppConstants.colUsers)
      .doc(hotelId)
      .collection(AppConstants.colInbox)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MessageModel.fromDoc).toList());

  Future<void> markMessageRead(String hotelId, String messageId) async {
    if (hotelId.isEmpty || messageId.isEmpty) return;
    await _db.collection(AppConstants.colUsers).doc(hotelId)
        .collection(AppConstants.colInbox).doc(messageId)
        .update({'isRead': true});
  }
}