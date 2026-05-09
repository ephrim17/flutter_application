class InputValidators {
  InputValidators._();

  static final RegExp _emailRegex = RegExp(
    r"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$",
    caseSensitive: false,
  );
  static final RegExp _indianPhoneRegex = RegExp(r'^[6-9]\d{9}$');

  static bool isValidEmail(String value) {
    return _emailRegex.hasMatch(value.trim());
  }

  static bool isValidIndianPhone(String value) {
    return _indianPhoneRegex.hasMatch(value.trim());
  }

  static double? parsePositiveAmount(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }
}
