import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:guess_the_number/engine.dart';

import 'fake_clock.dart';

void main() {
  late FakeClock clock;
  setUp(() => clock = FakeClock());

  GameSession session([String secret = '1234']) => GameSession(
    config: GameConfig.standard,
    secret: Code.parse(secret, GameConfig.standard),
    clock: clock.call,
  );

  group('pause and resume', () {
    test('paused time is not counted', () {
      final g = session()..start();
      clock.advance(const Duration(seconds: 10));
      g.pause();
      clock.advance(const Duration(minutes: 5));
      expect(g.elapsed, const Duration(seconds: 10));
      g.resume();
      clock.advance(const Duration(seconds: 3));
      expect(g.elapsed, const Duration(seconds: 13));
    });

    test('submitting while paused resumes the clock', () {
      final g = session()..start();
      clock.advance(const Duration(seconds: 4));
      g.pause();
      clock.advance(const Duration(minutes: 1));
      final e = g.submit('5678');
      expect(e.elapsed, const Duration(seconds: 4));
      expect(g.isPaused, isFalse);
    });

    test('a paused game does not time out', () {
      final g = GameSession(
        config: const GameConfig(timeLimit: Duration(seconds: 30)),
        secret: Code.parse('1234', GameConfig.standard),
        clock: clock.call,
      )..start();
      g.pause();
      clock.advance(const Duration(minutes: 2));
      expect(g.checkTimeout(), isFalse);
      g.resume();
      clock.advance(const Duration(seconds: 31));
      expect(g.checkTimeout(), isTrue);
    });
  });

  group('save and restore', () {
    test('an unfinished session restores guesses and time, paused', () {
      final g = session()..start();
      clock.advance(const Duration(seconds: 7));
      g.submit('5678');
      clock.advance(const Duration(seconds: 5));
      g.submit('4321');
      clock.advance(const Duration(seconds: 3));

      final json = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      clock.advance(const Duration(hours: 1)); // app closed
      final r = GameSession.fromJson(json, clock: clock.call);

      expect(r.guessCount, 2);
      expect(r.guesses.last.score, const Score(identified: 4, inPosition: 0));
      expect(r.status, GameStatus.inProgress);
      expect(r.isPaused, isTrue);
      expect(r.elapsed, const Duration(seconds: 15));
      r.resume();
      clock.advance(const Duration(seconds: 5));
      expect(r.elapsed, const Duration(seconds: 20));
      r.submit('1234');
      expect(r.status, GameStatus.won);
      expect(r.result.duration, const Duration(seconds: 20));
    });

    test('a finished session restores as finished', () {
      final g = session()..submit('1234');
      final r = GameSession.fromJson(g.toJson(), clock: clock.call);
      expect(r.status, GameStatus.won);
      expect(r.isOver, isTrue);
    });

    test('a duel restores turn and outcome rules', () {
      final cfg = GameConfig.standard;
      final m = DuelMatch(
        config: cfg,
        secretOfA: Code.parse('1234', cfg),
        secretOfB: Code.parse('5678', cfg),
        clock: clock.call,
      );
      m.submit(PlayerSlot.a, '1234');
      m.submit(PlayerSlot.b, '9876');
      m.submit(PlayerSlot.a, '5678'); // A solves; B gets an equalising turn
      expect(m.outcome, isNull);

      final json = jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>;
      final r = DuelMatch.fromJson(json, clock: clock.call);
      expect(r.currentTurn, PlayerSlot.b);
      expect(r.outcome, isNull);
      expect(r.sessionOf(PlayerSlot.a).status, GameStatus.won);
      r.submit(PlayerSlot.b, '2134');
      expect(r.outcome?.winner, PlayerSlot.a);
    });
  });

  group('solver', () {
    test('knows every 4-digit code', () {
      expect(Solver.allCodes(GameConfig.standard).length, 3024);
    });

    for (final level in SolverLevel.values) {
      test('${level.name} always cracks the number', () {
        final random = Random(42);
        const cfg = GameConfig.standard;
        final solver = Solver(cfg, level: level, random: random);
        var total = 0;
        for (var game = 0; game < 30; game++) {
          final g = GameSession(
            config: cfg,
            secret: Code.random(cfg, random: random),
          );
          while (!g.isOver && g.guessCount < 40) {
            final guess = solver.nextGuess(g.guesses);
            expect(g.check(guess.toString()), isNull);
            g.submit(guess.toString());
          }
          expect(g.status, GameStatus.won);
          total += g.guessCount;
        }
        if (level != SolverLevel.easy) {
          expect(total / 30, lessThan(8));
        }
      });
    }

    test('candidates fit every clue so far', () {
      const cfg = GameConfig.standard;
      final g = session('1234')
        ..submit('1243')
        ..submit('5671');
      final fits = Solver(cfg).candidates(g.guesses);
      expect(fits, contains(Code.parse('1234', cfg)));
      for (final c in fits) {
        for (final h in g.guesses) {
          expect(Score.of(c, h.guess), h.score);
        }
      }
    });
  });
}
