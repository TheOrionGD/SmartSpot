import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/main.dart';

void main() {
  testWidgets('SmartSpot starts on the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('SmartSpot'), findsOneWidget);
    expect(find.text('Location Based Reminder'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
  });
}
