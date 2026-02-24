import 'package:cloud_firestore/cloud_firestore.dart';

class PackageModel {
  final String packageId;
  final String hotelId;
  final String hotelName;
  final GeoPoint hotelLocation;
  final String hotelAddress;
  final String packageName;
  final String description;
  final double pricePerPerson;
  final bool isActive;
  final int totalReservations;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PackageModel({
    required this.packageId,
    required this.hotelId,
    required this.hotelName,
    required this.hotelLocation,
    required this.hotelAddress,
    required this.packageName,
    required this.description,
    required this.pricePerPerson,
    required this.isActive,
    required this.totalReservations,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PackageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PackageModel(
      packageId:         doc.id,
      hotelId:           d['hotelId']       ?? '',
      hotelName:         d['hotelName']     ?? '',
      hotelLocation:     d['hotelLocation'] as GeoPoint,
      hotelAddress:      d['hotelAddress']  ?? '',
      packageName:       d['packageName']   ?? '',
      description:       d['description']   ?? '',
      pricePerPerson:    (d['pricePerPerson'] as num?)?.toDouble() ?? 0,
      isActive:          d['isActive']      ?? true,
      totalReservations: d['totalReservations'] ?? 0,
      createdAt:         (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:         (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'hotelId':           hotelId,
    'hotelName':         hotelName,
    'hotelLocation':     hotelLocation,
    'hotelAddress':      hotelAddress,
    'packageName':       packageName,
    'description':       description,
    'pricePerPerson':    pricePerPerson,
    'isActive':          isActive,
    'totalReservations': totalReservations,
    'createdAt':         Timestamp.fromDate(createdAt),
    'updatedAt':         Timestamp.fromDate(updatedAt),
  };

  PackageModel copyWith({
    String?   hotelName,
    GeoPoint? hotelLocation,
    String?   hotelAddress,
    String?   packageName,
    String?   description,
    double?   pricePerPerson,
    bool?     isActive,
    int?      totalReservations,
  }) {
    return PackageModel(
      packageId:         packageId,
      hotelId:           hotelId,
      hotelName:         hotelName         ?? this.hotelName,
      hotelLocation:     hotelLocation     ?? this.hotelLocation,
      hotelAddress:      hotelAddress      ?? this.hotelAddress,
      packageName:       packageName       ?? this.packageName,
      description:       description       ?? this.description,
      pricePerPerson:    pricePerPerson    ?? this.pricePerPerson,
      isActive:          isActive          ?? this.isActive,
      totalReservations: totalReservations ?? this.totalReservations,
      createdAt:         createdAt,
      updatedAt:         DateTime.now(),
    );
  }
}
