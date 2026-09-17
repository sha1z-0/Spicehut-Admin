class IpValidator {
  static final RegExp _ipv4Pattern = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

  static bool isValidIpv4(String value) {
    final normalized = value.trim();
    if (!_ipv4Pattern.hasMatch(normalized)) {
      return false;
    }

    final octets = normalized.split('.');
    if (octets.length != 4) {
      return false;
    }

    for (final octet in octets) {
      final parsed = int.tryParse(octet);
      if (parsed == null || parsed < 0 || parsed > 255) {
        return false;
      }
    }

    return true;
  }

  static String? validateIpv4(
    String value, {
    String fieldName = 'Printer IP address',
  }) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return '$fieldName is required.';
    }

    if (!isValidIpv4(normalized)) {
      return 'Please enter a valid IPv4 address.';
    }

    return null;
  }
}
