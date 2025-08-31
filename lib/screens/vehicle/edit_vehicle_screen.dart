import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';

class EditVehicleScreen extends StatefulWidget {
  final Vehicle vehicle;

  const EditVehicleScreen({Key? key, required this.vehicle}) : super(key: key);

  @override
  _EditVehicleScreenState createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _regNumberController;
  late String _status;
  late String _type;
  XFile? _image;
  String? _photoPath;

  final List<String> _vehicleTypes = [
    'Hatchback',
    'Sedan',
    'MPV',
    'SUV',
    'Compact SUV',
    'Pickup Truck',
    'Electric Vehicle (EV)',
    'Luxury Car',
    'Utility',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.vehicle.name);
    _regNumberController = TextEditingController(text: widget.vehicle.regNumber);
    _status = widget.vehicle.status;
    _type = widget.vehicle.type.isEmpty ? _vehicleTypes.first : widget.vehicle.type;
    _photoPath = widget.vehicle.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
        ],
      ),
    );
    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = pickedFile;
        });
      }
    }
  }

  Future<void> _saveVehicle(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      String? newPhotoPath = _photoPath;
      if (_image != null) {
        newPhotoPath = await storageService.saveImage(File(_image!.path), 'vehicles/${widget.vehicle.id}.jpg');
      }

      final updatedVehicle = Vehicle(
        id: widget.vehicle.id,
        name: _nameController.text,
        regNumber: _regNumberController.text,
        photoPath: newPhotoPath,
        totalKm: widget.vehicle.totalKm,
        totalTrips: widget.vehicle.totalTrips,
        status: _status,
        type: _type,
      );

      await dbService.updateVehicle(updatedVehicle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle updated')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Vehicle', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue[700],
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vehicle Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                    const Divider(color: Colors.grey, thickness: 1, height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Vehicle Name'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter vehicle name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _regNumberController,
                      decoration: const InputDecoration(labelText: 'Registration Number'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter registration number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(labelText: 'Vehicle Type'),
                      items: _vehicleTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _type = value!;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a vehicle type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Status', style: TextStyle(fontSize: 16, color: Colors.blue[700])),
                    Text(_status == 'Assigned' ? 'Assigned' : _status, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    Text('Photo', style: TextStyle(fontSize: 16, color: Colors.blue[700])),
                    Row(
                      children: [
                        _image != null
                            ? Image.file(File(_image!.path), height: 100, fit: BoxFit.cover)
                            : _photoPath != null && _photoPath!.isNotEmpty
                                ? Image.file(File(_photoPath!), height: 100, fit: BoxFit.cover)
                                : const Text('No image selected', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _pickImage,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('Pick Photo', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () => _saveVehicle(context),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('Save', style: TextStyle(fontSize: 16)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
                          child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}