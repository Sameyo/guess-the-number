import 'package:flutter_test/flutter_test.dart';
import 'package:guess_the_number/engine.dart';

GameResult result({
  int digits = 4,
  bool won = true,
  int guesses = 8,
  int seconds = 60,
  int day = 1,
}) => GameResult(
  config: GameConfig(digitCount: digits),
  won: won,
  guessCount: guesses,
  duration: Duration(seconds: seconds),
  finishedAt: DateTime.utc(2026, 1, day),
);

void main() {
  group('PlayerStats', () {
    final stats = PlayerStats([
      result(guesses: 8, seconds: 90, day: 1),
      result(guesses: 5, seconds: 120, day: 2),
      result(won: false, guesses: 12, seconds: 10, day: 3),
      result(guesses: 7, seconds: 45, day: 4),
      result(digits: 5, guesses: 3, seconds: 20, day: 5),
    ]);

    test('counts and win rate', () {
      expect(stats.gamesPlayed, 5);
      expect(stats.gamesWon, 4);
      expect(stats.winRate, 0.8);
    });
    test('best records are per digit count and ignore losses', () {
      final best = stats.best(4);
      expect(best.fewestGuesses, 5);
      expect(best.fastestTime, const Duration(seconds: 45));
      expect(stats.best(6).fewestGuesses, isNull);
    });
    test(
      'average guesses',
      () => expect(stats.averageGuesses(4), closeTo(20 / 3, 1e-9)),
    );
    test('detects new records', () {
      final r = stats.newRecordsFor(result(guesses: 4, seconds: 50));
      expect(r.fewestGuesses, isTrue);
      expect(r.fastestTime, isFalse);
    });
    test('streak counts recent wins', () => expect(stats.currentStreak, 2));
  });

  group('Levels', () {
    final level = defaultLevelPath[3];

    test('default path spans 3 to 6 digits with limits', () {
      final digits = defaultLevelPath.map((l) => l.config.digitCount).toSet();
      expect(digits, {3, 4, 5, 6});
      expect(
        defaultLevelPath.every((l) => l.config.maxGuesses != null),
        isTrue,
      );
      expect(defaultLevelPath.any((l) => l.config.timeLimit != null), isTrue);
    });
    test('stars from guess count', () {
      expect(level.starsFor(result(guesses: level.threeStarGuesses)), 3);
      expect(level.starsFor(result(guesses: level.twoStarGuesses)), 2);
      expect(level.starsFor(result(guesses: level.twoStarGuesses + 1)), 1);
      expect(level.starsFor(result(won: false)), 0);
    });
    test('unlocking needs the previous level and enough stars', () {
      final p = LevelProgress();
      final path = defaultLevelPath;
      expect(p.isUnlocked(path[0], path), isTrue);
      expect(p.isUnlocked(path[1], path), isFalse);
      for (var i = 0; i < 3; i++) {
        p.record(path[i], result(digits: 3, guesses: 6)); // 2 stars each
      }
      expect(p.totalStars, 6);
      expect(p.isUnlocked(path[3], path), isTrue); // needs 4
    });
    test('progress keeps the best stars and round trips json', () {
      final p = LevelProgress();
      p.record(level, result(guesses: 1));
      p.record(level, result(guesses: 20));
      expect(p.bestStars[level.id], 3);
      expect(LevelProgress.fromJson(p.toJson()).bestStars, p.bestStars);
    });
  });
}
