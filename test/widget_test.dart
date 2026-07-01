// Basic smoke test for Paralegal Quest.

import 'package:flutter_test/flutter_test.dart';

import 'package:paralegal_quest/main.dart';

void main() {
  testWidgets('App launches and shows the setup screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ParalegalQuestApp());
    await tester.pump();

    expect(find.text('Paralegal Quest'), findsOneWidget);
    expect(find.text('Build your case'), findsOneWidget);
  });
}
