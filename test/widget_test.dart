import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guess_the_number/main.dart';

void main() {
  testWidgets('placeholder screen shows a guess field and I/P columns', (
    tester,
  ) async {
    await tester.pumpWidget(const GuessTheNumberApp());
    expect(find.text('Your guess'), findsOneWidget);
    expect(find.text('I'), findsOneWidget);
    expect(find.text('P'), findsOneWidget);
  });

  testWidgets('invalid guess shows an error', (tester) async {
    await tester.pumpWidget(const GuessTheNumberApp());
    await tester.enterText(find.byKey(const Key('guessField')), '1123');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(find.text('No repeated digits'), findsOneWidget);
  });
}
