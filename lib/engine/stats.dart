import 'game_session.dart';

/// Best records for one digit count.
class BestRecord {
  final int digitCount;
  final int? fewestGuesses;
  final Duration? fastestTime;
  const BestRecord(this.digitCount, {this.fewestGuesses, this.fastestTime});
}

/// Aggregate stats computed from a list of finished games. Records are only
/// comparable between games with the same digit count, so they are keyed by it.
class PlayerStats {
  final List<GameResult> results;
  PlayerStats(Iterable<GameResult> results)
    : results = List.unmodifiable(results);

  int get gamesPlayed => results.length;
  int get gamesWon => results.where((r) => r.won).length;
  double get winRate => gamesPlayed == 0 ? 0 : gamesWon / gamesPlayed;

  Iterable<GameResult> _wins(int digitCount) =>
      results.where((r) => r.won && r.config.digitCount == digitCount);

  double? averageGuesses(int digitCount) {
    final wins = _wins(digitCount).toList();
    if (wins.isEmpty) return null;
    return wins.map((r) => r.guessCount).reduce((a, b) => a + b) / wins.length;
  }

  BestRecord best(int digitCount) {
    final wins = _wins(digitCount).toList();
    if (wins.isEmpty) return BestRecord(digitCount);
    return BestRecord(
      digitCount,
      fewestGuesses: wins
          .map((r) => r.guessCount)
          .reduce((a, b) => a < b ? a : b),
      fastestTime: wins.map((r) => r.duration).reduce((a, b) => a < b ? a : b),
    );
  }

  /// Which records [result] would set, compared with the games before it.
  ({bool fewestGuesses, bool fastestTime}) newRecordsFor(GameResult result) {
    if (!result.won) return (fewestGuesses: false, fastestTime: false);
    final prev = best(result.config.digitCount);
    return (
      fewestGuesses:
          prev.fewestGuesses == null || result.guessCount < prev.fewestGuesses!,
      fastestTime:
          prev.fastestTime == null || result.duration < prev.fastestTime!,
    );
  }

  /// Current run of consecutive wins, newest first.
  int get currentStreak {
    final sorted = List.of(results)
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    var streak = 0;
    for (final r in sorted) {
      if (!r.won) break;
      streak++;
    }
    return streak;
  }
}

/// Where results are kept. Step 2 adds a local (on-device) implementation;
/// Firebase can back it later for cross-device sync.
abstract interface class ResultsRepository {
  Future<List<GameResult>> loadAll();
  Future<void> add(GameResult result);
}

class InMemoryResultsRepository implements ResultsRepository {
  final List<GameResult> _results = [];
  @override
  Future<List<GameResult>> loadAll() async => List.of(_results);
  @override
  Future<void> add(GameResult result) async => _results.add(result);
}
