import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/driver.dart';
import '../../services/database_service.dart';
import '../../widgets/driver_card.dart';
import 'add_driver_screen.dart';
import 'edit_driver_screen.dart';
import 'driver_details_screen.dart';

class DriverListScreen extends StatelessWidget {
  const DriverListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context, listen: true); // listens to changes

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Driver Management',
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
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddDriverScreen()),
                );
                // No need to manually refresh; notifyListeners will handle it
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 1,
              ),
              child: const Text('Add Driver', style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Driver>>(
                key: ValueKey(dbService), // rebuilds whenever notifyListeners is called
                future: dbService.getDrivers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading drivers'));
                  }
                  final drivers = snapshot.data ?? [];
                  return ListView.builder(
                    itemCount: drivers.length,
                    itemBuilder: (context, index) {
                      final driver = drivers[index];
                      return DriverCard(
                        driver: driver,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DriverDetailsScreen(driver: driver),
                            ),
                          );
                        },
                        onEdit: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditDriverScreen(driver: driver),
                            ),
                          );
                          // No manual refresh needed
                        },
                        onDelete: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Delete'),
                              content: Text('Do you want to delete ${driver.name}?'),
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

                          final isInTrip = await dbService.isEntityInActiveTrip(driverId: driver.id);
                          if (isInTrip) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Driver is in trip, cannot delete')),
                            );
                            return;
                          }

                          try {
                            await dbService.deleteDriver(driver.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Driver deleted')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error deleting driver: $e')),
                            );
                          }
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