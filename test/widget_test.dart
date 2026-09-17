import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spicehut_admin_panel/screens/age_verification_screen.dart';

void main() {
  testWidgets('Age verification screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AgeVerificationScreen(
          onAgeVerified: () {},
        ),
      ),
    );

    expect(find.text('Age Verification Required'), findsOneWidget);
  });
}
