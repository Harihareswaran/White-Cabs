import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../../models/vehicle.dart';
import '../../models/driver.dart';
import '../../services/database_service.dart';
import '../../services/sms_service.dart';

class EndTripScreen extends StatefulWidget {
  final Vehicle vehicle;
  final Driver driver;
  final String customerPhone;
  final String tripType;
  final String customerName;
  final String pickupArea;
  final String dropArea;
  final String startDateTime;
  final String packageType;

  const EndTripScreen({
    Key? key,
    required this.vehicle,
    required this.driver,
    required this.customerPhone,
    required this.tripType,
    required this.customerName,
    required this.pickupArea,
    required this.dropArea,
    required this.startDateTime,
    required this.packageType,
  }) : super(key: key);

  @override
  _EndTripScreenState createState() => _EndTripScreenState();
}

class _EndTripScreenState extends State<EndTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  final _ratePerKmController = TextEditingController();
  final _fastagController = TextEditingController();
  final _extraChargesController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _endDateController = TextEditingController();
  double _netTotal = 0.0;
  DateTime? _selectedEndDateTime;
  String? _bookingId;
  String? _customerId;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      developer.log('EndTripScreen init: vehicleId=${widget.vehicle.id}, driverId=${widget.driver.id}, '
          'customerPhone=${widget.customerPhone}, startDateTime=${widget.startDateTime}, '
          'customerName=${widget.customerName}, tripType=${widget.tripType}');
    }
    _distanceController.addListener(_updateNetTotal);
    _ratePerKmController.addListener(_updateNetTotal);
    _fastagController.addListener(_updateNetTotal);
    _extraChargesController.addListener(_updateNetTotal);
    _selectedEndDateTime = DateTime.now();
    _endDateController.text = DateFormat('dd-MM-yyyy HH:mm').format(_selectedEndDateTime!);
    _loadTripDetails();
  }

  Future<void> _loadTripDetails() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    try {
      final trip = await dbService.getTripByVehicleId(widget.vehicle.id);
      if (trip != null && trip.bookingId.isNotEmpty && RegExp(r'^WHITECABS\d{4}$').hasMatch(trip.bookingId)) {
        setState(() {
          _bookingId = trip.bookingId;
          _customerId = trip.customerId.isNotEmpty ? trip.customerId : 'CUS${trip.bookingId.substring(9)}';
        });
        if (kDebugMode) {
          developer.log('Loaded trip: bookingId=$_bookingId, customerId=$_customerId, '
              'vehicleId=${widget.vehicle.id}, driverId=${trip.driverId}, '
              'customerName=${trip.customerName}, tripType=${trip.tripType}');
        }
      } else {
        if (kDebugMode) {
          developer.log('No valid trip found for vehicleId=${widget.vehicle.id}: ${trip?.toMap() ?? 'null'}');
        }
        setState(() {
          _bookingId = null;
          _customerId = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid trip found for this vehicle. Please start a new trip.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        developer.log('Error loading trip details for vehicleId=${widget.vehicle.id}: $e', stackTrace: stackTrace);
      }
      setState(() {
        _bookingId = null;
        _customerId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateNetTotal() {
    final distance = double.tryParse(_distanceController.text) ?? 0.0;
    final ratePerKm = double.tryParse(_ratePerKmController.text) ?? 0.0;
    final fastag = double.tryParse(_fastagController.text) ?? 0.0;
    final extraCharges = double.tryParse(_extraChargesController.text) ?? 0.0;
    final earnings = distance * ratePerKm;
    final netTotal = earnings + fastag + extraCharges;
    setState(() {
      _netTotal = netTotal;
    });
  }

  Future<void> _selectEndDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedEndDateTime ?? DateTime.now(),
      firstDate: DateTime.parse(widget.startDateTime),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedEndDateTime ?? DateTime.now()),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _selectedEndDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _endDateController.text = DateFormat('dd-MM-yyyy HH:mm').format(_selectedEndDateTime!);
        });
      }
    }
  }

  Future<void> _endTrip(BuildContext context) async {
    if (_formKey.currentState!.validate() && _bookingId != null) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final smsService = Provider.of<SmsService>(context, listen: false);

      try {
        final distance = double.parse(_distanceController.text);
        final ratePerKm = double.parse(_ratePerKmController.text);
        final fastag = double.tryParse(_fastagController.text) ?? 0.0;
        final extraCharges = double.tryParse(_extraChargesController.text) ?? 0.0;
        final earnings = distance * ratePerKm;
        final netTotal = earnings + fastag + extraCharges;
        final description = _descriptionController.text;
        final endDateTime = _selectedEndDateTime!.toIso8601String();
        final startDateTime = DateTime.parse(widget.startDateTime);
        final duration = _selectedEndDateTime!.difference(startDateTime);
        final durationHours = duration.inHours.toDouble() + (duration.inMinutes % 60) / 60.0;

        if (kDebugMode) {
          developer.log('Attempting to end trip: vehicleId=${widget.vehicle.id}, driverId=${widget.driver.id}, '
              'durationHours=$durationHours, bookingId=$_bookingId, customerId=$_customerId');
        }

        final trip = await dbService.getTripByVehicleId(widget.vehicle.id);
        if (trip == null || trip.bookingId != _bookingId) {
          if (kDebugMode) {
            developer.log('No active trip found or bookingId mismatch for vehicleId=${widget.vehicle.id}, '
                'expected bookingId=$_bookingId, found=${trip?.bookingId ?? 'null'}');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active trip found or booking ID mismatch. Please start a new trip.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (trip.driverId != widget.driver.id) {
          if (kDebugMode) {
            developer.log('Driver mismatch: trip.driverId=${trip.driverId}, widget.driver.id=${widget.driver.id}');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Driver mismatch. Please ensure the correct driver is selected.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final result = await dbService.endTrip(
          widget.vehicle.id,
          widget.driver.id,
          distance,
          ratePerKm,
          fastag,
          extraCharges,
          earnings,
          description,
          netTotal,
          endDateTime,
          durationHours,
        );

        final bookingId = result['bookingId'];
        final apiSuccess = result['apiSuccess'];

        String customerPhone = widget.customerPhone.trim();
        if (!customerPhone.startsWith('+91')) {
          customerPhone = '+91$customerPhone';
        }

        String durationString = '';
        final days = duration.inDays;
        final hours = duration.inHours % 24;
        final minutes = duration.inMinutes % 60;
        if (days > 0) durationString += '$days days ';
        if (hours > 0 || (days > 0 && minutes > 0)) durationString += '$hours hrs ';
        if (minutes > 0 || durationString.isEmpty) durationString += '$minutes mins';
        if (durationString.isEmpty) durationString = '0 mins';

        String smsMessage = 'Dear ${widget.customerName},\n'
            'Your trip with White Cabs has been successfully completed.\n'
            'Booking ID: $bookingId\n'
            'Customer ID: $_customerId\n'
            'Trip Details:\n'
            'Start: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(widget.startDateTime))}\n'
            'End: ${_endDateController.text}\n'
            'Duration: $durationString\n'
            'Distance: ${distance.toStringAsFixed(2)} km\n';
        if (fastag > 0) {
          smsMessage += 'Fastag: ₹${fastag.toStringAsFixed(2)}\n';
        }
        if (extraCharges > 0) {
          smsMessage += 'Extra Charges: ₹${extraCharges.toStringAsFixed(2)}\n';
        }
        smsMessage += 'Total Amount: ₹${netTotal.toStringAsFixed(2)}\n'
            'Download Invoice: https://www.whitecabs.com.in/invoice.php?bookingId=$bookingId\n'
            'Website: https://www.whitecabs.com.in\n'
            'Thank you for choosing White Cabs!';
        if (!apiSuccess) {
          smsMessage += '\n(Note: Server error occurred, data saved locally)';
        }

        await smsService.sendSMS(customerPhone, smsMessage, vehicleType: widget.vehicle.type);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiSuccess ? 'Trip ended successfully' : 'Trip ended successfully (data saved locally due to server error)'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
          Navigator.popUntil(context, ModalRoute.withName('/'));
        }
      } catch (e, stackTrace) {
        if (mounted) {
          String errorMessage = e.toString();
          if (errorMessage.contains('500')) {
            errorMessage = 'Server error (HTTP 500). Trip data saved locally, please try again later.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error ending trip: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (kDebugMode) {
          developer.log('Error in _endTrip: vehicleId=${widget.vehicle.id}, driverId=${widget.driver.id}, error=$e', stackTrace: stackTrace);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid form or missing booking ID. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _distanceController.removeListener(_updateNetTotal);
    _ratePerKmController.removeListener(_updateNetTotal);
    _fastagController.removeListener(_updateNetTotal);
    _extraChargesController.removeListener(_updateNetTotal);
    _distanceController.dispose();
    _ratePerKmController.dispose();
    _fastagController.dispose();
    _extraChargesController.dispose();
    _descriptionController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String durationString = 'Calculating...';
    if (_selectedEndDateTime != null) {
      final startDateTime = DateTime.parse(widget.startDateTime);
      final duration = _selectedEndDateTime!.difference(startDateTime);
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      final minutes = duration.inMinutes % 60;
      durationString = '';
      if (days > 0) durationString += '$days days ';
      if (hours > 0 || (days > 0 && minutes > 0)) durationString += '$hours hrs ';
      if (minutes > 0 || durationString.isEmpty) durationString += '$minutes mins';
      if (durationString.isEmpty) durationString = '0 mins';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('End Trip'),
        backgroundColor: const Color.fromARGB(255, 113, 122, 131),
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
      body: Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip Summary',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text('Vehicle: ${widget.vehicle.name} (${widget.vehicle.regNumber})',
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Driver: ${widget.driver.name}', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Customer: ${widget.customerName}', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Customer Phone: ${widget.customerPhone}',
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Booking ID: ${_bookingId ?? 'Loading...'}',
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Customer ID: ${_customerId ?? 'Loading...'}',
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Pickup: ${widget.pickupArea}', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Drop: ${widget.dropArea}', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text(
                              'Start: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(widget.startDateTime))}',
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Duration: $durationString', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Trip Type: ${widget.tripType}', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Package: ${widget.packageType}', style: Theme.of(context).textTheme.bodyLarge),
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
                            'Billing Details',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: TextFormField(
                              controller: _distanceController,
                              decoration: InputDecoration(
                                labelText: 'Distance (km)',
                                prefixIcon: const Icon(Icons.straighten_outlined),
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
                                if (value == null || value.isEmpty) {
                                  return 'Please enter distance';
                                }
                                if (double.tryParse(value) == null || double.parse(value) <= 0) {
                                  return 'Please enter a valid positive number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: TextFormField(
                              controller: _ratePerKmController,
                              decoration: InputDecoration(
                                labelText: 'Rate per km (₹)',
                                prefixIcon: const Icon(Icons.currency_rupee_outlined),
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
                                if (value == null || value.isEmpty) {
                                  return 'Please enter rate per km';
                                }
                                if (double.tryParse(value) == null || double.parse(value) <= 0) {
                                  return 'Please enter a valid positive number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: TextFormField(
                              controller: _fastagController,
                              decoration: InputDecoration(
                                labelText: 'Fastag (₹, optional)',
                                prefixIcon: const Icon(Icons.toll_outlined),
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
                                if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: TextFormField(
                              controller: _extraChargesController,
                              decoration: InputDecoration(
                                labelText: 'Extra Charges (₹, optional)',
                                prefixIcon: const Icon(Icons.add_circle_outline),
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
                                if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: TextFormField(
                              controller: _endDateController,
                              decoration: InputDecoration(
                                labelText: 'End Date & Time',
                                prefixIcon: const Icon(Icons.calendar_today_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () => _selectEndDateTime(context),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.red),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              readOnly: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please select end date and time';
                                }
                                try {
                                  final selectedDate = DateFormat('dd-MM-yyyy HH:mm').parse(value);
                                  final startDate = DateTime.parse(widget.startDateTime);
                                  if (selectedDate.isBefore(startDate)) {
                                    return 'End date cannot be before start date';
                                  }
                                } catch (e) {
                                  return 'Invalid date format';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Amount (includes all charges)',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₹${_netTotal.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                        fontSize: 20,
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
                            'Additional Notes',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: TextFormField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                labelText: 'Description (optional)',
                                prefixIcon: const Icon(Icons.note_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              maxLines: 3,
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
                        onPressed: () => _endTrip(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 4,
                        ),
                        child: const Text(
                          'End Trip',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
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
    );
  }
}