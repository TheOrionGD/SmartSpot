import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/screens/onboarding_screen.dart';

void main() {
  testWidgets('OnboardingScreen renders initial slide and navigation controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to SmartSpot'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
