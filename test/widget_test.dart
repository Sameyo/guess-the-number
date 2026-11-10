import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guess_the_number/app/store.dart';
import 'package:guess_the_number/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(await SharedPreferences.getInstance());
  store.setHaptics(false);
  await tester.pumpWidget(GuessTheNumberApp(store: store));
  return store;
}

Future<void> enter(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(Key('key$d')));
    await tester.pump();
  }
  await tester.tap(find.byKey(const Key('keyGo')));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('home shows records and every mode', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('bestGuesses')), findsOneWidget);
    expect(find.byKey(const Key('bestTime')), findsOneWidget);
    expect(find.byKey(const Key('playSolo')), findsOneWidget);
    expect(find.byKey(const Key('playKutir')), findsOneWidget);
    expect(find.byKey(const Key('play2p')), findsOneWidget);
    expect(find.byKey(const Key('playLevels')), findsOneWidget);
    expect(find.byKey(const Key('resume')), findsNothing);
  });

  testWidgets('solo game counts guesses and can be resumed', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('playSolo')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timer')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('stepCounter'))).data, '0');
    // Find a guess that is not the secret, so the game keeps going.
    await enter(tester, '1234');
    if (store.savedGame == null) return; // lucky first guess; nothing to resume
    expect(tester.widget<Text>(find.byKey(const Key('stepCounter'))).data, '1');

    // The same guess again is refused.
    await enter(tester, '1234');
    expect(find.byKey(const Key('guessError')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('resume')), findsOneWidget);
    await tester.tap(find.byKey(const Key('resume')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('stepCounter'))).data, '1');
  });

  testWidgets('Kutir answers each guess', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('playKutir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('randomSecret')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('keyGo')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kutir → your number'), findsOneWidget);
    await enter(tester, '1234');
    expect(find.text('Kutir is thinking…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Kutir is thinking…'), findsNothing);
    // Leave the screen so its timers stop.
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('levels screen shows the first level unlocked', (tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.byKey(const Key('playLevels')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('playLevels')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('level1')), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsWidgets);
  });
}
