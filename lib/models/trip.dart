
class Trip {
  final String id;
  final String vehicleId;
  final String driverId;
  final String? customerName;
  final String customerPhone;
  final String? pickupArea;
  final String? dropArea;
  final String? startDateTime;
  final String tripType;
  final String? packageType;
  final double distance;
  final double ratePerKm;
  final double fastag;
  final double extraCharges;
  final double earnings;
  final String description;
  final String timestamp;
  final double netTotal;
  final String? endDateTime;
  final double durationHours;
  final String bookingId;
  final String customerId;

  Trip({
    required this.id,
    required this.vehicleId,
    required this.driverId,
    this.customerName,
    required this.customerPhone,
    this.pickupArea,
    this.dropArea,
    this.startDateTime,
    required this.tripType,
    this.packageType,
    required this.distance,
    required this.ratePerKm,
    required this.fastag,
    required this.extraCharges,
    required this.earnings,
    required this.description,
    required this.timestamp,
    required this.netTotal,
    this.endDateTime,
    required this.durationHours,
    required this.bookingId,
    required this.customerId,
  });

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as String,
      vehicleId: map['vehicleId'] as String,
      driverId: map['driverId'] as String,
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String,
      pickupArea: map['pickupArea'] as String?,
      dropArea: map['dropArea'] as String?,
      startDateTime: map['startDateTime'] as String?,
      tripType: map['tripType'] as String,
      packageType: map['packageType'] as String?,
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      ratePerKm: (map['ratePerKm'] as num?)?.toDouble() ?? 0.0,
      fastag: (map['fastag'] as num?)?.toDouble() ?? 0.0,
      extraCharges: (map['extraCharges'] as num?)?.toDouble() ?? 0.0,
      earnings: (map['earnings'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      timestamp: map['timestamp'] as String,
      netTotal: (map['netTotal'] as num?)?.toDouble() ?? 0.0,
      endDateTime: map['endDateTime'] as String?,
      durationHours: (map['durationHours'] as num?)?.toDouble() ?? 0.0,
      bookingId: map['bookingId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    String sanitizeString(String? input) {
      if (input == null || input.isEmpty) return '';
      return input.replaceAll(RegExp(r'["\\]'), '').trim();
    }

    return {
      'id': id,
      'vehicleId': vehicleId,
      'driverId': driverId,
      'customerName': sanitizeString(customerName),
      'customerPhone': sanitizeString(customerPhone),
      'pickupArea': sanitizeString(pickupArea),
      'dropArea': sanitizeString(dropArea),
      'startDateTime': startDateTime ?? '',
      'tripType': tripType,
      'packageType': packageType ?? '',
      'distance': distance,
      'ratePerKm': ratePerKm,
      'fastag': fastag,
      'extraCharges': extraCharges,
      'earnings': earnings,
      'description': sanitizeString(description),
      'timestamp': timestamp,
      'netTotal': netTotal,
      'endDateTime': endDateTime ?? '',
      'durationHours': durationHours,
      'bookingId': bookingId,
      'customerId': customerId,
    };
  }
}