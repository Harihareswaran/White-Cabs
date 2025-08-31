import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle.dart';
import '../../services/database_service.dart';
import '../../widgets/vehicle_card.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_details_screen.dart';
import 'edit_vehicle_screen.dart';

class VehicleListScreen extends StatelessWidget {
  const VehicleListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vehicle Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 2,
      ),
      body: Container(
        color: Colors.grey[100],
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 1,
              ),
              child: const Text('Add Vehicle', style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<DatabaseService>(
                builder: (context, dbService, child) {
                  return FutureBuilder<List<Vehicle>>(
                    future: dbService.getVehicles(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text('Error loading vehicles'));
                      }
                      final vehicles = snapshot.data ?? [];
                      return ListView.builder(
                        itemCount: vehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = vehicles[index];
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
                            onEdit: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditVehicleScreen(vehicle: vehicle),
                                ),
                              );
                            },
                            onDelete: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Delete'),
                                  content: Text('Do you want to delete ${vehicle.name}?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Yes'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;

                              final isInTrip = await dbService.isEntityInActiveTrip(vehicleId: vehicle.id);
                              if (isInTrip) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vehicle is in trip, cannot delete')),
                                );
                                return;
                              }

                              try {
                                await dbService.deleteVehicle(vehicle.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vehicle deleted')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error deleting vehicle: $e')),
                                );
                              }
                            },
                            editIcon: const Icon(Icons.edit, color: Colors.blue), // Added blue edit icon
                            deleteIcon: const Icon(Icons.delete, color: Colors.red), // Added red delete icon
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}