import 'package:flutter_test/flutter_test.dart';
import 'package:guess_the_number/engine.dart';

import 'fake_clock.dart';

void main() {
  const config = GameConfig.standard;
  Code c(String s) => Code.parse(s, config);

  group('DuelMatch', () {
    // A picked 1234 (B must guess it); B picked 5678 (A must guess it).
    DuelMatch duel({bool equalTurns = true, GameConfig cfg = config}) =>
        DuelMatch(
          config: cfg,
          secretOfA: c('1234'),
          secretOfB: c('5678'),
          equalTurns: equalTurns,
        );

    test('players guess the other secret', () {
      final m = duel();
      expect(m.submit(PlayerSlot.a, '5678').score.inPosition, 0 + 4);
      expect(m.sessionOf(PlayerSlot.b).secret, c('1234'));
    });

    test('enforces turn order', () {
      final m = duel();
      expect(
        () => m.submit(PlayerSlot.b, '1234'),
        throwsA(isA<MatchRuleException>()),
      );
      m.submit(PlayerSlot.a, '1239');
      expect(m.currentTurn, PlayerSlot.b);
      expect(
        () => m.submit(PlayerSlot.a, '1239'),
        throwsA(isA<MatchRuleException>()),
      );
    });

    test('second player gets an equalising turn', () {
      final m = duel()..submit(PlayerSlot.a, '5678');
      expect(m.status, MatchStatus.inProgress);
      m.submit(PlayerSlot.b, '9876');
      expect(m.outcome!.winner, PlayerSlot.a);
    });

    test('both solve in the same round is a draw', () {
      final m = duel()
        ..submit(PlayerSlot.a, '5678')
        ..submit(PlayerSlot.b, '1234');
      expect(m.outcome!.isDraw, isTrue);
    });

    test('without equal turns first solver wins immediately', () {
      final m = duel(equalTurns: false)..submit(PlayerSlot.a, '5678');
      expect(m.outcome!.winner, PlayerSlot.a);
    });

    test('second player can win', () {
      final m = duel()
        ..submit(PlayerSlot.a, '1239')
        ..submit(PlayerSlot.b, '1234');
      expect(m.outcome!.winner, PlayerSlot.b);
    });

    test('eliminated player is skipped; both out is a draw', () {
      final m = duel(cfg: const GameConfig(maxGuesses: 1))
        ..submit(PlayerSlot.a, '1239');
      expect(m.status, MatchStatus.inProgress);
      m.submit(PlayerSlot.b, '5679');
      expect(m.outcome!.isDraw, isTrue);
    });

    test('player out of guesses lets the other keep going', () {
      final m = DuelMatch(
        config: const GameConfig(maxGuesses: 3),
        secretOfA: c('1234'),
        secretOfB: c('5678'),
      );
      m
        ..submit(PlayerSlot.a, '1239')
        ..submit(PlayerSlot.b, '9871')
        ..submit(PlayerSlot.a, '1238')
        ..submit(PlayerSlot.b, '9872')
        ..submit(PlayerSlot.a, '1237'); // A is out of guesses
      expect(m.currentTurn, PlayerSlot.b);
      m.submit(PlayerSlot.b, '9873'); // B out too
      expect(m.outcome!.isDraw, isTrue);
    });
  });

  group('RaceMatch', () {
    test('first to solve wins', () {
      final clock = FakeClock();
      final m = RaceMatch(config: config, secret: c('1234'), clock: clock.call)
        ..start();
      clock.advance(const Duration(seconds: 10));
      m.submit(PlayerSlot.a, '5678');
      m.submit(PlayerSlot.b, '1234');
      expect(m.outcome!.winner, PlayerSlot.b);
      expect(
        () => m.submit(PlayerSlot.a, '1234'),
        throwsA(isA<MatchRuleException>()),
      );
    });

    test('players move independently', () {
      final m = RaceMatch(config: config, secret: c('1234'));
      m
        ..submit(PlayerSlot.a, '5678')
        ..submit(PlayerSlot.a, '5679');
      expect(m.sessionOf(PlayerSlot.a).guessCount, 2);
      expect(m.sessionOf(PlayerSlot.b).guessCount, 0);
      expect(m.status, MatchStatus.inProgress);
    });

    test('both out of guesses is a draw', () {
      final m =
          RaceMatch(config: const GameConfig(maxGuesses: 1), secret: c('1234'))
            ..submit(PlayerSlot.a, '5678')
            ..submit(PlayerSlot.b, '5679');
      expect(m.outcome!.isDraw, isTrue);
    });
  });
}
