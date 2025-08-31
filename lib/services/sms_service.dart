import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsService with ChangeNotifier {
  Future<void> sendSMS(String phoneNumber, String message, {String vehicleType = ''}) async {
    try {
      final uri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch SMS';
      }
      if (kDebugMode) {
        debugPrint('SMS sent to $phoneNumber: $message');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending SMS: $e');
      }
      rethrow;
    }
  }
}