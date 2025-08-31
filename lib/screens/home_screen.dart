import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../models/driver.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import '../widgets/vehicle_card.dart';
import 'trip/assign_driver_screen.dart';
import 'trip/end_trip_screen.dart';
import 'trip/trip_assignment_screen.dart';
import 'vehicle/vehicle_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseService>(
      builder: (context, dbService, child) {
        return FutureBuilder(
          future: Future.wait([
            dbService.getVehicles().catchError((e) => throw Exception('getVehicles failed: $e')),
            dbService.getDrivers().catchError((e) => throw Exception('getDrivers failed: $e')),
            dbService.getTrips().catchError((e) => throw Exception('getTrips failed: $e')),
            dbService.getCustomerCount().catchError((e) => throw Exception('getCustomerCount failed: $e')),
            dbService.getTotalIncome().catchError((e) => throw Exception('getTotalIncome failed: $e')),
            dbService.getAvailableVehiclesCount().catchError((e) => throw Exception('getAvailableVehiclesCount failed: $e')),
            dbService.getAvailableDriversCount().catchError((e) => throw Exception('getAvailableDriversCount failed: $e')),
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              debugPrint('Dashboard error: ${snapshot.error}');
              return Center(child: Text('Error loading dashboard: ${snapshot.error}'));
            }
            final vehicles = snapshot.data![0] as List<Vehicle>;
            final drivers = snapshot.data![1] as List<Driver>;
            final trips = snapshot.data![2] as List<Trip>;
            final customerCount = snapshot.data![3] as int;
            final totalIncome = snapshot.data![4] as double;
            final availableVehiclesCount = snapshot.data![5] as int;
            final availableDriversCount = snapshot.data![6] as int;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 1.5,
                        children: [
                          _buildDashboardTile('Vehicles', vehicles.length.toString(), Icons.directions_car),
                          _buildDashboardTile('Drivers', drivers.length.toString(), Icons.person),
                          _buildDashboardTile('Available\nVehicle', availableVehiclesCount.toString(), Icons.directions_car_outlined),
                          _buildDashboardTile('Available\nDriver', availableDriversCount.toString(), Icons.person_outline),
                          _buildDashboardTile('Trips', trips.length.toString(), Icons.route),
                          _buildDashboardTile('Income', '₹${totalIncome.toStringAsFixed(2)}', Icons.currency_rupee),
                          _buildDashboardTile('Customer', customerCount.toString(), Icons.people),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Vehicles', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  vehicles.isEmpty
                      ? const Center(child: Text('No vehicles available'))
                      : FutureBuilder<List<Widget>>(
                          future: Future.wait(vehicles.map((vehicle) async {
                            final trip = await dbService.getTripByVehicleId(vehicle.id).catchError((e) {
                              debugPrint('Error fetching trip for vehicle ${vehicle.id}: $e');
                              return null;
                            });
                            final driver = trip != null
                                ? await dbService.getDriverById(trip.driverId).catchError((e) {
                                    debugPrint('Error fetching driver for trip ${trip.id}: $e');
                                    return null;
                                  })
                                : null;
                            return VehicleCard(
                              vehicle: vehicle,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VehicleDetailsScreen(vehicle: vehicle),
                                  ),
                                );
                              },
                              onEdit: null,
                              onDelete: null,
                              trailing: vehicle.status == 'Available'
                                  ? Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => AssignDriverScreen(vehicle: vehicle),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[700],
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        ),
                                        child: const Text(
                                          'Assign',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                    )
                                  : trip != null && driver != null
                                      ? Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ElevatedButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => TripAssignmentScreen(
                                                        vehicle: vehicle,
                                                        driver: driver,
                                                        isReassign: true,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue[700],
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                ),
                                                child: const Text(
                                                  'Edit Trip',
                                                  style: TextStyle(color: Colors.white, fontSize: 10),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              ElevatedButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => EndTripScreen(
                                                        vehicle: vehicle,
                                                        driver: driver,
                                                        customerPhone: trip.customerPhone,
                                                        tripType: trip.tripType,
                                                        customerName: trip.customerName ?? '',
                                                        pickupArea: trip.pickupArea ?? '',
                                                        dropArea: trip.dropArea ?? '',
                                                        startDateTime: trip.startDateTime ?? DateTime.now().toIso8601String(),
                                                        packageType: trip.packageType ?? 'Local',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red[700],
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                ),
                                                child: const Text(
                                                  'End Trip',
                                                  style: TextStyle(color: Colors.white, fontSize: 10),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                            );
                          }).toList()),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              debugPrint('Vehicle cards error: ${snapshot.error}');
                              return Center(child: Text('Error loading vehicle cards: ${snapshot.error}'));
                            }
                            return ListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: snapshot.data!,
                            );
                          },
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardTile(String title, String value, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Colors.black87),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ],
    );
  }
}