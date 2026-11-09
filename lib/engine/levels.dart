import 'package:meta/meta.dart';

import 'game_config.dart';
import 'game_session.dart';

/// One level on the level path.
@immutable
class Level {
  final String id;
  final int number;
  final GameConfig config;

  /// Win in at most this many guesses for 3 stars, or [twoStarGuesses] for 2.
  /// Any other win earns 1 star.
  final int threeStarGuesses;
  final int twoStarGuesses;

  /// Stars needed in total across earlier levels to unlock this one.
  final int starsToUnlock;

  const Level({
    required this.id,
    required this.number,
    required this.config,
    required this.threeStarGuesses,
    required this.twoStarGuesses,
    this.starsToUnlock = 0,
  }) : assert(threeStarGuesses <= twoStarGuesses);

  /// 0 for a loss, otherwise 1-3.
  int starsFor(GameResult result) {
    if (!result.won) return 0;
    if (result.guessCount <= threeStarGuesses) return 3;
    if (result.guessCount <= twoStarGuesses) return 2;
    return 1;
  }
}

/// A player's progress through the levels: best stars per level id.
class LevelProgress {
  final Map<String, int> bestStars;
  LevelProgress([Map<String, int>? bestStars]) : bestStars = {...?bestStars};

  int get totalStars => bestStars.values.fold(0, (a, b) => a + b);

  bool isCompleted(Level level) => (bestStars[level.id] ?? 0) > 0;

  /// The first level is always open. Each later one needs the previous level
  /// completed and enough total stars.
  bool isUnlocked(Level level, List<Level> path) {
    final index = path.indexWhere((l) => l.id == level.id);
    if (index <= 0) return true;
    return isCompleted(path[index - 1]) && totalStars >= level.starsToUnlock;
  }

  /// Records a result; keeps the best star count. Returns stars earned.
  int record(Level level, GameResult result) {
    final stars = level.starsFor(result);
    if (stars > (bestStars[level.id] ?? 0)) bestStars[level.id] = stars;
    return stars;
  }

  Map<String, dynamic> toJson() => {'bestStars': bestStars};
  factory LevelProgress.fromJson(Map<String, dynamic> json) =>
      LevelProgress((json['bestStars'] as Map).cast<String, int>());
}

/// A first-pass level path: digit count grows 3 to 6, guess limits tighten,
/// and later levels add a timer. Tuning will come with playtesting.
final List<Level> defaultLevelPath = _buildDefaultPath();

List<Level> _buildDefaultPath() {
  final specs =
      <(int digits, int maxGuesses, int three, int two, int? seconds)>[
        (3, 12, 5, 8, null),
        (3, 10, 5, 7, null),
        (3, 8, 4, 6, null),
        (4, 14, 7, 10, null),
        (4, 12, 6, 9, null),
        (4, 10, 6, 8, null),
        (4, 10, 6, 8, 180),
        (5, 16, 8, 12, null),
        (5, 14, 8, 11, null),
        (5, 12, 7, 10, 300),
        (6, 18, 10, 14, null),
        (6, 15, 9, 12, 420),
      ];
  return [
    for (var i = 0; i < specs.length; i++)
      Level(
        id: 'L${i + 1}',
        number: i + 1,
        config: GameConfig(
          digitCount: specs[i].$1,
          maxGuesses: specs[i].$2,
          timeLimit: specs[i].$5 == null
              ? null
              : Duration(seconds: specs[i].$5!),
        ),
        threeStarGuesses: specs[i].$3,
        twoStarGuesses: specs[i].$4,
        // Every third level asks for a bit more than bare completion.
        starsToUnlock: (i ~/ 3) * 4,
      ),
  ];
}
