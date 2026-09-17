import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spicehut_admin_panel/services/printer_service.dart';

void main() {
  group('PrinterService dual print', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('captures both kitchen and bill failures without throwing', () async {
      final result = await PrinterService.printKitchenAndBillInParallel(
        orderId: 'ORD-1001',
        items: const [
          {
            'name': 'Burger',
            'quantity': 1,
            'price': 10.0,
          }
        ],
        totalAmount: 10.0,
      );

      expect(result.hasFailures, isTrue);
      expect(result.kitchenPrinted, isFalse);
      expect(result.billPrinted, isFalse);

      expect(result.kitchenError, isA<PrinterServiceException>());
      expect(result.billError, isA<PrinterServiceException>());

      expect(
        result.kitchenError.toString(),
        contains('Printer not configured. Please open Printer Setup.'),
      );
      expect(
        result.billError.toString(),
        contains('Printer not configured. Please open Printer Setup.'),
      );
    });
  });
}
