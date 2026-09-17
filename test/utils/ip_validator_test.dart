import 'package:flutter_test/flutter_test.dart';
import 'package:spicehut_admin_panel/utils/ip_validator.dart';

void main() {
  group('IpValidator', () {
    test('accepts valid IPv4 addresses', () {
      expect(IpValidator.isValidIpv4('192.168.1.20'), isTrue);
      expect(IpValidator.isValidIpv4('10.0.0.55'), isTrue);
      expect(IpValidator.isValidIpv4('255.255.255.255'), isTrue);
      expect(IpValidator.isValidIpv4('0.0.0.0'), isTrue);
    });

    test('rejects invalid IPv4 addresses', () {
      expect(IpValidator.isValidIpv4('999.888.1.1'), isFalse);
      expect(IpValidator.isValidIpv4('abc.def'), isFalse);
      expect(IpValidator.isValidIpv4('192.168.1'), isFalse);
      expect(IpValidator.isValidIpv4('192.168.1.1.1'), isFalse);
      expect(IpValidator.isValidIpv4('192.168.-1.10'), isFalse);
      expect(IpValidator.isValidIpv4(''), isFalse);
    });

    test('returns user-friendly validation messages', () {
      expect(
        IpValidator.validateIpv4('', fieldName: 'Kitchen printer IP address'),
        'Kitchen printer IP address is required.',
      );

      expect(
        IpValidator.validateIpv4('invalid-ip'),
        'Please enter a valid IPv4 address.',
      );

      expect(
        IpValidator.validateIpv4('192.168.1.10'),
        isNull,
      );
    });
  });
}
