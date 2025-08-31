import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle.dart';
import '../../models/driver.dart';
import '../../services/database_service.dart';
import 'trip_assignment_screen.dart';

class AssignDriverScreen extends StatelessWidget {
  final Vehicle vehicle;

  const AssignDriverScreen({Key? key, required this.vehicle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Driver'),
        backgroundColor: Colors.blue[700],
      ),
      body: FutureBuilder<List<Driver>>(
        future: dbService.getDrivers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading drivers'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No available drivers'));
          }

          final availableDrivers = snapshot.data!.where((driver) => driver.status == 'Available').toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: availableDrivers.length,
            itemBuilder: (context, index) {
              final driver = availableDrivers[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: driver.driverPhotoPath.isNotEmpty
                      ? CircleAvatar(
                          backgroundImage: FileImage(File(driver.driverPhotoPath)),
                          radius: 20,
                        )
                      : const Icon(Icons.person, size: 40),
                  title: Text(driver.name),
                  subtitle: Text(driver.phone),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TripAssignmentScreen(
                          vehicle: vehicle,
                          driver: driver,
                          isReassign: false,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}