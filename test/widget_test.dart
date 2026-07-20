import 'package:flutter_test/flutter_test.dart';

import 'package:universbook/main.dart';

void main() {
  testWidgets('navigates from home to about', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Universbook Home'), findsOneWidget);
    expect(find.text('Welcome to Universbook'), findsOneWidget);

    await tester.tap(find.text('Go to About'));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
  });
}
