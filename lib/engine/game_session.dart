import 'code.dart';
import 'clock.dart';
import 'game_config.dart';
import 'score.dart';

enum GameStatus { notStarted, inProgress, won, lost }

/// Why a lost game ended.
enum LossReason { outOfGuesses, outOfTime, gaveUp }

/// One submitted guess and its feedback.
class GuessEntry {
  final Code guess;
  final Score score;

  /// Time since the game started when this guess was made.
  final Duration elapsed;

  const GuessEntry(this.guess, this.score, this.elapsed);

  Map<String, dynamic> toJson() => {
    'guess': guess.toString(),
    'score': score.toJson(),
    'elapsedMs': elapsed.inMilliseconds,
  };
}

/// Thrown when a guess is submitted to a game that is not accepting guesses.
class GameNotActiveException implements Exception {
  final GameStatus status;
  const GameNotActiveException(this.status);
  @override
  String toString() => 'GameNotActiveException($status)';
}

/// A single player's attempt to crack one secret.
///
/// This is the building block for every mode: free play and levels use one
/// session; a 2-player duel gives each player a session against the other's
/// secret; a race gives each player a session against a shared secret.
class GameSession {
  final GameConfig config;
  final Code secret;
  final Clock clock;

  final List<GuessEntry> _guesses = [];
  GameStatus _status = GameStatus.notStarted;
  LossReason? _lossReason;
  DateTime? _startedAt;
  DateTime? _endedAt;

  GameSession({
    required this.config,
    required this.secret,
    this.clock = systemClock,
  }) {
    if (secret.length != config.digitCount) {
      throw ArgumentError('Secret length does not match config');
    }
  }

  /// Starts a session with a freshly generated secret.
  factory GameSession.random(GameConfig config, {Clock clock = systemClock}) =>
      GameSession(config: config, secret: Code.random(config), clock: clock);

  GameStatus get status => _status;
  LossReason? get lossReason => _lossReason;
  List<GuessEntry> get guesses => List.unmodifiable(_guesses);
  int get guessCount => _guesses.length;
  DateTime? get startedAt => _startedAt;
  DateTime? get endedAt => _endedAt;
  bool get isOver => _status == GameStatus.won || _status == GameStatus.lost;

  int? get guessesRemaining =>
      config.maxGuesses == null ? null : config.maxGuesses! - _guesses.length;

  /// Time played so far, or the final time once the game is over.
  Duration get elapsed {
    if (_startedAt == null) return Duration.zero;
    return (_endedAt ?? clock()).difference(_startedAt!);
  }

  /// Time left under [GameConfig.timeLimit], or null if there is none.
  Duration? get timeRemaining {
    final limit = config.timeLimit;
    if (limit == null) return null;
    final left = limit - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Starts the timer. Called automatically by the first guess, but the UI can
  /// call it earlier (e.g. when the board appears) so thinking time counts.
  void start() {
    if (_status != GameStatus.notStarted) return;
    _startedAt = clock();
    _status = GameStatus.inProgress;
  }

  /// Validates [input] without submitting it. Also rejects repeats of an
  /// earlier guess so a mis-tap doesn't waste a turn.
  GuessRejection? check(String input) {
    final error = Code.validate(input, config);
    if (error != null) return GuessRejection.invalid(error);
    final code = Code.parse(input, config);
    if (_guesses.any((g) => g.guess == code)) {
      return const GuessRejection.alreadyGuessed();
    }
    return null;
  }

  /// Submits a guess and returns its score. Throws [InvalidCodeException] for
  /// malformed input and [GameNotActiveException] if the game is over.
  /// Use [check] first to give the player friendly feedback.
  GuessEntry submit(String input) {
    start();
    checkTimeout();
    if (isOver) throw GameNotActiveException(_status);

    final guess = Code.parse(input, config);
    final entry = GuessEntry(guess, Score.of(secret, guess), elapsed);
    _guesses.add(entry);

    if (entry.score.isSolved(config.digitCount)) {
      _finish(GameStatus.won);
    } else if (guessesRemaining == 0) {
      _finish(GameStatus.lost, LossReason.outOfGuesses);
    }
    return entry;
  }

  /// Ends the game if the time limit has passed. Call from a UI ticker.
  /// Returns true if the game ended because of this call.
  bool checkTimeout() {
    if (_status != GameStatus.inProgress) return false;
    final limit = config.timeLimit;
    if (limit != null && elapsed >= limit) {
      _finish(GameStatus.lost, LossReason.outOfTime, _startedAt!.add(limit));
      return true;
    }
    return false;
  }

  /// The player gives up; the secret can then be revealed.
  void giveUp() {
    if (isOver) return;
    start();
    _finish(GameStatus.lost, LossReason.gaveUp);
  }

  void _finish(GameStatus status, [LossReason? reason, DateTime? at]) {
    _status = status;
    _lossReason = reason;
    _endedAt = at ?? clock();
  }

  /// A summary for stats and records, available once the game is over.
  GameResult get result {
    if (!isOver) throw StateError('Game is not over');
    return GameResult(
      config: config,
      won: _status == GameStatus.won,
      guessCount: guessCount,
      duration: elapsed,
      finishedAt: _endedAt!,
      lossReason: _lossReason,
    );
  }
}

/// Why [GameSession.check] refused a guess.
class GuessRejection {
  final CodeError? codeError;
  final bool alreadyGuessed;

  const GuessRejection.invalid(CodeError this.codeError)
    : alreadyGuessed = false;
  const GuessRejection.alreadyGuessed()
    : codeError = null,
      alreadyGuessed = true;

  @override
  String toString() => alreadyGuessed
      ? 'GuessRejection(alreadyGuessed)'
      : 'GuessRejection($codeError)';
}

/// The outcome of a finished game, as stored for stats and best records.
class GameResult {
  final GameConfig config;
  final bool won;
  final int guessCount;
  final Duration duration;
  final DateTime finishedAt;
  final LossReason? lossReason;

  /// Set when the game was played as a level.
  final String? levelId;

  const GameResult({
    required this.config,
    required this.won,
    required this.guessCount,
    required this.duration,
    required this.finishedAt,
    this.lossReason,
    this.levelId,
  });

  GameResult withLevel(String id) => GameResult(
    config: config,
    won: won,
    guessCount: guessCount,
    duration: duration,
    finishedAt: finishedAt,
    lossReason: lossReason,
    levelId: id,
  );

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'won': won,
    'guessCount': guessCount,
    'durationMs': duration.inMilliseconds,
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    if (lossReason != null) 'lossReason': lossReason!.name,
    if (levelId != null) 'levelId': levelId,
  };

  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
    config: GameConfig.fromJson(json['config'] as Map<String, dynamic>),
    won: json['won'] as bool,
    guessCount: json['guessCount'] as int,
    duration: Duration(milliseconds: json['durationMs'] as int),
    finishedAt: DateTime.parse(json['finishedAt'] as String),
    lossReason: json['lossReason'] == null
        ? null
        : LossReason.values.byName(json['lossReason'] as String),
    levelId: json['levelId'] as String?,
  );
}
