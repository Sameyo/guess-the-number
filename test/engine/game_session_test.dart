import 'package:flutter_test/flutter_test.dart';
import 'package:guess_the_number/engine.dart';

import 'fake_clock.dart';

void main() {
  late FakeClock clock;
  setUp(() => clock = FakeClock());

  GameSession session([
    GameConfig config = GameConfig.standard,
    String secret = '1234',
  ]) => GameSession(
    config: config,
    secret: Code.parse(secret, config),
    clock: clock.call,
  );

  test('plays to a win and records time and guesses', () {
    final g = session();
    expect(g.status, GameStatus.notStarted);
    clock.advance(const Duration(seconds: 5)); // before start: not counted
    g.submit('5678');
    expect(g.status, GameStatus.inProgress);
    clock.advance(const Duration(seconds: 10));
    final e = g.submit('4321');
    expect(e.score, const Score(identified: 4, inPosition: 0));
    expect(e.elapsed, const Duration(seconds: 10));
    clock.advance(const Duration(seconds: 20));
    g.submit('1234');
    expect(g.status, GameStatus.won);
    expect(g.guessCount, 3);
    expect(g.elapsed, const Duration(seconds: 30));
    clock.advance(const Duration(minutes: 5));
    expect(
      g.elapsed,
      const Duration(seconds: 30),
      reason: 'timer stops at the end',
    );
    expect(g.result.won, isTrue);
    expect(g.result.guessCount, 3);
  });

  test('explicit start counts thinking time', () {
    final g = session()..start();
    clock.advance(const Duration(seconds: 7));
    g.submit('1234');
    expect(g.result.duration, const Duration(seconds: 7));
  });

  test('rejects guesses after the game is over', () {
    final g = session()..submit('1234');
    expect(() => g.submit('5678'), throwsA(isA<GameNotActiveException>()));
  });

  test('check reports invalid and duplicate guesses', () {
    final g = session();
    expect(g.check('1203')?.codeError, CodeError.invalidCharacter);
    expect(g.check('5678'), isNull);
    g.submit('5678');
    expect(g.check('5678')?.alreadyGuessed, isTrue);
  });

  test('guess limit ends the game as a loss', () {
    final g = session(const GameConfig(maxGuesses: 2));
    g.submit('5678');
    expect(g.guessesRemaining, 1);
    g.submit('5679');
    expect(g.status, GameStatus.lost);
    expect(g.lossReason, LossReason.outOfGuesses);
  });

  test('winning on the last allowed guess is a win', () {
    final g = session(const GameConfig(maxGuesses: 2));
    g.submit('5678');
    g.submit('1234');
    expect(g.status, GameStatus.won);
  });

  test('time limit ends the game at exactly the limit', () {
    final g = session(const GameConfig(timeLimit: Duration(seconds: 60)))
      ..start();
    clock.advance(const Duration(seconds: 30));
    expect(g.timeRemaining, const Duration(seconds: 30));
    expect(g.checkTimeout(), isFalse);
    clock.advance(const Duration(seconds: 45));
    expect(() => g.submit('1234'), throwsA(isA<GameNotActiveException>()));
    expect(g.lossReason, LossReason.outOfTime);
    expect(g.elapsed, const Duration(seconds: 60));
  });

  test('give up', () {
    final g = session()..giveUp();
    expect(g.status, GameStatus.lost);
    expect(g.lossReason, LossReason.gaveUp);
  });

  test('secret must match digit count', () {
    expect(
      () => GameSession(
        config: const GameConfig(digitCount: 5),
        secret: Code.parse('1234', GameConfig.standard),
      ),
      throwsArgumentError,
    );
  });

  test('GameResult json round trip', () {
    final g = session(
      const GameConfig(
        digitCount: 4,
        maxGuesses: 10,
        timeLimit: Duration(minutes: 3),
      ),
    )..submit('1234');
    final r = GameResult.fromJson(g.result.withLevel('L4').toJson());
    expect(r.config, g.config);
    expect(r.won, isTrue);
    expect(r.levelId, 'L4');
    expect(r.finishedAt, clock.now);
  });
}
