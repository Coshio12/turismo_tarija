import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String role; // 'public' | 'hotel' | 'admin'
  final bool isActive;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Solo rol hotel
  final String? hotelName;
  final String? address;
  final GeoPoint? location;
  final String? phone;
  final int totalReservations;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
    this.hotelName,
    this.address,
    this.location,
    this.phone,
    this.totalReservations = 0,
  });

  bool get isPublic => role == 'public';
  bool get isHotel  => role == 'hotel';
  bool get isAdmin  => role == 'admin';

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid:               doc.id,
      email:             d['email'] ?? '',
      displayName:       d['displayName'] ?? '',
      role:              d['role'] ?? 'public',
      isActive:          d['isActive'] ?? true,
      fcmToken:          d['fcmToken'],
      createdAt:         (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:         (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hotelName:         d['hotelName'],
      address:           d['address'],
      location:          d['location'],
      phone:             d['phone'],
      totalReservations: d['totalReservations'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':               uid,
    'email':             email,
    'displayName':       displayName,
    'role':              role,
    'isActive':          isActive,
    'fcmToken':          fcmToken,
    'createdAt':         Timestamp.fromDate(createdAt),
    'updatedAt':         Timestamp.fromDate(updatedAt),
    if (hotelName != null) 'hotelName':         hotelName,
    if (address   != null) 'address':           address,
    if (location  != null) 'location':          location,
    if (phone     != null) 'phone':             phone,
    'totalReservations': totalReservations,
  };

  UserModel copyWith({
    String?   displayName,
    bool?     isActive,
    String?   fcmToken,
    String?   hotelName,
    String?   address,
    GeoPoint? location,
    String?   phone,
    int?      totalReservations,
  }) {
    return UserModel(
      uid:               uid,
      email:             email,
      displayName:       displayName ?? this.displayName,
      role:              role,
      isActive:          isActive ?? this.isActive,
      fcmToken:          fcmToken  ?? this.fcmToken,
      createdAt:         createdAt,
      updatedAt:         DateTime.now(),
      hotelName:         hotelName         ?? this.hotelName,
      address:           address           ?? this.address,
      location:          location          ?? this.location,
      phone:             phone             ?? this.phone,
      totalReservations: totalReservations ?? this.totalReservations,
    );
  }
}
