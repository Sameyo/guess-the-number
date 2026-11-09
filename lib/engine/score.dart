import 'package:meta/meta.dart';

import 'code.dart';

/// Feedback for one guess, matching the paper game's columns:
/// I = how many of the secret's digits appear anywhere in the guess,
/// P = how many of those are also in the right position.
@immutable
class Score {
  final int identified;
  final int inPosition;

  const Score({required this.identified, required this.inPosition})
    : assert(inPosition <= identified);

  /// Scores [guess] against [secret]. Both must be the same length.
  factory Score.of(Code secret, Code guess) {
    if (secret.length != guess.length) {
      throw ArgumentError('Secret and guess lengths differ');
    }
    final secretDigits = secret.digits.toSet();
    var identified = 0;
    var inPosition = 0;
    for (var i = 0; i < guess.length; i++) {
      if (secretDigits.contains(guess.digits[i])) {
        identified++;
        if (secret.digits[i] == guess.digits[i]) inPosition++;
      }
    }
    return Score(identified: identified, inPosition: inPosition);
  }

  /// True when every digit is found and in place.
  bool isSolved(int digitCount) => inPosition == digitCount;

  Map<String, dynamic> toJson() => {'i': identified, 'p': inPosition};

  factory Score.fromJson(Map<String, dynamic> json) =>
      Score(identified: json['i'] as int, inPosition: json['p'] as int);

  @override
  bool operator ==(Object other) =>
      other is Score &&
      other.identified == identified &&
      other.inPosition == inPosition;

  @override
  int get hashCode => Object.hash(identified, inPosition);

  @override
  String toString() => 'I$identified P$inPosition';
}
