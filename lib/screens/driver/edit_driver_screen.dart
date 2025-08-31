import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/driver.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';

class EditDriverScreen extends StatefulWidget {
  final Driver driver;

  const EditDriverScreen({Key? key, required this.driver}) : super(key: key);

  @override
  _EditDriverScreenState createState() => _EditDriverScreenState();
}

class _EditDriverScreenState extends State<EditDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  XFile? _driverPhoto;
  XFile? _licensePhoto;
  String? _driverPhotoPath;
  String? _licensePhotoPath;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.driver.name);

    // Extract 10-digit phone number (remove +91 if present)
    String phone = widget.driver.phone;
    if (phone.startsWith('+91') && phone.length == 13) {
      phone = phone.substring(3);
    }
    _phoneController = TextEditingController(text: phone);
    _driverPhotoPath = widget.driver.driverPhotoPath;
    _licensePhotoPath = widget.driver.licensePhotoPath;
    _status = widget.driver.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDriverPhoto() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Source'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ImageSource.gallery), child: const Text('Gallery')),
          TextButton(onPressed: () => Navigator.pop(context, ImageSource.camera), child: const Text('Camera')),
        ],
      ),
    );
    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _driverPhoto = pickedFile;
        });
      }
    }
  }

  Future<void> _pickLicensePhoto() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Source'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ImageSource.gallery), child: const Text('Gallery')),
          TextButton(onPressed: () => Navigator.pop(context, ImageSource.camera), child: const Text('Camera')),
        ],
      ),
    );
    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _licensePhoto = pickedFile;
        });
      }
    }
  }

  Future<void> _saveDriver(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      String? newDriverPhotoPath = _driverPhotoPath;
      String? newLicensePhotoPath = _licensePhotoPath;

      if (_driverPhoto != null) {
        newDriverPhotoPath = await storageService.saveImage(
          File(_driverPhoto!.path),
          'drivers/${widget.driver.id}_driver.jpg',
        );
      }

      if (_licensePhoto != null) {
        newLicensePhotoPath = await storageService.saveImage(
          File(_licensePhoto!.path),
          'drivers/${widget.driver.id}_license.jpg',
        );
      }

      final updatedDriver = Driver(
        id: widget.driver.id,
        name: _nameController.text,
        phone: '+91${_phoneController.text.trim()}',
        driverPhotoPath: newDriverPhotoPath ?? '',
        licensePhotoPath: newLicensePhotoPath ?? '',
        status: _status,
      );

      await dbService.updateDriver(updatedDriver);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver updated')),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Driver', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                    Text('Driver Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                    const Divider(color: Colors.grey, thickness: 1, height: 20),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Driver Name'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter driver name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Phone Field with Static +91
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixText: '+91 ',
                        prefixStyle: TextStyle(color: Colors.black),
                        hintText: 'Enter 10-digit number',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter phone number';
                        if (value.length != 10) return 'Enter exactly 10 digits';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),
                    Text('Photos', style: TextStyle(fontSize: 16, color: Colors.blue[700])),

                    const SizedBox(height: 8),
                    Text('Driver Photo', style: TextStyle(fontSize: 14, color: Colors.blue[700])),
                    Row(
                      children: [
                        _driverPhoto != null
                            ? Image.file(File(_driverPhoto!.path), height: 100, fit: BoxFit.cover)
                            : _driverPhotoPath != null && _driverPhotoPath!.isNotEmpty
                                ? Image.file(File(_driverPhotoPath!), height: 100, fit: BoxFit.cover)
                                : const Text('No driver photo', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _pickDriverPhoto,
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
                    Text('License Photo', style: TextStyle(fontSize: 14, color: Colors.blue[700])),
                    Row(
                      children: [
                        _licensePhoto != null
                            ? Image.file(File(_licensePhoto!.path), height: 100, fit: BoxFit.cover)
                            : _licensePhotoPath != null && _licensePhotoPath!.isNotEmpty
                                ? Image.file(File(_licensePhotoPath!), height: 100, fit: BoxFit.cover)
                                : const Text('No license photo', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _pickLicensePhoto,
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
                    Text('Status', style: TextStyle(fontSize: 16, color: Colors.blue[700])),
                    Text(_status, style: const TextStyle(fontSize: 16)),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () => _saveDriver(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
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
