import 'dart:io';
import 'package:flutter/material.dart';
import '../models/vehicle.dart';

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget? trailing;
  final Icon? editIcon; // Added parameter for edit icon
  final Icon? deleteIcon; // Added parameter for delete icon

  const VehicleCard({
    Key? key,
    required this.vehicle,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.trailing,
    this.editIcon,
    this.deleteIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8.0),
        leading: vehicle.photoPath != null && vehicle.photoPath!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(vehicle.photoPath!),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              )
            : const Icon(Icons.directions_car, size: 50),
        title: Text(
          vehicle.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Reg: ${vehicle.regNumber}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              'Status: ${vehicle.status}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: trailing ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  IconButton(
                    icon: editIcon ?? const Icon(Icons.edit, color: Colors.blue), // Use provided or blue default
                    onPressed: onEdit,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: deleteIcon ?? const Icon(Icons.delete, color: Colors.red), // Use provided or red default
                    onPressed: onDelete,
                  ),
              ],
            ),
        onTap: onTap,
      ),
    );
  }
}