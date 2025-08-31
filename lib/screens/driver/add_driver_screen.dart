import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/driver.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({Key? key}) : super(key: key);

  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _phone = '';
  File? _driverPhoto;
  File? _licensePhoto;
  final _phoneController = TextEditingController(); // Only 10 digits

  Future<void> _pickImage(bool isDriverPhoto) async {
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
          if (isDriverPhoto) {
            _driverPhoto = File(pickedFile.path);
          } else {
            _licensePhoto = File(pickedFile.path);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Driver', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                    Text('Add Driver Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                    const Divider(color: Colors.grey, thickness: 1, height: 20),

                    // Driver Name
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Driver Name'),
                      validator: (value) => value!.isEmpty ? 'Enter driver name' : null,
                      onSaved: (value) => _name = value!,
                    ),
                    const SizedBox(height: 16),

                    // Clean Phone Field
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixText: '+91 ',
                        prefixStyle: TextStyle(color: Colors.black, fontSize: 16),
                        hintText: 'Enter 10-digit mobile number',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter phone number';
                        if (value.length != 10) return 'Enter exactly 10 digits';
                        return null;
                      },
                      onSaved: (value) => _phone = '+91$value',
                    ),

                    const SizedBox(height: 16),
                    Text('Photos', style: TextStyle(fontSize: 16, color: Colors.blue[700])),

                    // Driver Photo
                    const SizedBox(height: 8),
                    Text('Driver Photo', style: TextStyle(fontSize: 14, color: Colors.blue[700])),
                    Row(
                      children: [
                        _driverPhoto != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(_driverPhoto!, height: 100, fit: BoxFit.cover),
                              )
                            : const Text('No driver photo', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => _pickImage(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Pick Photo', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // License Photo
                    Text('License Photo', style: TextStyle(fontSize: 14, color: Colors.blue[700])),
                    Row(
                      children: [
                        _licensePhoto != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(_licensePhoto!, height: 100, fit: BoxFit.cover),
                              )
                            : const Text('No license photo', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => _pickImage(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Pick Photo', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          if (_driverPhoto == null || _licensePhoto == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select both photos')),
                            );
                            return;
                          }
                          _formKey.currentState!.save();
                          final driverPhotoPath = await storageService.saveImage(_driverPhoto!, 'drivers');
                          final licensePhotoPath = await storageService.saveImage(_licensePhoto!, 'licenses');
                          final driver = Driver(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: _name,
                            phone: _phone,
                            driverPhotoPath: driverPhotoPath,
                            licensePhotoPath: licensePhotoPath,
                            status: 'Available',
                          );
                          await dbService.addDriver(driver);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Driver added')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Submit', style: TextStyle(fontSize: 16)),
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
