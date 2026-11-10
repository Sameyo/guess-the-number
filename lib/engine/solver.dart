import 'dart:math';

import 'code.dart';
import 'game_config.dart';
import 'game_session.dart';
import 'score.dart';

/// How hard the computer opponent plays.
enum SolverLevel {
  /// Often guesses without using everything it has learned.
  easy,

  /// Always guesses a number that fits every clue so far.
  normal,

  /// Picks the fitting number that narrows the options down the most.
  hard,
}

/// A code breaker for the computer opponent ("Kutir").
///
/// It keeps no hidden state: [nextGuess] works from the visible history, so a
/// resumed game picks up exactly where it left off.
class Solver {
  final GameConfig config;
  final SolverLevel level;
  final Random _random;
  final List<Code> _allCodes;

  Solver(this.config, {this.level = SolverLevel.normal, Random? random})
    : _random = random ?? Random(),
      _allCodes = allCodes(config);

  /// Every valid code for [config], e.g. 3024 for 4 digits.
  static List<Code> allCodes(GameConfig config) {
    final result = <Code>[];
    final current = <int>[];
    final used = List<bool>.filled(10, false);
    void build() {
      if (current.length == config.digitCount) {
        result.add(Code.parse(current.join(), config));
        return;
      }
      for (final d in GameConfig.allowedDigits) {
        if (used[d]) continue;
        used[d] = true;
        current.add(d);
        build();
        current.removeLast();
        used[d] = false;
      }
    }

    build();
    return result;
  }

  /// Codes that would have produced every score in [history].
  List<Code> candidates(List<GuessEntry> history) => [
    for (final code in _allCodes)
      if (history.every((h) => Score.of(code, h.guess) == h.score)) code,
  ];

  /// The next guess, given the guesses and scores so far.
  Code nextGuess(List<GuessEntry> history) {
    final fits = candidates(history);
    if (fits.isEmpty) {
      // Only possible if the clues were inconsistent; fall back to anything new.
      return _randomUntried(history);
    }
    switch (level) {
      case SolverLevel.easy:
        if (fits.length > 1 && _random.nextDouble() < 0.45) {
          return _randomUntried(history);
        }
        return fits[_random.nextInt(fits.length)];
      case SolverLevel.normal:
        return fits[_random.nextInt(fits.length)];
      case SolverLevel.hard:
        if (history.isEmpty || fits.length <= 2 || fits.length > 2000) {
          return fits[_random.nextInt(fits.length)];
        }
        return _bestSplit(fits);
    }
  }

  Code _randomUntried(List<GuessEntry> history) {
    final tried = history.map((h) => h.guess).toSet();
    while (true) {
      final code = _allCodes[_random.nextInt(_allCodes.length)];
      if (!tried.contains(code)) return code;
    }
  }

  /// Among a sample of fitting codes, the one whose worst-case answer leaves
  /// the fewest possibilities.
  Code _bestSplit(List<Code> fits) {
    final pool = List.of(fits)..shuffle(_random);
    final sample = pool.take(120);
    Code? best;
    var bestWorst = 1 << 30;
    for (final guess in sample) {
      final buckets = <Score, int>{};
      for (final secret in fits) {
        final s = Score.of(secret, guess);
        buckets[s] = (buckets[s] ?? 0) + 1;
      }
      final worst = buckets.values.reduce(max);
      if (worst < bestWorst) {
        bestWorst = worst;
        best = guess;
      }
    }
    return best!;
  }
}
