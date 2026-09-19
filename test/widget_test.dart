import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health/main.dart';
import 'package:health/screens/login_screen.dart';

void main() {
  testWidgets('shows the login form', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(home: LoginScreen()));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text("Don't have an account?"), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });
}
