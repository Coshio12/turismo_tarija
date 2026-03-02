import 'package:cloud_firestore/cloud_firestore.dart';

enum ReservationStatus { pending, accepted, rejected, cancelled, completed }

extension ReservationStatusX on ReservationStatus {
  String get value {
    switch (this) {
      case ReservationStatus.pending:   return 'pending';
      case ReservationStatus.accepted:  return 'accepted';
      case ReservationStatus.rejected:  return 'rejected';
      case ReservationStatus.cancelled: return 'cancelled';
      case ReservationStatus.completed: return 'completed';
    }
  }

  String get label {
    switch (this) {
      case ReservationStatus.pending:   return 'En espera';
      case ReservationStatus.accepted:  return 'Aceptada';
      case ReservationStatus.rejected:  return 'Rechazada';
      case ReservationStatus.cancelled: return 'Cancelada';
      case ReservationStatus.completed: return 'Completada';
    }
  }

  static ReservationStatus fromString(String s) =>
      ReservationStatus.values.firstWhere(
        (e) => e.value == s,
        orElse: () => ReservationStatus.pending,
      );
}

enum ReservationType { room, package }

extension ReservationTypeX on ReservationType {
  String get value => this == ReservationType.room ? 'room' : 'package';
  String get label =>
      this == ReservationType.room ? 'Hospedaje' : 'Paquete Turístico';

  static ReservationType fromString(String? s) =>
      s == 'room' ? ReservationType.room : ReservationType.package;
}

class ReservationModel {
  final String reservationId;
  final String packageId;
  final String packageName;
  final String roomId;
  final String roomName;
  final String hotelId;
  final String hotelName;
  final String userId;
  final String guestName;
  final String guestPhone;
  final int    numberOfPeople;
  final DateTime  checkInDate;
  final DateTime  checkOutDate;
  final DateTime? tourGuideDate;
  final ReservationType   reservationType;
  final double            totalPrice;
  final ReservationStatus status;
  final String            hotelMessage;
  final DateTime          createdAt;
  final DateTime          updatedAt;

  // ── Campos de pago ──────────────────────────────────────────────────
  /// URL pública del QR de pago del hotel (guardada en el doc del usuario-hotel).
  /// Se copia aquí al crear la reserva para que el turista siempre la vea.
  final String? hotelQrUrl;

  /// URL pública del comprobante subido por el turista a Supabase.
  final String? paymentReceiptUrl;

  /// Nombre del archivo del comprobante (ej: "comprobante.pdf").
  final String? paymentReceiptName;

  const ReservationModel({
    required this.reservationId,
    required this.packageId,
    required this.packageName,
    required this.roomId,
    required this.roomName,
    required this.hotelId,
    required this.hotelName,
    required this.userId,
    required this.guestName,
    required this.guestPhone,
    required this.numberOfPeople,
    required this.checkInDate,
    required this.checkOutDate,
    this.tourGuideDate,
    required this.reservationType,
    required this.totalPrice,
    required this.status,
    required this.hotelMessage,
    required this.createdAt,
    required this.updatedAt,
    this.hotelQrUrl,
    this.paymentReceiptUrl,
    this.paymentReceiptName,
  });

  factory ReservationModel.fromDoc(DocumentSnapshot doc) {
    final d       = doc.data() as Map<String, dynamic>;
    final checkIn = (d['checkInDate']  as Timestamp?)?.toDate() ?? DateTime.now();
    final checkOut= (d['checkOutDate'] as Timestamp?)?.toDate()
        ?? checkIn.add(const Duration(days: 1));
    return ReservationModel(
      reservationId:      doc.id,
      packageId:          d['packageId']    ?? '',
      packageName:        d['packageName']  ?? '',
      roomId:             d['roomId']       ?? '',
      roomName:           d['roomName']     ?? '',
      hotelId:            d['hotelId']      ?? '',
      hotelName:          d['hotelName']    ?? '',
      userId:             d['userId']       ?? '',
      guestName:          d['guestName']    ?? '',
      guestPhone:         d['guestPhone']   ?? '',
      numberOfPeople:     d['numberOfPeople'] ?? 1,
      checkInDate:        checkIn,
      checkOutDate:       checkOut,
      tourGuideDate:      (d['tourGuideDate'] as Timestamp?)?.toDate(),
      reservationType:    ReservationTypeX.fromString(d['reservationType'] as String?),
      totalPrice:         (d['totalPrice'] as num?)?.toDouble() ?? 0,
      status:             ReservationStatusX.fromString(d['status'] ?? 'pending'),
      hotelMessage:       d['hotelMessage']     ?? '',
      createdAt:          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:          (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hotelQrUrl:         d['hotelQrUrl']         as String?,
      paymentReceiptUrl:  d['paymentReceiptUrl']  as String?,
      paymentReceiptName: d['paymentReceiptName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'packageId':       packageId,
    'packageName':     packageName,
    'roomId':          roomId,
    'roomName':        roomName,
    'hotelId':         hotelId,
    'hotelName':       hotelName,
    'userId':          userId,
    'guestName':       guestName,
    'guestPhone':      guestPhone,
    'numberOfPeople':  numberOfPeople,
    'checkInDate':     Timestamp.fromDate(checkInDate),
    'checkOutDate':    Timestamp.fromDate(checkOutDate),
    if (tourGuideDate != null)
      'tourGuideDate': Timestamp.fromDate(tourGuideDate!),
    'reservationType': reservationType.value,
    'totalPrice':      totalPrice,
    'status':          status.value,
    'hotelMessage':    hotelMessage,
    'createdAt':       Timestamp.fromDate(createdAt),
    'updatedAt':       Timestamp.fromDate(updatedAt),
    if (hotelQrUrl != null)
      'hotelQrUrl':          hotelQrUrl,
    if (paymentReceiptUrl != null)
      'paymentReceiptUrl':   paymentReceiptUrl,
    if (paymentReceiptName != null)
      'paymentReceiptName':  paymentReceiptName,
  };

  int  get nights            => checkOutDate.difference(checkInDate).inDays.clamp(1, 9999);
  bool get isPackage         => reservationType == ReservationType.package;
  bool get isRoomOnly        => reservationType == ReservationType.room;
  bool get tourGuideAssigned => tourGuideDate != null;
  bool get hasReceipt        => paymentReceiptUrl != null && paymentReceiptUrl!.isNotEmpty;
  bool get hasQr             => hotelQrUrl != null && hotelQrUrl!.isNotEmpty;

  ReservationModel copyWith({
    ReservationStatus? status,
    String?            hotelMessage,
    DateTime?          tourGuideDate,
    String?            hotelQrUrl,
    String?            paymentReceiptUrl,
    String?            paymentReceiptName,
  }) => ReservationModel(
    reservationId:      reservationId,
    packageId:          packageId,
    packageName:        packageName,
    roomId:             roomId,
    roomName:           roomName,
    hotelId:            hotelId,
    hotelName:          hotelName,
    userId:             userId,
    guestName:          guestName,
    guestPhone:         guestPhone,
    numberOfPeople:     numberOfPeople,
    checkInDate:        checkInDate,
    checkOutDate:       checkOutDate,
    tourGuideDate:      tourGuideDate     ?? this.tourGuideDate,
    reservationType:    reservationType,
    totalPrice:         totalPrice,
    status:             status            ?? this.status,
    hotelMessage:       hotelMessage      ?? this.hotelMessage,
    createdAt:          createdAt,
    updatedAt:          DateTime.now(),
    hotelQrUrl:         hotelQrUrl        ?? this.hotelQrUrl,
    paymentReceiptUrl:  paymentReceiptUrl ?? this.paymentReceiptUrl,
    paymentReceiptName: paymentReceiptName?? this.paymentReceiptName,
  );
}