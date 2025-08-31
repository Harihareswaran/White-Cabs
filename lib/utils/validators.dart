class Validators {
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a name';
    }
    return null;
  }

  static String? validateRegistrationNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a registration number';
    }
    return null;
  }

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a phone number';
    }
    if (!RegExp(r'^\+91[0-9]{10}$').hasMatch(value)) {
      return 'Please enter a valid phone number (+91XXXXXXXXXX)';
    }
    return null;
  }
}