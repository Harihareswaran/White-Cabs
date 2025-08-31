import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/driver.dart';
import '../../services/database_service.dart';
import '../fullscreen_image.dart';

class DriverDetailsScreen extends StatelessWidget {
  final Driver driver;

  const DriverDetailsScreen({Key? key, required this.driver}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          driver.name,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait([
            dbService.getDriverTotalKm(driver.id).catchError((e) {
              debugPrint('Error fetching total km: $e');
              return 0.0;
            }),
            dbService.getDriverTotalTrips(driver.id).catchError((e) {
              debugPrint('Error fetching total trips: $e');
              return 0;
            }),
            dbService.getDriverTotalEarnings(driver.id).catchError((e) {
              debugPrint('Error fetching total earnings: $e');
              return 0.0;
            }),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading driver details: ${snapshot.error}'));
            }

            final totalKm = snapshot.data?[0] as double? ?? 0.0;
            final totalTrips = snapshot.data?[1] as int? ?? 0;
            final totalEarnings = snapshot.data?[2] as double? ?? 0.0;

            return Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: driver.driverPhotoPath.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullscreenImage(imagePath: driver.driverPhotoPath),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(driver.driverPhotoPath),
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : const Text(
                              'No driver image available',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Driver Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const Divider(color: Colors.grey, thickness: 1, height: 20),
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.blue[700]),
                      title: Text('Name: ${driver.name}', style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      leading: Icon(Icons.phone, color: Colors.blue[700]),
                      title: Text('Phone: ${driver.phone}', style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      leading: Icon(Icons.directions_car, color: Colors.blue[700]),
                      title: Text('Total KM: ${totalKm.toStringAsFixed(2)} km', style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      leading: Icon(Icons.route, color: Colors.blue[700]),
                      title: Text('Total Trips: $totalTrips', style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      leading: Icon(Icons.info, color: Colors.blue[700]),
                      title: Text('Status: ${driver.status}', style: const TextStyle(fontSize: 16)),
                    ),
                    ListTile(
                      leading: Icon(Icons.currency_rupee, color: Colors.blue[700]),
                      title: Text('Total Earnings: ₹${totalEarnings.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                    ),
                    if (driver.licensePhotoPath.isNotEmpty)
                      ListTile(
                        leading: Icon(Icons.badge, color: Colors.blue[700]),
                        title: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullscreenImage(imagePath: driver.licensePhotoPath),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('View License', style: TextStyle(fontSize: 14)),
                        ),
                      )
                    else
                      ListTile(
                        leading: Icon(Icons.badge, color: Colors.grey),
                        title: const Text('No license image available', style: TextStyle(fontSize: 16, color: Colors.grey)),
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