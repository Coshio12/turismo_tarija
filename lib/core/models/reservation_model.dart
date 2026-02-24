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

  static ReservationStatus fromString(String s) {
    return ReservationStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => ReservationStatus.pending,
    );
  }
}

class ReservationModel {
  final String reservationId;
  final String packageId;
  final String packageName;
  final String hotelId;
  final String hotelName;
  final String userId;
  final String guestName;
  final String guestPhone;
  final int numberOfPeople;
  final DateTime? checkInDate;
  final DateTime? checkOutDate;
  final DateTime? tourGuideDate;
  final bool includesLodging;
  final bool includesTourGuide;
  final double totalPrice;
  final ReservationStatus status;
  final String hotelMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReservationModel({
    required this.reservationId,
    required this.packageId,
    required this.packageName,
    required this.hotelId,
    required this.hotelName,
    required this.userId,
    required this.guestName,
    required this.guestPhone,
    required this.numberOfPeople,
    this.checkInDate,
    this.checkOutDate,
    this.tourGuideDate,
    required this.includesLodging,
    required this.includesTourGuide,
    required this.totalPrice,
    required this.status,
    required this.hotelMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReservationModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ReservationModel(
      reservationId:    doc.id,
      packageId:        d['packageId']    ?? '',
      packageName:      d['packageName']  ?? '',
      hotelId:          d['hotelId']      ?? '',
      hotelName:        d['hotelName']    ?? '',
      userId:           d['userId']       ?? '',
      guestName:        d['guestName']    ?? '',
      guestPhone:       d['guestPhone']   ?? '',
      numberOfPeople:   d['numberOfPeople'] ?? 1,
      checkInDate:      (d['checkInDate']   as Timestamp?)?.toDate(),
      checkOutDate:     (d['checkOutDate']  as Timestamp?)?.toDate(),
      tourGuideDate:    (d['tourGuideDate'] as Timestamp?)?.toDate(),
      includesLodging:  d['includesLodging']  ?? false,
      includesTourGuide:d['includesTourGuide']?? false,
      totalPrice:       (d['totalPrice'] as num?)?.toDouble() ?? 0,
      status:           ReservationStatusX.fromString(d['status'] ?? 'pending'),
      hotelMessage:     d['hotelMessage'] ?? '',
      createdAt:        (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:        (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'packageId':         packageId,
    'packageName':       packageName,
    'hotelId':           hotelId,
    'hotelName':         hotelName,
    'userId':            userId,
    'guestName':         guestName,
    'guestPhone':        guestPhone,
    'numberOfPeople':    numberOfPeople,
    if (checkInDate    != null) 'checkInDate':    Timestamp.fromDate(checkInDate!),
    if (checkOutDate   != null) 'checkOutDate':   Timestamp.fromDate(checkOutDate!),
    if (tourGuideDate  != null) 'tourGuideDate':  Timestamp.fromDate(tourGuideDate!),
    'includesLodging':   includesLodging,
    'includesTourGuide': includesTourGuide,
    'totalPrice':        totalPrice,
    'status':            status.value,
    'hotelMessage':      hotelMessage,
    'createdAt':         Timestamp.fromDate(createdAt),
    'updatedAt':         Timestamp.fromDate(updatedAt),
  };
}
