import 'dart:math';

import 'package:meta/meta.dart';

import 'game_config.dart';

/// Why a candidate number is not a valid secret or guess.
enum CodeError {
  /// Wrong number of digits for the game.
  wrongLength,

  /// Contains something other than the digits 1-9 (including 0).
  invalidCharacter,

  /// The same digit appears more than once.
  repeatedDigit,
}

/// Thrown when building a [Code] from invalid input.
class InvalidCodeException implements Exception {
  final CodeError error;
  final String input;
  const InvalidCodeException(this.error, this.input);

  @override
  String toString() => 'InvalidCodeException($error, "$input")';
}

/// A valid sequence of distinct digits 1-9. Used for both secrets and guesses.
@immutable
class Code {
  final List<int> digits;

  Code._(List<int> digits) : digits = List.unmodifiable(digits);

  int get length => digits.length;

  /// Checks [input] against [config] without throwing. Returns null when valid.
  static CodeError? validate(String input, GameConfig config) {
    final text = input.trim();
    for (final ch in text.split('')) {
      final d = int.tryParse(ch);
      if (d == null || !GameConfig.allowedDigits.contains(d)) {
        return CodeError.invalidCharacter;
      }
    }
    if (text.length != config.digitCount) return CodeError.wrongLength;
    if (text.split('').toSet().length != text.length) {
      return CodeError.repeatedDigit;
    }
    return null;
  }

  /// Parses [input] such as "1234". Throws [InvalidCodeException] if invalid.
  factory Code.parse(String input, GameConfig config) {
    final error = validate(input, config);
    if (error != null) throw InvalidCodeException(error, input);
    return Code._(input.trim().split('').map(int.parse).toList());
  }

  /// Generates a random secret for [config]. Pass a seeded [random] for
  /// deterministic tests or daily challenges.
  factory Code.random(GameConfig config, {Random? random}) {
    final pool = List<int>.of(GameConfig.allowedDigits)
      ..shuffle(random ?? Random.secure());
    return Code._(pool.take(config.digitCount).toList());
  }

  @override
  String toString() => digits.join();

  @override
  bool operator ==(Object other) =>
      other is Code && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}
