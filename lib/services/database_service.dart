import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../models/vehicle.dart';
import '../models/driver.dart';
import '../models/trip.dart';

class DatabaseService with ChangeNotifier {
  Database? _database;
  Vehicle? _activeTripVehicle;
  Driver? _activeTripDriver;
  String? _activeTripCustomerPhone;
  String? _activeTripType;
  String? _activeTripCustomerName;
  String? _activeTripPickupArea;
  String? _activeTripDropArea;
  String? _activeTripStartDateTime;
  String? _activeTripPackageType;
  String? _activeTripBookingId;
  String? _activeTripCustomerId;

  DatabaseService() {
    _initDatabase();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    await _initDatabase();
    return _database!;
  }

  // Getters for active trip details
  String? get activeTripCustomerName => _activeTripCustomerName;
  String? get activeTripPickupArea => _activeTripPickupArea;
  String? get activeTripDropArea => _activeTripDropArea;
  String? get activeTripStartDateTime => _activeTripStartDateTime;
  String? get activeTripPackageType => _activeTripPackageType;
  String? get activeTripBookingId => _activeTripBookingId;
  String? get activeTripCustomerId => _activeTripCustomerId;

  Future<void> _initDatabase() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, 'TirupurCabs', 'tirupur_cabs.db');
      _database = await openDatabase(
        path,
        version: 9,
        onCreate: _createTables,
        onUpgrade: _upgradeDatabase,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          if (kDebugMode) {
            developer.log('Database configured with foreign keys');
          }
        },
      );
      if (kDebugMode) {
        developer.log('Database initialized at version 9, path: $path');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error initializing database: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> _createTables(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE vehicles (
          id TEXT PRIMARY KEY,
          name TEXT,
          regNumber TEXT,
          photoPath TEXT,
          totalKm REAL,
          totalTrips INTEGER,
          status TEXT,
          type TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE drivers (
          id TEXT PRIMARY KEY,
          name TEXT,
          phone TEXT,
          driverPhotoPath TEXT,
          licensePhotoPath TEXT,
          status TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE trips (
          id TEXT PRIMARY KEY,
          vehicleId TEXT,
          driverId TEXT,
          customerName TEXT,
          customerPhone TEXT,
          pickupArea TEXT,
          dropArea TEXT,
          startDateTime TEXT,
          tripType TEXT,
          packageType TEXT,
          distance REAL,
          ratePerKm REAL,
          fastag REAL,
          extraCharges REAL,
          earnings REAL,
          description TEXT,
          timestamp TEXT,
          netTotal REAL,
          endDateTime TEXT,
          durationHours REAL,
          bookingId TEXT,
          customerId TEXT,
          FOREIGN KEY (vehicleId) REFERENCES vehicles(id),
          FOREIGN KEY (driverId) REFERENCES drivers(id)
        )
      ''');
      if (kDebugMode) {
        developer.log('Tables created successfully');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error creating tables: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE trips ADD COLUMN ratePerKm REAL');
        await db.execute('ALTER TABLE trips ADD COLUMN fastag REAL');
        await db.execute('ALTER TABLE trips ADD COLUMN extraCharges REAL');
      }
      if (oldVersion < 3) {
        await db.execute('ALTER TABLE trips ADD COLUMN earnings REAL');
      }
      if (oldVersion < 4) {
        await db.execute('ALTER TABLE vehicles ADD COLUMN type TEXT');
      }
      if (oldVersion < 5) {
        await db.execute('ALTER TABLE trips ADD COLUMN netTotal REAL');
      }
      if (oldVersion < 6) {
        await db.execute('ALTER TABLE trips ADD COLUMN customerName TEXT');
        await db.execute('ALTER TABLE trips ADD COLUMN pickupArea TEXT');
        await db.execute('ALTER TABLE trips ADD COLUMN dropArea TEXT');
        await db.execute('ALTER TABLE trips ADD COLUMN startDateTime TEXT');
        await db.execute('ALTER TABLE trips ADD COLUMN packageType TEXT');
        await db.execute('ALTER TABLE trips ADD COLUMN endDateTime TEXT');
      }
      if (oldVersion < 7) {
        await db.execute('ALTER TABLE trips ADD COLUMN durationHours REAL');
      }
      if (oldVersion < 8) {
        await db.execute('ALTER TABLE trips ADD COLUMN bookingId TEXT');
        final trips = await db.query('trips');
        for (int i = 0; i < trips.length; i++) {
          final bookingId = 'WHITECABS${(i + 1).toString().padLeft(4, '0')}';
          await db.update(
            'trips',
            {'bookingId': bookingId},
            where: 'id = ?',
            whereArgs: [trips[i]['id']],
          );
        }
      }
      if (oldVersion < 9) {
        await db.execute('ALTER TABLE trips ADD COLUMN customerId TEXT');
        final trips = await db.query('trips');
        for (int i = 0; i < trips.length; i++) {
          final customerId = 'CUS${(i + 1).toString().padLeft(4, '0')}';
          await db.update(
            'trips',
            {'customerId': customerId},
            where: 'id = ?',
            whereArgs: [trips[i]['id']],
          );
        }
      }
      if (kDebugMode) {
        developer.log('Database upgraded from version $oldVersion to $newVersion');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error upgrading database: $e', stackTrace: stackTrace);
      }
      await db.execute('DROP TABLE IF EXISTS trips');
      await db.execute('DROP TABLE IF EXISTS vehicles');
      await db.execute('DROP TABLE IF EXISTS drivers');
      await _createTables(db, newVersion);
    }
  }

  Future<String> _generateBookingId(Database db) async {
    try {
      final result = await db.rawQuery(
        'SELECT bookingId FROM trips WHERE bookingId LIKE "WHITECABS%" ORDER BY CAST(SUBSTR(bookingId, 10) AS INTEGER) DESC LIMIT 1',
      );
      int nextNumber = 1;
      if (result.isNotEmpty) {
        final lastBookingId = result.first['bookingId'] as String;
        final numberPart = lastBookingId.replaceFirst('WHITECABS', '');
        nextNumber = int.parse(numberPart) + 1;
      }
      final bookingId = 'WHITECABS${nextNumber.toString().padLeft(4, '0')}';
      if (kDebugMode) {
        developer.log('Generated bookingId: $bookingId');
      }
      return bookingId;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error generating bookingId: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<String> _getOrGenerateCustomerId(String customerPhone) async {
    try {
      final db = await database;
      final existing = await db.query(
        'trips',
        where: 'customerPhone = ?',
        whereArgs: [customerPhone],
        columns: ['customerId'],
        limit: 1,
      );
      if (existing.isNotEmpty && existing.first['customerId'] != null) {
        final customerId = existing.first['customerId'] as String;
        if (kDebugMode) {
          developer.log('Found existing customerId: $customerId for phone: $customerPhone');
        }
        return customerId;
      }
      final result = await db.rawQuery(
        'SELECT customerId FROM trips WHERE customerId LIKE "CUS%" ORDER BY CAST(SUBSTR(customerId, 4) AS INTEGER) DESC LIMIT 1',
      );
      int nextNumber = 1;
      if (result.isNotEmpty) {
        final lastCustomerId = result.first['customerId'] as String;
        final numberPart = lastCustomerId.replaceFirst('CUS', '');
        nextNumber = int.parse(numberPart) + 1;
      }
      final customerId = 'CUS${nextNumber.toString().padLeft(4, '0')}';
      if (kDebugMode) {
        developer.log('Generated customerId: $customerId for phone: $customerPhone');
      }
      return customerId;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error generating customerId: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<bool> isEntityInActiveTrip({String? vehicleId, String? driverId}) async {
    try {
      final db = await database;
      if (vehicleId != null) {
        final vehicleMaps = await db.query(
          'vehicles',
          where: 'id = ? AND status = ?',
          whereArgs: [vehicleId, 'Assigned'],
        );
        if (vehicleMaps.isEmpty) return false;
        final tripMaps = await db.query(
          'trips',
          where: 'vehicleId = ? AND endDateTime IS NULL',
          whereArgs: [vehicleId],
          limit: 1,
        );
        if (kDebugMode && tripMaps.isNotEmpty) {
          developer.log('Active trip found for vehicleId=$vehicleId: ${tripMaps.first}');
        }
        return tripMaps.isNotEmpty;
      } else if (driverId != null) {
        final driverMaps = await db.query(
          'drivers',
          where: 'id = ? AND status = ?',
          whereArgs: [driverId, 'Assigned'],
        );
        if (driverMaps.isEmpty) return false;
        final tripMaps = await db.query(
          'trips',
          where: 'driverId = ? AND endDateTime IS NULL',
          whereArgs: [driverId],
          limit: 1,
        );
        if (kDebugMode && tripMaps.isNotEmpty) {
          developer.log('Active trip found for driverId=$driverId: ${tripMaps.first}');
        }
        return tripMaps.isNotEmpty;
      }
      return false;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in isEntityInActiveTrip: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<List<Vehicle>> getVehicles() async {
    try {
      final db = await database;
      final maps = await db.query('vehicles');
      return List.generate(maps.length, (i) => Vehicle.fromMap(maps[i]));
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getVehicles: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<int> getAvailableVehiclesCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery("SELECT COUNT(*) as count FROM vehicles WHERE status = 'Available'");
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getAvailableVehiclesCount: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    try {
      final db = await database;
      await db.insert('vehicles', vehicle.toMap());
      if (kDebugMode) {
        developer.log('Vehicle added: id=${vehicle.id}, name=${vehicle.name}');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in addVehicle: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    try {
      final db = await database;
      await db.update(
        'vehicles',
        vehicle.toMap(),
        where: 'id = ?',
        whereArgs: [vehicle.id],
      );
      if (kDebugMode) {
        developer.log('Vehicle updated: id=${vehicle.id}, name=${vehicle.name}');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in updateVehicle: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete(
          'trips',
          where: 'vehicleId = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'vehicles',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      if (kDebugMode) {
        developer.log('Vehicle deleted: id=$id');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in deleteVehicle: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<List<Driver>> getDrivers() async {
    try {
      final db = await database;
      final maps = await db.query('drivers');
      return List.generate(maps.length, (i) => Driver.fromMap(maps[i]));
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getDrivers: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<int> getAvailableDriversCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery("SELECT COUNT(*) as count FROM drivers WHERE status = 'Available'");
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getAvailableDriversCount: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<Driver?> getDriverById(String id) async {
    try {
      final db = await database;
      final maps = await db.query('drivers', where: 'id = ?', whereArgs: [id]);
      return maps.isNotEmpty ? Driver.fromMap(maps.first) : null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getDriverById: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> addDriver(Driver driver) async {
    try {
      final db = await database;
      await db.insert('drivers', driver.toMap());
      if (kDebugMode) {
        developer.log('Driver added: id=${driver.id}, name=${driver.name}');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in addDriver: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> updateDriver(Driver driver) async {
    try {
      final db = await database;
      await db.update(
        'drivers',
        driver.toMap(),
        where: 'id = ?',
        whereArgs: [driver.id],
      );
      if (kDebugMode) {
        developer.log('Driver updated: id=${driver.id}, name=${driver.name}');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in updateDriver: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> deleteDriver(String id) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete(
          'trips',
          where: 'driverId = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'drivers',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      if (kDebugMode) {
        developer.log('Driver deleted: id=$id');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in deleteDriver: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<List<Trip>> getTrips() async {
    try {
      final db = await database;
      final maps = await db.query('trips');
      return List.generate(maps.length, (i) => Trip.fromMap(maps[i]));
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getTrips: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<Trip?> getTripByDriverId(String driverId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'trips',
        where: 'driverId = ? AND endDateTime IS NULL',
        whereArgs: [driverId],
        limit: 1,
      );
      if (kDebugMode) {
        developer.log('getTripByDriverId: driverId=$driverId, found ${maps.length} trips');
        if (maps.isNotEmpty) developer.log('Trip details: ${maps.first}');
      }
      return maps.isNotEmpty ? Trip.fromMap(maps.first) : null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getTripByDriverId: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<Trip?> getTripByVehicleId(String vehicleId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'trips',
        where: 'vehicleId = ? AND endDateTime IS NULL',
        whereArgs: [vehicleId],
        limit: 1,
      );
      if (kDebugMode) {
        developer.log('getTripByVehicleId: vehicleId=$vehicleId, found ${maps.length} trips');
        if (maps.isNotEmpty) developer.log('Trip details: ${maps.first}');
      }
      return maps.isNotEmpty ? Trip.fromMap(maps.first) : null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getTripByVehicleId: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<Trip?> getTripByBookingId(String bookingId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'trips',
        where: 'bookingId = ?',
        whereArgs: [bookingId],
        limit: 1,
      );
      if (kDebugMode) {
        developer.log('getTripByBookingId: bookingId=$bookingId, found ${maps.length} trips');
        if (maps.isNotEmpty) developer.log('Trip details: ${maps.first}');
      }
      return maps.isNotEmpty ? Trip.fromMap(maps.first) : null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getTripByBookingId: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<List<Trip>> getDriverTrips(String driverId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'trips',
        where: 'driverId = ?',
        whereArgs: [driverId],
      );
      if (kDebugMode) {
        developer.log('getDriverTrips: driverId=$driverId, found ${maps.length} trips');
      }
      return List.generate(maps.length, (i) => Trip.fromMap(maps[i]));
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getDriverTrips: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<double> getDriverTotalKm(String driverId) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT SUM(COALESCE(distance, 0)) as total FROM trips WHERE driverId = ?',
        [driverId],
      );
      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getDriverTotalKm: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<int> getDriverTotalTrips(String driverId) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM trips WHERE driverId = ?',
        [driverId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getDriverTotalTrips: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<double> getDriverTotalEarnings(String driverId) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT SUM(COALESCE(netTotal, 0)) as total FROM trips WHERE driverId = ?',
        [driverId],
      );
      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getDriverTotalEarnings: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<double> getVehicleTotalEarnings(String vehicleId) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT SUM(COALESCE(netTotal, 0)) as total FROM trips WHERE vehicleId = ?',
        [vehicleId],
      );
      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getVehicleTotalEarnings: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<int> getCustomerCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(DISTINCT COALESCE(customerPhone, \'\')) as count FROM trips');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getCustomerCount: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<double> getTotalIncome() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT SUM(COALESCE(netTotal, 0)) as total FROM trips');
      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in getTotalIncome: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> assignTrip(
    String vehicleId,
    String driverId,
    String customerName,
    String customerPhone,
    String pickupArea,
    String dropArea,
    String startDateTime,
    String tripType,
    String packageType,
  ) async {
    try {
      final db = await database;
      final isVehicleAssigned = await isEntityInActiveTrip(vehicleId: vehicleId);
      final isDriverAssigned = await isEntityInActiveTrip(driverId: driverId);
      if (isVehicleAssigned) {
        throw Exception('Vehicle is already assigned to an active trip: id=$vehicleId');
      }
      if (isDriverAssigned) {
        throw Exception('Driver is already assigned to an active trip: id=$driverId');
      }

      final vehicleMaps = await db.query('vehicles', where: 'id = ?', whereArgs: [vehicleId]);
      final driverMaps = await db.query('drivers', where: 'id = ?', whereArgs: [driverId]);

      if (vehicleMaps.isEmpty) throw Exception('Vehicle not found: id=$vehicleId');
      if (driverMaps.isEmpty) throw Exception('Driver not found: id=$driverId');

      final bookingId = await _generateBookingId(db);
      final customerId = await _getOrGenerateCustomerId(customerPhone);

      await db.transaction((txn) async {
        await txn.insert(
          'trips',
          {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'vehicleId': vehicleId,
            'driverId': driverId,
            'customerName': customerName,
            'customerPhone': customerPhone,
            'pickupArea': pickupArea,
            'dropArea': dropArea,
            'startDateTime': startDateTime,
            'tripType': tripType,
            'packageType': packageType,
            'distance': 0.0,
            'ratePerKm': 0.0,
            'fastag': 0.0,
            'extraCharges': 0.0,
            'earnings': 0.0,
            'description': '',
            'timestamp': DateTime.now().toIso8601String(),
            'netTotal': 0.0,
            'endDateTime': null,
            'durationHours': 0.0,
            'bookingId': bookingId,
            'customerId': customerId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await txn.update(
          'vehicles',
          {'status': 'Assigned'},
          where: 'id = ?',
          whereArgs: [vehicleId],
        );
        await txn.update(
          'drivers',
          {'status': 'Assigned'},
          where: 'id = ?',
          whereArgs: [driverId],
        );
      });

      _activeTripVehicle = Vehicle.fromMap(vehicleMaps.first);
      _activeTripDriver = Driver.fromMap(driverMaps.first);
      _activeTripCustomerName = customerName;
      _activeTripCustomerPhone = customerPhone;
      _activeTripPickupArea = pickupArea;
      _activeTripDropArea = dropArea;
      _activeTripStartDateTime = startDateTime;
      _activeTripType = tripType;
      _activeTripPackageType = packageType;
      _activeTripBookingId = bookingId;
      _activeTripCustomerId = customerId;

      if (kDebugMode) {
        developer.log('Assigned trip: vehicleId=$vehicleId, driverId=$driverId, '
            'driver=${_activeTripDriver?.name ?? 'N/A'}, bookingId=$bookingId, customerId=$customerId, '
            'customerName=$customerName, tripType=$tripType');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in assignTrip: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> reassignTrip(
    String originalVehicleId,
    String newVehicleId,
    String driverId,
    String customerName,
    String customerPhone,
    String pickupArea,
    String dropArea,
    String startDateTime,
    String tripType,
    String packageType,
  ) async {
    try {
      final db = await database;
      final currentTrip = await getTripByVehicleId(originalVehicleId);
      if (kDebugMode) {
        developer.log('Reassigning trip: originalVehicleId=$originalVehicleId, newVehicleId=$newVehicleId, '
            'driverId=$driverId, customerPhone=$customerPhone, tripType=$tripType');
        developer.log('Current trip: ${currentTrip?.toMap() ?? 'none'}');
      }
      if (currentTrip == null) {
        throw Exception('No active trip found for original vehicleId=$originalVehicleId');
      }

      Map<String, dynamic>? newVehicleMap;
      if (newVehicleId != originalVehicleId) {
        final newVehicleMaps = await db.query('vehicles', where: 'id = ?', whereArgs: [newVehicleId]);
        if (newVehicleMaps.isEmpty) {
          throw Exception('New vehicle not found: id=$newVehicleId');
        }
        final isAssigned = await isEntityInActiveTrip(vehicleId: newVehicleId);
        if (isAssigned) {
          throw Exception('New vehicle is already assigned to another active trip: id=$newVehicleId');
        }
        newVehicleMap = newVehicleMaps.first;
      } else {
        final vehicleMaps = await db.query('vehicles', where: 'id = ?', whereArgs: [newVehicleId]);
        if (vehicleMaps.isEmpty) {
          throw Exception('Vehicle not found: id=$newVehicleId');
        }
        newVehicleMap = vehicleMaps.first;
      }

      final driverMaps = await db.query('drivers', where: 'id = ?', whereArgs: [driverId]);
      if (driverMaps.isEmpty) {
        throw Exception('Driver not found: id=$driverId');
      }
      if (driverId != currentTrip.driverId) {
        final isDriverAssigned = await isEntityInActiveTrip(driverId: driverId);
        if (isDriverAssigned) {
          throw Exception('New driver is already assigned to another active trip: id=$driverId');
        }
      }

      final customerId = await _getOrGenerateCustomerId(customerPhone);

      await db.transaction((txn) async {
        await txn.update(
          'trips',
          {
            'vehicleId': newVehicleId,
            'driverId': driverId,
            'customerName': customerName,
            'customerPhone': customerPhone,
            'pickupArea': pickupArea,
            'dropArea': dropArea,
            'startDateTime': startDateTime,
            'tripType': tripType,
            'packageType': packageType,
            'timestamp': DateTime.now().toIso8601String(),
            'bookingId': currentTrip.bookingId,
            'customerId': customerId,
          },
          where: 'id = ?',
          whereArgs: [currentTrip.id],
        );

        if (currentTrip.vehicleId != newVehicleId) {
          await txn.update(
            'vehicles',
            {'status': 'Available'},
            where: 'id = ?',
            whereArgs: [currentTrip.vehicleId],
          );
          await txn.update(
            'vehicles',
            {'status': 'Assigned'},
            where: 'id = ?',
            whereArgs: [newVehicleId],
          );
        }

        if (currentTrip.driverId != driverId) {
          await txn.update(
            'drivers',
            {'status': 'Available'},
            where: 'id = ?',
            whereArgs: [currentTrip.driverId],
          );
          await txn.update(
            'drivers',
            {'status': 'Assigned'},
            where: 'id = ?',
            whereArgs: [driverId],
          );
        }
      });

      _activeTripVehicle = Vehicle.fromMap(newVehicleMap);
      _activeTripDriver = Driver.fromMap(driverMaps.first);
      _activeTripCustomerName = customerName;
      _activeTripCustomerPhone = customerPhone;
      _activeTripPickupArea = pickupArea;
      _activeTripDropArea = dropArea;
      _activeTripStartDateTime = startDateTime;
      _activeTripType = tripType;
      _activeTripPackageType = packageType;
      _activeTripBookingId = currentTrip.bookingId;
      _activeTripCustomerId = customerId;

      if (kDebugMode) {
        developer.log('Reassignment successful: vehicleId=$newVehicleId, driverId=$driverId, '
            'driver=${_activeTripDriver?.name ?? 'N/A'}, bookingId=${_activeTripBookingId}, '
            'customerId=${_activeTripCustomerId}');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in reassignTrip: $e', stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> endTrip(
    String vehicleId,
    String driverId,
    double distance,
    double ratePerKm,
    double fastag,
    double extraCharges,
    double earnings,
    String description,
    double netTotal,
    String endDateTime,
    double durationHours,
  ) async {
    bool apiSuccess = false;
    String? bookingId;
    try {
      final db = await database;
      final vehicleMaps = await db.query('vehicles', where: 'id = ?', whereArgs: [vehicleId]);
      if (vehicleMaps.isEmpty) throw Exception('Vehicle not found: id=$vehicleId');

      final vehicle = Vehicle.fromMap(vehicleMaps.first);
      final updatedVehicle = Vehicle(
        id: vehicle.id,
        name: vehicle.name,
        regNumber: vehicle.regNumber,
        photoPath: vehicle.photoPath,
        totalKm: vehicle.totalKm + distance,
        totalTrips: vehicle.totalTrips + 1,
        status: 'Available',
        type: vehicle.type,
      );

      final driverMaps = await db.query('drivers', where: 'id = ?', whereArgs: [driverId]);
      if (driverMaps.isEmpty) throw Exception('Driver not found: id=$driverId');

      final tripMaps = await db.query(
        'trips',
        where: 'vehicleId = ? AND driverId = ? AND endDateTime IS NULL',
        whereArgs: [vehicleId, driverId],
        limit: 1,
      );
      if (tripMaps.isEmpty) {
        if (kDebugMode) {
          developer.log('No active trip found for vehicleId=$vehicleId, driverId=$driverId');
          final allActiveTrips = await db.query('trips', where: 'endDateTime IS NULL');
          developer.log('All active trips: $allActiveTrips');
        }
        throw Exception('No active trip found for vehicleId=$vehicleId and driverId=$driverId');
      }

      final trip = Trip.fromMap(tripMaps.first);
      bookingId = trip.bookingId;
      if (bookingId.isEmpty || !RegExp(r'^WHITECABS\d{4}$').hasMatch(bookingId)) {
        throw Exception('Invalid booking ID: $bookingId');
      }

      final tripData = Trip(
        id: trip.id,
        vehicleId: vehicleId,
        driverId: driverId,
        customerName: trip.customerName,
        customerPhone: trip.customerPhone,
        pickupArea: trip.pickupArea,
        dropArea: trip.dropArea,
        startDateTime: trip.startDateTime,
        tripType: trip.tripType,
        packageType: trip.packageType,
        distance: distance,
        ratePerKm: ratePerKm,
        fastag: fastag,
        extraCharges: extraCharges,
        earnings: earnings,
        description: description,
        timestamp: DateTime.now().toIso8601String(),
        netTotal: netTotal,
        endDateTime: endDateTime,
        durationHours: durationHours,
        bookingId: bookingId,
        customerId: trip.customerId,
      );

      await db.transaction((txn) async {
        await txn.update(
          'vehicles',
          updatedVehicle.toMap(),
          where: 'id = ?',
          whereArgs: [vehicleId],
        );

        await txn.update(
          'drivers',
          {'status': 'Available'},
          where: 'id = ?',
          whereArgs: [driverId],
        );

        await txn.update(
          'trips',
          {
            'distance': distance,
            'ratePerKm': ratePerKm,
            'fastag': fastag,
            'extraCharges': extraCharges,
            'earnings': earnings,
            'description': description,
            'timestamp': DateTime.now().toIso8601String(),
            'netTotal': netTotal,
            'endDateTime': endDateTime,
            'durationHours': durationHours,
          },
          where: 'id = ?',
          whereArgs: [trip.id],
        );
      });

      apiSuccess = await _sendTripToApi(tripData);

      _activeTripVehicle = null;
      _activeTripDriver = null;
      _activeTripCustomerName = null;
      _activeTripCustomerPhone = null;
      _activeTripPickupArea = null;
      _activeTripDropArea = null;
      _activeTripStartDateTime = null;
      _activeTripType = null;
      _activeTripPackageType = null;
      _activeTripBookingId = null;
      _activeTripCustomerId = null;

      if (kDebugMode) {
        developer.log('Ended trip: vehicleId=$vehicleId, driverId=$driverId, distance=$distance, '
            'totalKm=${updatedVehicle.totalKm}, totalTrips=${updatedVehicle.totalTrips}, '
            'ratePerKm=$ratePerKm, fastag=$fastag, extraCharges=$extraCharges, '
            'earnings=$earnings, netTotal=$netTotal, endDateTime=$endDateTime, '
            'durationHours=$durationHours, bookingId=$bookingId, customerId=${trip.customerId}, '
            'apiSuccess=$apiSuccess');
      }
      notifyListeners();
      return {'bookingId': bookingId, 'apiSuccess': apiSuccess};
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error in endTrip: vehicleId=$vehicleId, driverId=$driverId, error=$e', stackTrace: stackTrace);
      }
      return {'bookingId': bookingId ?? 'N/A', 'apiSuccess': false};
    }
  }

  Future<bool> _sendTripToApi(Trip trip) async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final url = Uri.parse('https://www.whitecabs.com.in/trip.php');
        final tripMap = trip.toMap();
        final jsonBody = jsonEncode(tripMap);
        if (kDebugMode) {
          developer.log('Attempt $attempt - Sending trip to API: bookingId=${trip.bookingId}, JSON=$jsonBody');
        }
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonBody,
        );

        if (kDebugMode) {
          developer.log('Attempt $attempt - API Response: status=${response.statusCode}, body=${response.body}');
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] != 'success') {
            throw Exception('API error: ${data['message'] ?? 'Failed to save trip'}');
          }
          if (kDebugMode) {
            developer.log('Trip saved to API: id=${trip.id}, bookingId=${trip.bookingId}');
          }
          return true;
        } else {
          throw Exception('Failed to save trip to API: ${response.statusCode} - ${response.body}');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          developer.log('Attempt $attempt - Error sending trip to API: bookingId=${trip.bookingId}, error=$e', stackTrace: stackTrace);
        }
        if (attempt == maxRetries) return false;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return false;
  }

  bool hasActiveTrip() => _activeTripVehicle != null && _activeTripDriver != null;

  Vehicle getActiveTripVehicle() => _activeTripVehicle ?? (throw Exception('No active trip vehicle'));

  Driver getActiveTripDriver() => _activeTripDriver ?? (throw Exception('No active trip driver'));

  String getActiveTripCustomerPhone() => _activeTripCustomerPhone ?? (throw Exception('No active trip customer'));

  String getActiveTripType() => _activeTripType ?? (throw Exception('No active trip type'));

  String getActiveTripBookingId() => _activeTripBookingId ?? (throw Exception('No active trip booking ID'));

  String getActiveTripCustomerId() => _activeTripCustomerId ?? (throw Exception('No active trip customer ID'));
}