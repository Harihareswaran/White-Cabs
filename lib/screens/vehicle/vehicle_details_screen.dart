import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle.dart';
import '../../services/database_service.dart';
import '../fullscreen_image.dart';

class VehicleDetailsScreen extends StatelessWidget {
  final Vehicle vehicle;

  const VehicleDetailsScreen({Key? key, required this.vehicle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          vehicle.name,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<double>(
          future: dbService.getVehicleTotalEarnings(vehicle.id).catchError((e) {
            debugPrint('Error fetching total earnings: $e');
            return 0.0;
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading vehicle details: ${snapshot.error}'));
            }
            final totalEarnings = snapshot.data ?? 0.0;

            return Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: vehicle.photoPath != null && vehicle.photoPath!.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullscreenImage(imagePath: vehicle.photoPath!),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(vehicle.photoPath!),
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : const Text(
                              'No vehicle image available',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Vehicle Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const Divider(color: Colors.grey, thickness: 1, height: 20),
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.blue[700]),
                      title: Text('Name: ${vehicle.name}', style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      leading: Icon(Icons.confirmation_number, color: Colors.blue[700]),
                      title: Text('Registration Number: ${vehicle.regNumber}', style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      leading: Icon(Icons.directions_car, color: Colors.blue[700]),
                      title: Text('Total KM: ${vehicle.totalKm.toStringAsFixed(2)} km', style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      leading: Icon(Icons.route, color: Colors.blue[700]),
                      title: Text('Total Trips: ${vehicle.totalTrips}', style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      leading: Icon(Icons.info, color: Colors.blue[700]),
                      title: Text('Status: ${vehicle.status}', style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      leading: Icon(Icons.currency_rupee, color: Colors.blue[700]),
                      title: Text('Total Earnings: ₹${totalEarnings.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}