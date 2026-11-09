import 'package:meta/meta.dart';

/// Rules for one game. Immutable and JSON-serializable so it can be stored
/// with records or shared with an opponent over the network.
@immutable
class GameConfig {
  /// Smallest and largest supported number length. With digits 1-9 and no
  /// repeats, 9 is the hard ceiling.
  static const int minDigits = 3;
  static const int maxDigits = 9;

  /// How many digits the secret has.
  final int digitCount;

  /// Optional cap on guesses; the game is lost when it is reached.
  final int? maxGuesses;

  /// Optional time limit; the game is lost when it runs out.
  final Duration? timeLimit;

  const GameConfig({this.digitCount = 4, this.maxGuesses, this.timeLimit})
    : assert(digitCount >= minDigits && digitCount <= maxDigits),
      assert(maxGuesses == null || maxGuesses > 0);

  /// The classic 4-digit game with no limits.
  static const GameConfig standard = GameConfig();

  /// Digits a secret or guess may contain.
  static const List<int> allowedDigits = [1, 2, 3, 4, 5, 6, 7, 8, 9];

  GameConfig copyWith({
    int? digitCount,
    int? maxGuesses,
    Duration? timeLimit,
  }) => GameConfig(
    digitCount: digitCount ?? this.digitCount,
    maxGuesses: maxGuesses ?? this.maxGuesses,
    timeLimit: timeLimit ?? this.timeLimit,
  );

  Map<String, dynamic> toJson() => {
    'digitCount': digitCount,
    if (maxGuesses != null) 'maxGuesses': maxGuesses,
    if (timeLimit != null) 'timeLimitMs': timeLimit!.inMilliseconds,
  };

  factory GameConfig.fromJson(Map<String, dynamic> json) => GameConfig(
    digitCount: json['digitCount'] as int,
    maxGuesses: json['maxGuesses'] as int?,
    timeLimit: json['timeLimitMs'] == null
        ? null
        : Duration(milliseconds: json['timeLimitMs'] as int),
  );

  @override
  bool operator ==(Object other) =>
      other is GameConfig &&
      other.digitCount == digitCount &&
      other.maxGuesses == maxGuesses &&
      other.timeLimit == timeLimit;

  @override
  int get hashCode => Object.hash(digitCount, maxGuesses, timeLimit);

  @override
  String toString() =>
      'GameConfig(digits: $digitCount, maxGuesses: $maxGuesses, timeLimit: $timeLimit)';
}
