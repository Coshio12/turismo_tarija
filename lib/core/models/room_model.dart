import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomType { single, double_, matrimonial, suite }

extension RoomTypeX on RoomType {
  String get value {
    switch (this) {
      case RoomType.single:      return 'single';
      case RoomType.double_:     return 'double';
      case RoomType.matrimonial: return 'matrimonial';
      case RoomType.suite:       return 'suite';
    }
  }

  String get label {
    switch (this) {
      case RoomType.single:      return 'Simple (1 cama individual)';
      case RoomType.double_:     return 'Doble (2 camas individuales)';
      case RoomType.matrimonial: return 'Matrimonial (1 cama doble)';
      case RoomType.suite:       return 'Suite';
    }
  }

  String get shortLabel {
    switch (this) {
      case RoomType.single:      return 'Simple';
      case RoomType.double_:     return 'Doble';
      case RoomType.matrimonial: return 'Matrimonial';
      case RoomType.suite:       return 'Suite';
    }
  }

  static RoomType fromString(String s) =>
      RoomType.values.firstWhere((e) => e.value == s,
          orElse: () => RoomType.single);
}

class RoomModel {
  final String   roomId;
  final String   hotelId;
  final String   hotelName;
  final String   roomName;
  final RoomType roomType;
  final int      capacity;
  final double   pricePerNight;
  final String   description;
  final bool     isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RoomModel({
    required this.roomId,
    required this.hotelId,
    required this.hotelName,
    required this.roomName,
    required this.roomType,
    required this.capacity,
    required this.pricePerNight,
    required this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoomModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RoomModel(
      roomId:        doc.id,
      hotelId:       d['hotelId']       ?? '',
      hotelName:     d['hotelName']     ?? '',
      roomName:      d['roomName']      ?? '',
      roomType:      RoomTypeX.fromString(d['roomType'] ?? 'single'),
      capacity:      d['capacity']      ?? 1,
      pricePerNight: (d['pricePerNight'] as num?)?.toDouble() ?? 0,
      description:   d['description']   ?? '',
      isActive:      d['isActive']      ?? true,
      createdAt:     (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:     (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'hotelId':       hotelId,
    'hotelName':     hotelName,
    'roomName':      roomName,
    'roomType':      roomType.value,
    'capacity':      capacity,
    'pricePerNight': pricePerNight,
    'description':   description,
    'isActive':      isActive,
    'createdAt':     Timestamp.fromDate(createdAt),
    'updatedAt':     Timestamp.fromDate(updatedAt),
  };

  RoomModel copyWith({
    String?   roomName,
    RoomType? roomType,
    int?      capacity,
    double?   pricePerNight,
    String?   description,
    bool?     isActive,
  }) =>
      RoomModel(
        roomId:        roomId,
        hotelId:       hotelId,
        hotelName:     hotelName,
        roomName:      roomName      ?? this.roomName,
        roomType:      roomType      ?? this.roomType,
        capacity:      capacity      ?? this.capacity,
        pricePerNight: pricePerNight ?? this.pricePerNight,
        description:   description   ?? this.description,
        isActive:      isActive      ?? this.isActive,
        createdAt:     createdAt,
        updatedAt:     DateTime.now(),
      );
}

/// Entrada de habitación dentro de un paquete.
/// [pricePerNight] se captura al momento de crear el paquete para que
/// el total se pueda calcular sin consultas extra a Firestore.
class PackageRoomEntry {
  final String roomId;
  final String roomName;
  final String roomType;
  final int    nights;
  final int    extraBeds;
  /// Precio por noche en Bs — copiado de RoomModel.pricePerNight.
  final double pricePerNight;

  const PackageRoomEntry({
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.nights,
    this.extraBeds     = 0,
    this.pricePerNight = 0,
  });

  /// Costo de esta habitación = pricePerNight × nights.
  double get subtotal => pricePerNight * nights;

  factory PackageRoomEntry.fromMap(Map<String, dynamic> m) =>
      PackageRoomEntry(
        roomId:        m['roomId']        ?? '',
        roomName:      m['roomName']      ?? '',
        roomType:      m['roomType']      ?? 'single',
        nights:        m['nights']        ?? 1,
        extraBeds:     m['extraBeds']     ?? 0,
        pricePerNight: (m['pricePerNight'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
    'roomId':        roomId,
    'roomName':      roomName,
    'roomType':      roomType,
    'nights':        nights,
    'extraBeds':     extraBeds,
    'pricePerNight': pricePerNight,
  };
}

class OccupantEntry {
  final String role;
  final String ageGroup;

  const OccupantEntry({required this.role, required this.ageGroup});

  factory OccupantEntry.fromMap(Map<String, dynamic> m) =>
      OccupantEntry(role: m['role'] ?? '', ageGroup: m['ageGroup'] ?? 'adult');

  Map<String, dynamic> toMap() => {'role': role, 'ageGroup': ageGroup};

  String get ageLabel {
    switch (ageGroup) {
      case 'child':  return 'Niño';
      case 'infant': return 'Infante';
      default:       return 'Adulto';
    }
  }
}