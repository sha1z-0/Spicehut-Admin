import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spicehut_admin_panel/storage/printer_storage.dart';

void main() {
  group('PrinterStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and loads global printer IPs', () async {
      await PrinterStorage.saveKitchenPrinterIp('192.168.1.50');
      await PrinterStorage.saveBillPrinterIp('192.168.1.51');

      expect(await PrinterStorage.getKitchenPrinterIp(), '192.168.1.50');
      expect(await PrinterStorage.getBillPrinterIp(), '192.168.1.51');
    });

    test('saves and loads branch-scoped printer IPs', () async {
      await PrinterStorage.saveKitchenPrinterIp(
        '10.0.0.10',
        branchId: 'Comox',
      );
      await PrinterStorage.saveBillPrinterIp(
        '10.0.0.11',
        branchId: 'Comox',
      );

      expect(
        await PrinterStorage.getKitchenPrinterIp(branchId: 'Comox'),
        '10.0.0.10',
      );
      expect(
        await PrinterStorage.getBillPrinterIp(branchId: 'Comox'),
        '10.0.0.11',
      );
    });

    test('falls back to global value when branch-specific key is missing', () async {
      await PrinterStorage.saveKitchenPrinterIp('192.168.88.20');

      expect(
        await PrinterStorage.getKitchenPrinterIp(branchId: 'Port Alberni'),
        '192.168.88.20',
      );
    });

    test('resolves active branch from selected dashboard branch first', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dashboard_selected_location', 'Comox');
      await prefs.setString('user_location', 'Tofino');

      expect(await PrinterStorage.resolveActiveBranchId(), 'Comox');
    });

    test('resolves active branch from user branch when dashboard branch is missing',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_location', 'Tofino');

      expect(await PrinterStorage.resolveActiveBranchId(), 'Tofino');
    });

    test('returns null when no branch context is available', () async {
      expect(await PrinterStorage.resolveActiveBranchId(), isNull);
    });
  });
}
