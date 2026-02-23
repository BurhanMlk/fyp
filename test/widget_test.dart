// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:blood_bridge_flutter/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
  // Build our app and trigger a frame. Use the BloodBridgeApp (login screen).
  await tester.pumpWidget(const BloodBridgeApp());

  // Verify that the login title/button text is present.
  expect(find.text('Login'), findsWidgets);
  });
}
