import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/screens/register_screen.dart';

void main() {
  testWidgets('RegisterScreen renders form fields and registration button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsWidgets);
    expect(find.byType(TextFormField), findsAtLeastNWidgets(3));
  });
}
