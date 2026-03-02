import 'package:cloud_firestore/cloud_firestore.dart';
import 'room_model.dart';

enum PackageType { lodging, tourist }

extension PackageTypeX on PackageType {
  String get value => this == PackageType.lodging ? 'lodging' : 'tourist';
  String get label => this == PackageType.lodging ? 'Hospedaje' : 'Paquete Turístico';

  static PackageType fromString(String? s) =>
      s == 'lodging' ? PackageType.lodging : PackageType.tourist;
}

class PackageModel {
  final String      packageId;
  final String      hotelId;
  final String      hotelName;
  final GeoPoint    hotelLocation;
  final String      hotelAddress;
  final String      packageName;
  final String      description;

  /// Precio del servicio de guía turística por persona (Bs).
  /// El precio total de un paquete se calcula como:
  ///   total = roomsTotalPrice + guidePricePerPerson × personas
  ///
  /// Para paquetes de tipo [lodging], este campo es 0.
  /// [pricePerPerson] es un alias mantenido por retrocompatibilidad.
  final double guidePricePerPerson;

  final bool     isActive;
  final int      totalReservations;
  final DateTime createdAt;
  final DateTime updatedAt;

  final PackageType            packageType;
  final List<OccupantEntry>    occupants;
  final List<PackageRoomEntry> rooms;
  final int                    totalNights;
  final int                    minPeople;
  final int                    maxPeople;
  final List<String>           includedServices;

  // ── Alias retrocompatible ─────────────────────────────────────────
  double get pricePerPerson => guidePricePerPerson;

  // ── Helpers de precio ─────────────────────────────────────────────

  /// Suma de (pricePerNight × nights) de todas las habitaciones.
  double get roomsTotalPrice =>
      rooms.fold(0.0, (sum, r) => sum + r.subtotal);

  /// Costo total = habitaciones + guía × personas.
  double totalPriceForPeople(int numberOfPeople) =>
      roomsTotalPrice + guidePricePerPerson * numberOfPeople;

  const PackageModel({
    required this.packageId,
    required this.hotelId,
    required this.hotelName,
    required this.hotelLocation,
    required this.hotelAddress,
    required this.packageName,
    required this.description,
    required this.guidePricePerPerson,
    required this.isActive,
    required this.totalReservations,
    required this.createdAt,
    required this.updatedAt,
    this.packageType      = PackageType.tourist,
    this.occupants        = const [],
    this.rooms            = const [],
    this.totalNights      = 0,
    this.minPeople        = 1,
    this.maxPeople        = 10,
    this.includedServices = const [],
  });

  factory PackageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    final rawOccupants = (d['occupants'] as List?)
            ?.map((e) => OccupantEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    final rawRooms = (d['rooms'] as List?)
            ?.map((e) => PackageRoomEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    final rawServices = (d['includedServices'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // Retrocompatibilidad: si guidePricePerPerson no existe, usa pricePerPerson
    final double legacy =
        (d['pricePerPerson'] as num?)?.toDouble() ?? 0;
    final double guidePrice =
        (d['guidePricePerPerson'] as num?)?.toDouble() ?? legacy;

    return PackageModel(
      packageId:            doc.id,
      hotelId:              d['hotelId']       ?? '',
      hotelName:            d['hotelName']     ?? '',
      hotelLocation:        d['hotelLocation'] as GeoPoint,
      hotelAddress:         d['hotelAddress']  ?? '',
      packageName:          d['packageName']   ?? '',
      description:          d['description']   ?? '',
      guidePricePerPerson:  guidePrice,
      isActive:             d['isActive']      ?? true,
      totalReservations:    d['totalReservations'] ?? 0,
      createdAt:  (d['createdAt']  as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:  (d['updatedAt']  as Timestamp?)?.toDate() ?? DateTime.now(),
      packageType:      PackageTypeX.fromString(d['packageType'] as String?),
      occupants:        rawOccupants,
      rooms:            rawRooms,
      totalNights:      d['totalNights']  ?? 0,
      minPeople:        d['minPeople']    ?? 1,
      maxPeople:        d['maxPeople']    ?? 10,
      includedServices: rawServices,
    );
  }

  Map<String, dynamic> toMap() => {
    'hotelId':             hotelId,
    'hotelName':           hotelName,
    'hotelLocation':       hotelLocation,
    'hotelAddress':        hotelAddress,
    'packageName':         packageName,
    'description':         description,
    'pricePerPerson':      guidePricePerPerson, // alias legacy
    'guidePricePerPerson': guidePricePerPerson,
    'isActive':            isActive,
    'totalReservations':   totalReservations,
    'createdAt':           Timestamp.fromDate(createdAt),
    'updatedAt':           Timestamp.fromDate(updatedAt),
    'packageType':         packageType.value,
    'occupants':           occupants.map((e) => e.toMap()).toList(),
    'rooms':               rooms.map((e) => e.toMap()).toList(),
    'totalNights':         totalNights,
    'minPeople':           minPeople,
    'maxPeople':           maxPeople,
    'includedServices':    includedServices,
  };

  PackageModel copyWith({
    String?                  hotelName,
    GeoPoint?                hotelLocation,
    String?                  hotelAddress,
    String?                  packageName,
    String?                  description,
    double?                  guidePricePerPerson,
    bool?                    isActive,
    int?                     totalReservations,
    PackageType?             packageType,
    List<OccupantEntry>?     occupants,
    List<PackageRoomEntry>?  rooms,
    int?                     totalNights,
    int?                     minPeople,
    int?                     maxPeople,
    List<String>?            includedServices,
  }) =>
      PackageModel(
        packageId:            packageId,
        hotelId:              hotelId,
        hotelName:            hotelName            ?? this.hotelName,
        hotelLocation:        hotelLocation        ?? this.hotelLocation,
        hotelAddress:         hotelAddress         ?? this.hotelAddress,
        packageName:          packageName          ?? this.packageName,
        description:          description          ?? this.description,
        guidePricePerPerson:  guidePricePerPerson  ?? this.guidePricePerPerson,
        isActive:             isActive             ?? this.isActive,
        totalReservations:    totalReservations    ?? this.totalReservations,
        createdAt:            createdAt,
        updatedAt:            DateTime.now(),
        packageType:          packageType          ?? this.packageType,
        occupants:            occupants            ?? this.occupants,
        rooms:                rooms                ?? this.rooms,
        totalNights:          totalNights          ?? this.totalNights,
        minPeople:            minPeople            ?? this.minPeople,
        maxPeople:            maxPeople            ?? this.maxPeople,
        includedServices:     includedServices     ?? this.includedServices,
      );
}