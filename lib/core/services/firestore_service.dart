import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/message_model.dart';
import '../models/package_model.dart';
import '../models/reservation_model.dart';
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
    // FIX: validar que el ID no sea vacío antes de llamar a Firestore
    if (packageId.isEmpty) throw ArgumentError('packageId no puede estar vacío');
    await _db
        .collection(AppConstants.colPackages)
        .doc(packageId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deletePackage(String packageId) async {
    if (packageId.isEmpty) throw ArgumentError('packageId no puede estar vacío');
    await _db.collection(AppConstants.colPackages).doc(packageId).delete();
  }

  Future<void> togglePackageActive(String packageId, bool isActive) async {
    if (packageId.isEmpty) throw ArgumentError('packageId no puede estar vacío');
    await _db.collection(AppConstants.colPackages).doc(packageId).update({
      'isActive':  isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<PackageModel>> activePackagesStream() {
    return _db
        .collection(AppConstants.colPackages)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PackageModel.fromDoc).toList());
  }

  Stream<List<PackageModel>> hotelPackagesStream(String hotelId) {
    return _db
        .collection(AppConstants.colPackages)
        .where('hotelId', isEqualTo: hotelId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PackageModel.fromDoc).toList());
  }

  // ════════════════════════════════════════════════════════════════
  // RESERVATIONS
  // ════════════════════════════════════════════════════════════════

  /// FIX PRINCIPAL: Se validaban los IDs críticos antes de escribir
  /// en Firestore. El error "document path must be a non-empty string"
  /// ocurría cuando res.hotelId o res.userId venían vacíos, porque
  /// luego se usaban como path al notificar.
  Future<void> createReservation(ReservationModel res) async {
    // ── Validaciones defensivas ──────────────────────────────────
    if (res.packageId.isEmpty) {
      throw ArgumentError('El paquete no tiene ID. Vuelve al listado y selecciónalo de nuevo.');
    }
    if (res.hotelId.isEmpty) {
      throw ArgumentError('El hotel asociado al paquete no es válido.');
    }
    if (res.userId.isEmpty) {
      throw ArgumentError('Usuario no identificado. Cierra sesión y vuelve a entrar.');
    }

    // 1. Guardar reserva
    final ref = _db.collection(AppConstants.colReservations).doc();
    await ref.set({...res.toMap(), 'reservationId': ref.id});

    // 2. Obtener token del hotel y notificar (solo si el hotelId es válido)
    try {
      final hotelDoc = await _db
          .collection(AppConstants.colUsers)
          .doc(res.hotelId)
          .get();
      final hotelToken = hotelDoc.data()?['fcmToken'] as String?;
      if (hotelToken != null && hotelToken.isNotEmpty) {
        await _notif.sendPushNotification(
          toToken: hotelToken,
          title:   '¡Nueva reserva recibida!',
          body:    '${res.guestName} quiere reservar ${res.packageName}',
          data:    {'type': 'new_reservation', 'reservationId': ref.id},
        );
      }
    } catch (_) {
      // La notificación es no crítica — no impide que la reserva se guarde
    }
  }

  Future<void> updateReservationStatus({
    required String reservationId,
    required String userId,
    required ReservationStatus status,
    required String hotelMessage,
    required String hotelName,
    required String packageName,
  }) async {
    if (reservationId.isEmpty) throw ArgumentError('reservationId vacío');
    if (userId.isEmpty)        throw ArgumentError('userId vacío');

    // 1. Actualizar estado
    await _db.collection(AppConstants.colReservations).doc(reservationId).update({
      'status':       status.value,
      'hotelMessage': hotelMessage,
      'updatedAt':    FieldValue.serverTimestamp(),
    });

    // 2. Notificar al usuario (no crítico)
    try {
      final userDoc = await _db
          .collection(AppConstants.colUsers)
          .doc(userId)
          .get();
      final userToken = userDoc.data()?['fcmToken'] as String?;
      if (userToken != null && userToken.isNotEmpty) {
        final messages = {
          ReservationStatus.accepted:  ('¡Reserva aceptada! ✅', 'Tu reserva en $hotelName fue aceptada.'),
          ReservationStatus.rejected:  ('Reserva rechazada ❌',  'Tu reserva en $hotelName fue rechazada.'),
          ReservationStatus.cancelled: ('Reserva cancelada',    'Tu reserva en $hotelName fue cancelada.'),
          ReservationStatus.completed: ('Reserva completada ⭐','Tu estadía en $hotelName fue marcada como completada.'),
        };
        final msg = messages[status];
        if (msg != null) {
          await _notif.sendPushNotification(
            toToken: userToken,
            title:   msg.$1,
            body:    msg.$2,
            data:    {'type': 'reservation_${status.value}', 'reservationId': reservationId},
          );
        }
      }
    } catch (_) {}

    // 3. Incrementar contadores si se aceptó
    if (status == ReservationStatus.accepted) {
      try {
        final resDoc = await _db
            .collection(AppConstants.colReservations)
            .doc(reservationId)
            .get();
        final hotelId   = resDoc.data()?['hotelId']   as String?;
        final packageId = resDoc.data()?['packageId'] as String?;
        if (hotelId != null && hotelId.isNotEmpty) {
          await _db.collection(AppConstants.colUsers).doc(hotelId).update(
              {'totalReservations': FieldValue.increment(1)});
        }
        if (packageId != null && packageId.isNotEmpty) {
          await _db.collection(AppConstants.colPackages).doc(packageId).update(
              {'totalReservations': FieldValue.increment(1)});
        }
      } catch (_) {}
    }
  }

  Stream<List<ReservationModel>> userReservationsStream(String userId) {
    return _db
        .collection(AppConstants.colReservations)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ReservationModel.fromDoc).toList());
  }

  Stream<List<ReservationModel>> hotelPendingReservationsStream(String hotelId) {
    return _db
        .collection(AppConstants.colReservations)
        .where('hotelId', isEqualTo: hotelId)
        .where('status',  isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ReservationModel.fromDoc).toList());
  }

  Stream<List<ReservationModel>> hotelAllReservationsStream(String hotelId) {
    return _db
        .collection(AppConstants.colReservations)
        .where('hotelId', isEqualTo: hotelId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ReservationModel.fromDoc).toList());
  }

  // ════════════════════════════════════════════════════════════════
  // USERS (admin)
  // ════════════════════════════════════════════════════════════════

  Stream<List<UserModel>> hotelsStream() {
    return _db
        .collection(AppConstants.colUsers)
        .where('role', isEqualTo: AppConstants.roleHotel)
        .orderBy('totalReservations', descending: true)
        .snapshots()
        .map((s) => s.docs.map(UserModel.fromDoc).toList());
  }


  Future<void> updateHotelProfile(String hotelId, Map<String, dynamic> data) async {
    if (hotelId.isEmpty) throw ArgumentError('hotelId vacío');
    await _db.collection(AppConstants.colUsers).doc(hotelId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleHotelActive(String hotelId, bool isActive) async {
    if (hotelId.isEmpty) throw ArgumentError('hotelId vacío');
    await _db.collection(AppConstants.colUsers).doc(hotelId).update({
      'isActive':  isActive,
      'updatedAt': FieldValue.serverTimestamp(),
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

  /// FIX: también elimina las reservas huérfanas del hotel
  Future<void> deleteHotel(String hotelId) async {
    if (hotelId.isEmpty) throw ArgumentError('hotelId vacío');

    // 1. Eliminar subcolección inbox
    final inbox = await _db
        .collection(AppConstants.colUsers)
        .doc(hotelId)
        .collection(AppConstants.colInbox)
        .get();
    for (final doc in inbox.docs) {
      await doc.reference.delete();
    }

    // 2. Suspender paquetes (se conserva historial)
    final pkgs = await _db
        .collection(AppConstants.colPackages)
        .where('hotelId', isEqualTo: hotelId)
        .get();
    for (final doc in pkgs.docs) {
      await doc.reference.update({'isActive': false});
    }

    // 3. Cancelar reservas pendientes/aceptadas del hotel
    final reservations = await _db
        .collection(AppConstants.colReservations)
        .where('hotelId', isEqualTo: hotelId)
        .where('status', whereIn: ['pending', 'accepted'])
        .get();
    for (final doc in reservations.docs) {
      await doc.reference.update({
        'status':       ReservationStatus.cancelled.value,
        'hotelMessage': 'El hotel ha sido eliminado de la plataforma.',
        'updatedAt':    FieldValue.serverTimestamp(),
      });
    }

    // 4. Eliminar doc del usuario
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
    await _db
        .collection(AppConstants.colUsers)
        .doc(hotelId)
        .collection(AppConstants.colInbox)
        .add(msg.toMap());

    try {
      final hotelDoc = await _db
          .collection(AppConstants.colUsers)
          .doc(hotelId)
          .get();
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

  Stream<List<MessageModel>> inboxStream(String hotelId) {
    return _db
        .collection(AppConstants.colUsers)
        .doc(hotelId)
        .collection(AppConstants.colInbox)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(MessageModel.fromDoc).toList());
  }

  Future<void> markMessageRead(String hotelId, String messageId) async {
    if (hotelId.isEmpty || messageId.isEmpty) return;
    await _db
        .collection(AppConstants.colUsers)
        .doc(hotelId)
        .collection(AppConstants.colInbox)
        .doc(messageId)
        .update({'isRead': true});
  }

  Future<List<PackageModel>> hotelPackagesFuture(String hotelId) async {
    final snap = await _db
        .collection(AppConstants.colPackages)
        .where('hotelId', isEqualTo: hotelId)
        .get();
    return snap.docs.map(PackageModel.fromDoc).toList();
  }
}