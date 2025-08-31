// lib/models/vehicle.dart

class Vehicle {
  final String id;
  final String name;
  final String regNumber;
  final String? photoPath;
  final double totalKm;
  final int totalTrips;
  final String status;
  final String type;

  Vehicle({
    required this.id,
    required this.name,
    required this.regNumber,
    this.photoPath,
    required this.totalKm,
    required this.totalTrips,
    required this.status,
    required this.type,
  });

  /// Convert Vehicle object to Map (for SQLite or JSON)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'regNumber': regNumber,
      'photoPath': photoPath,
      'totalKm': totalKm,
      'totalTrips': totalTrips,
      'status': status,
      'type': type,
    };
  }

  /// Create Vehicle object from Map (from SQLite or JSON)
  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'],
      name: map['name'],
      regNumber: map['regNumber'],
      photoPath: map['photoPath'],
      totalKm: map['totalKm'] ?? 0,
      totalTrips: map['totalTrips'] ?? 0,
      status: map['status'] ?? 'Available',
      type: map['type'] ?? 'Hatchback',
    );
  }
}
