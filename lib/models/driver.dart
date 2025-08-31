class Driver {
  final String id;
  final String name;
  final String phone;
  final String driverPhotoPath;
  final String licensePhotoPath;
  final String status;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.driverPhotoPath,
    required this.licensePhotoPath,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'driverPhotoPath': driverPhotoPath,
      'licensePhotoPath': licensePhotoPath,
      'status': status,
    };
  }

  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      driverPhotoPath: map['driverPhotoPath'],
      licensePhotoPath: map['licensePhotoPath'],
      status: map['status'],
    );
  }
}