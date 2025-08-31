import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/vehicle.dart';
import '../../models/driver.dart';
import '../../services/database_service.dart';
import '../../services/sms_service.dart';
import '../driver/driver_details_screen.dart';

class TripAssignmentScreen extends StatefulWidget {
  final Vehicle vehicle;
  final Driver driver;
  final bool isReassign;

  const TripAssignmentScreen({
    Key? key,
    required this.vehicle,
    required this.driver,
    this.isReassign = false,
  }) : super(key: key);

  @override
  _TripAssignmentScreenState createState() => _TripAssignmentScreenState();
}

class _TripAssignmentScreenState extends State<TripAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _pickupAreaController = TextEditingController();
  final _dropAreaController = TextEditingController();
  final _startDateController = TextEditingController();
  String? _selectedTripType = 'Single';
  String? _selectedPackageType;
  Vehicle? _selectedVehicle;
  Driver? _selectedDriver;
  final List<String> _packageTypes = ['Local', 'Rental', 'Outstation'];
  DateTime? _selectedStartDateTime;
  Map<String, dynamic>? _cachedTripData;
  List<Vehicle>? _cachedVehicles;
  List<Driver>? _cachedDrivers;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.vehicle;
    _selectedDriver = widget.driver;
    _selectedPackageType = _packageTypes[0];
    debugPrint('Initial driver: ${widget.driver.name}, photoPath: ${widget.driver.driverPhotoPath}, exists: ${widget.driver.driverPhotoPath.isNotEmpty && File(widget.driver.driverPhotoPath).existsSync()}');
    debugPrint('Initial vehicle: ${widget.vehicle.name}, status: ${widget.vehicle.status}');
    _customerPhoneController.addListener(_updatePhoneCounter);
    _preloadData();
  }

  void _updatePhoneCounter() {
    setState(() {
      // Trigger rebuild to update the counter
    });
  }

  Future<void> _preloadData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    await Future.wait([
      dbService.getVehicles().then((vehicles) {
        _cachedVehicles = vehicles;
        debugPrint('Vehicles cached: ${_cachedVehicles?.length ?? 0} vehicles');
      }),
      dbService.getDrivers().then((drivers) {
        _cachedDrivers = drivers;
        debugPrint('Drivers cached: ${_cachedDrivers?.length ?? 0} drivers');
      }),
      if (widget.isReassign)
        dbService.getTripByVehicleId(widget.vehicle.id).then((trip) {
          if (trip != null && mounted) {
            _cachedTripData = {
              'customerName': trip.customerName ?? '',
              'customerPhone': trip.customerPhone.startsWith('+91') ? trip.customerPhone.substring(3) : trip.customerPhone,
              'pickupArea': trip.pickupArea ?? '',
              'dropArea': trip.dropArea ?? '',
              'startDateTime': trip.startDateTime != null ? DateTime.parse(trip.startDateTime!) : null,
              'tripType': trip.tripType == 'Round' ? 'Round' : 'Single',
              'packageType': _packageTypes.contains(trip.packageType) ? trip.packageType : _packageTypes[0],
              'bookingId': trip.bookingId,
              'customerId': trip.customerId,
            };
            setState(() {
              _customerNameController.text = _cachedTripData!['customerName'];
              _customerPhoneController.text = _cachedTripData!['customerPhone'];
              _pickupAreaController.text = _cachedTripData!['pickupArea'];
              _dropAreaController.text = _cachedTripData!['dropArea'];
              _startDateController.text = _cachedTripData!['startDateTime'] != null
                  ? DateFormat('dd-MM-yyyy HH:mm').format(_cachedTripData!['startDateTime'])
                  : '';
              _selectedTripType = _cachedTripData!['tripType'];
              _selectedPackageType = _cachedTripData!['packageType'];
              _selectedStartDateTime = _cachedTripData!['startDateTime'];
            });
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No active trip found for this vehicle. Cannot edit.'),
                backgroundColor: Colors.red,
              ),
            );
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.pop(context);
            });
          }
        }),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedStartDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedStartDateTime ?? DateTime.now()),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _selectedStartDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _startDateController.text = DateFormat('dd-MM-yyyy HH:mm').format(_selectedStartDateTime!);
        });
      }
    }
  }

  void _showVehicleBottomSheet(BuildContext context) {
    if (_cachedVehicles == null || _cachedVehicles!.isEmpty) {
      debugPrint('No vehicles available: _cachedVehicles is ${_cachedVehicles == null ? 'null' : 'empty'}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vehicles available'), backgroundColor: Colors.red),
      );
      return;
    }
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      elevation: 8,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => FutureBuilder<List<Vehicle>>(
          future: dbService.getVehicles().then((vehicles) async {
            final availableVehicles = <Vehicle>[];
            for (var vehicle in vehicles) {
              if (!(await dbService.isEntityInActiveTrip(vehicleId: vehicle.id))) {
                availableVehicles.add(vehicle);
              }
            }
            return availableVehicles;
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              debugPrint('No available vehicles: ${snapshot.error ?? 'Empty list'}');
              return const Center(child: Text('No available vehicles'));
            }
            final availableVehicles = snapshot.data!;
            debugPrint('Showing vehicle bottom sheet with ${availableVehicles.length} vehicles');
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Select Vehicle',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: availableVehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = availableVehicles[index];
                      debugPrint('Vehicle ${vehicle.name}, photoPath: ${vehicle.photoPath}, exists: ${vehicle.photoPath != null && vehicle.photoPath!.isNotEmpty && File(vehicle.photoPath!).existsSync()}');
                      return InkWell(
                        onTap: () {
                          if (mounted) {
                            setState(() {
                              _selectedVehicle = vehicle;
                              debugPrint('Vehicle selected: ${vehicle.name}, photoPath: ${vehicle.photoPath ?? 'none'}');
                            });
                            Navigator.pop(context);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.blue[100],
                                backgroundImage: vehicle.photoPath != null && vehicle.photoPath!.isNotEmpty && File(vehicle.photoPath!).existsSync()
                                    ? FileImage(File(vehicle.photoPath!))
                                    : null,
                                child: vehicle.photoPath == null || vehicle.photoPath!.isEmpty || !File(vehicle.photoPath!).existsSync()
                                    ? const Icon(Icons.directions_car, size: 28, color: Colors.blue)
                                    : null,
                                onBackgroundImageError: (error, stackTrace) {
                                  debugPrint('Vehicle image load error for ${vehicle.name}: ${vehicle.photoPath}, error: $error, stackTrace: $stackTrace');
                                },
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${vehicle.name} (${vehicle.type})',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Reg: ${vehicle.regNumber}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showDriverBottomSheet(BuildContext context) {
    if (_cachedDrivers == null || _cachedDrivers!.isEmpty) {
      debugPrint('No drivers available: _cachedDrivers is ${_cachedDrivers == null ? 'null' : 'empty'}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No drivers available'), backgroundColor: Colors.red),
      );
      return;
    }
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      elevation: 8,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => FutureBuilder<List<Driver>>(
          future: dbService.getDrivers().then((drivers) async {
            final availableDrivers = <Driver>[];
            for (var driver in drivers) {
              if (!(await dbService.isEntityInActiveTrip(driverId: driver.id))) {
                availableDrivers.add(driver);
              }
            }
            return availableDrivers;
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              debugPrint('No available drivers: ${snapshot.error ?? 'Empty list'}');
              return const Center(child: Text('No available drivers'));
            }
            final availableDrivers = snapshot.data!;
            debugPrint('Showing driver bottom sheet with ${availableDrivers.length} drivers');
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Select Driver',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: availableDrivers.length,
                    itemBuilder: (context, index) {
                      final driver = availableDrivers[index];
                      return InkWell(
                        onTap: () {
                          if (mounted) {
                            setState(() {
                              _selectedDriver = driver;
                              debugPrint('Driver selected: ${driver.name}');
                            });
                            Navigator.pop(context);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: driver.driverPhotoPath.isNotEmpty && File(driver.driverPhotoPath).existsSync()
                                    ? FileImage(File(driver.driverPhotoPath))
                                    : null,
                                child: driver.driverPhotoPath.isEmpty || !File(driver.driverPhotoPath).existsSync()
                                    ? const Icon(Icons.person, size: 28, color: Colors.grey)
                                    : null,
                                onBackgroundImageError: (error, stackTrace) {
                                  debugPrint('Driver image load error: ${driver.name}, error: $error');
                                },
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driver.name,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      driver.phone,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customerPhoneController.removeListener(_updatePhoneCounter);
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _pickupAreaController.dispose();
    _dropAreaController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  Future<void> _assignTrip(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      if (_selectedVehicle == null || _selectedDriver == null || _selectedPackageType == null || _selectedStartDateTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.red),
        );
        return;
      }

      final dbService = Provider.of<DatabaseService>(context, listen: false);
      if (_selectedVehicle!.id != widget.vehicle.id) {
        final isVehicleAvailable = !(await dbService.isEntityInActiveTrip(vehicleId: _selectedVehicle!.id));
        if (!isVehicleAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected vehicle is already assigned'), backgroundColor: Colors.red),
          );
          return;
        }
      }
      if (_selectedDriver!.id != widget.driver.id) {
        final isDriverAvailable = !(await dbService.isEntityInActiveTrip(driverId: _selectedDriver!.id));
        if (!isDriverAvailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected driver is already assigned'), backgroundColor: Colors.red),
          );
          return;
        }
      }

      setState(() => _isLoading = true);
      final smsService = Provider.of<SmsService>(context, listen: false);
      String customerPhone = _customerPhoneController.text.trim();
      if (!customerPhone.startsWith('+91')) {
        customerPhone = '+91$customerPhone';
      }

      String? bookingId;
      String? customerId;
      try {
        debugPrint('Assigning trip: vehicleId=${_selectedVehicle!.id}, driverId=${_selectedDriver!.id}, isReassign=${widget.isReassign}');
        if (widget.isReassign) {
          final currentTrip = await dbService.getTripByVehicleId(widget.vehicle.id);
          bookingId = currentTrip?.bookingId;
          customerId = currentTrip?.customerId;
          await dbService.reassignTrip(
            widget.vehicle.id,
            _selectedVehicle!.id,
            _selectedDriver!.id,
            _customerNameController.text.trim(),
            customerPhone,
            _pickupAreaController.text.trim(),
            _dropAreaController.text.trim(),
            _selectedStartDateTime!.toIso8601String(),
            _selectedTripType!,
            _selectedPackageType!,
          );
        } else {
          await dbService.assignTrip(
            _selectedVehicle!.id,
            _selectedDriver!.id,
            _customerNameController.text.trim(),
            customerPhone,
            _pickupAreaController.text.trim(),
            _dropAreaController.text.trim(),
            _selectedStartDateTime!.toIso8601String(),
            _selectedTripType!,
            _selectedPackageType!,
          );
          bookingId = dbService.getActiveTripBookingId();
          customerId = dbService.getActiveTripCustomerId();
        }

        final smsMessage = widget.isReassign
            ? 'Dear ${_customerNameController.text.trim()},\n'
                'Your trip with White Cabs has been successfully reassigned.\n'
                'Booking ID: $bookingId\n'
                'Customer ID: $customerId\n'
                'Trip Details:\n'
                'Driver: ${_selectedDriver!.name} (${_selectedDriver!.phone})\n'
                'Vehicle: ${_selectedVehicle!.name} ${_selectedVehicle!.type} (${_selectedVehicle!.regNumber})\n'
                'Pickup: ${_pickupAreaController.text.trim()}\n'
                'Drop: ${_dropAreaController.text.trim()}\n'
                'Start: ${_startDateController.text}\n'
                'Trip Type: $_selectedTripType\n'
                'Website: www.tiruppurcabs.com\n'
                'We look forward to serving you!'
            : 'Dear ${_customerNameController.text.trim()},\n'
                'Your trip with White Cabs has been successfully booked.\n'
                'Booking ID: $bookingId\n'
                'Customer ID: $customerId\n'
                'Trip Details:\n'
                'Driver: ${_selectedDriver!.name} (${_selectedDriver!.phone})\n'
                'Vehicle: ${_selectedVehicle!.name} ${_selectedVehicle!.type} (${_selectedVehicle!.regNumber})\n'
                'Pickup: ${_pickupAreaController.text.trim()}\n'
                'Drop: ${_dropAreaController.text.trim()}\n'
                'Start: ${_startDateController.text}\n'
                'Trip Type: $_selectedTripType\n'
                'Website: www.tiruppurcabs.com\n'
                'We look forward to serving you!';
        await smsService.sendSMS(customerPhone, smsMessage, vehicleType: _selectedVehicle!.type);

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.isReassign ? 'Trip reassigned successfully' : 'Trip started successfully'),
              backgroundColor: Colors.green,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            Navigator.pop(context);
            if (!widget.isReassign) {
              Navigator.pop(context);
            }
          }
        }
      } catch (e) {
        debugPrint('Error in _assignTrip: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isReassign ? 'Edit Trip' : 'Assign Trip'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[800]!, Colors.blue[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  debugPrint('Tapped driver photo: ${_selectedDriver!.name}, photoPath: ${_selectedDriver!.driverPhotoPath}, exists: ${File(_selectedDriver!.driverPhotoPath).existsSync()}');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DriverDetailsScreen(driver: _selectedDriver!),
                                    ),
                                  );
                                },
                                child: Hero(
                                  tag: 'driver_${_selectedDriver!.id}',
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: _selectedDriver!.driverPhotoPath.isNotEmpty && File(_selectedDriver!.driverPhotoPath).existsSync()
                                        ? FileImage(File(_selectedDriver!.driverPhotoPath))
                                        : null,
                                    child: _selectedDriver!.driverPhotoPath.isEmpty || !File(_selectedDriver!.driverPhotoPath).existsSync()
                                        ? const Icon(Icons.person, size: 40, color: Colors.grey)
                                        : null,
                                    onBackgroundImageError: (error, stackTrace) {
                                      debugPrint('Image load error for ${_selectedDriver!.name}: ${_selectedDriver!.driverPhotoPath}, error: $error');
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Driver: ${_selectedDriver!.name}',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Phone: ${_selectedDriver!.phone}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer Details',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                child: TextFormField(
                                  controller: _customerNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Customer Name',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    errorBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.red),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter customer name';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    TextFormField(
                                      controller: _customerPhoneController,
                                      decoration: InputDecoration(
                                        labelText: 'Customer Phone',
                                        prefixIcon: const Icon(Icons.phone_outlined),
                                        prefixText: '+91 ',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        filled: true,
                                        fillColor: Colors.white,
                                        errorBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(color: Colors.red),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter customer phone';
                                        }
                                        final cleanPhone = value.trim();
                                        if (!RegExp(r'^\d{10}$').hasMatch(cleanPhone)) {
                                          return 'Phone number must be exactly 10 digits';
                                        }
                                        return null;
                                      },
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_customerPhoneController.text.length}/10',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: _customerPhoneController.text.length == 10 ? Colors.green : Colors.grey[600],
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trip Details',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                child: TextFormField(
                                  controller: _pickupAreaController,
                                  decoration: InputDecoration(
                                    labelText: 'Pickup Area',
                                    prefixIcon: const Icon(Icons.location_on_outlined),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    errorBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.red),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter pickup area';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                child: TextFormField(
                                  controller: _dropAreaController,
                                  decoration: InputDecoration(
                                    labelText: 'Drop Area',
                                    prefixIcon: const Icon(Icons.location_off_outlined),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    errorBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.red),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter drop area';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                child: TextFormField(
                                  controller: _startDateController,
                                  decoration: InputDecoration(
                                    labelText: 'Start Date & Time',
                                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.calendar_today),
                                      onPressed: () => _selectDateTime(context),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.red),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  readOnly: true,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please select start date and time';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Trip Type',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'Trip',
                                    groupValue: _selectedTripType,
                                    onChanged: (value) {
                                      if (mounted) {
                                        setState(() {
                                          _selectedTripType = value;
                                          debugPrint('Trip type selected: $value');
                                        });
                                      }
                                    },
                                    activeColor: Colors.blue[700],
                                  ),
                                  const Text('Trip'),
                                  const SizedBox(width: 16),
                                  Radio<String>(
                                    value: 'Round',
                                    groupValue: _selectedTripType,
                                    onChanged: (value) {
                                      if (mounted) {
                                        setState(() {
                                          _selectedTripType = value;
                                          debugPrint('Trip type selected: $value');
                                        });
                                      }
                                    },
                                    activeColor: Colors.blue[700],
                                  ),
                                  const Text('Round'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selection',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              if (!widget.isReassign) ...[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vehicle: ${_selectedVehicle!.name} (${_selectedVehicle!.type})',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Reg: ${_selectedVehicle!.regNumber}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  child: TextFormField(
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'Vehicle',
                                      prefixIcon: const Icon(Icons.directions_car_outlined),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.white,
                                      suffixIcon: const Icon(Icons.arrow_drop_down),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(color: Colors.red),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    controller: TextEditingController(
                                      text: _selectedVehicle != null
                                          ? '${_selectedVehicle!.name} (${_selectedVehicle!.type})'
                                          : '',
                                    ),
                                    onTap: () => _showVehicleBottomSheet(context),
                                    validator: (value) => _selectedVehicle == null ? 'Please select a vehicle' : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  child: TextFormField(
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'Driver',
                                      prefixIcon: const Icon(Icons.person_pin_outlined),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.white,
                                      suffixIcon: const Icon(Icons.arrow_drop_down),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(color: Colors.red),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    controller: TextEditingController(
                                      text: _selectedDriver != null ? _selectedDriver!.name : '',
                                    ),
                                    onTap: () => _showDriverBottomSheet(context),
                                    validator: (value) => _selectedDriver == null ? 'Please select a driver' : null,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedPackageType,
                                  decoration: InputDecoration(
                                    labelText: 'Package Type',
                                    prefixIcon: const Icon(Icons.category_outlined),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    errorBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.red),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  items: _packageTypes.map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(type),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (mounted) {
                                      setState(() {
                                        _selectedPackageType = value;
                                        debugPrint('Package type selected: $value');
                                      });
                                    }
                                  },
                                  validator: (value) => value == null ? 'Please select a package type' : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : () => _assignTrip(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 4,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    widget.isReassign ? 'Update Trip' : 'Start Trip',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red[700],
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}