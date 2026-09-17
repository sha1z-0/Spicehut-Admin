import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spicehut_admin_panel/services/printer_service.dart';
import 'package:spicehut_admin_panel/widgets/printer_setup_guide_modal.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrinterService.connectionStateNotifier.value = {
      PrinterRole.kitchen: const PrinterConnectionState(
        ipAddress: null,
        status: PrinterConnectivityStatus.notConfigured,
      ),
      PrinterRole.bill: const PrinterConnectionState(
        ipAddress: null,
        status: PrinterConnectivityStatus.notConfigured,
      ),
    };
  });

  testWidgets('configure then cancel closes centered editor without crash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrinterSetupGuideModal(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Configure Kitchen Printer'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Kitchen Printer IP Address'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Kitchen Printer IP Address'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
