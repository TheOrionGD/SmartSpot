import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders email, password inputs and login button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign in to continue to SmartSpot'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });
}
