import 'dart:math';

import 'package:guess_the_number/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const four = GameConfig.standard;

  group('Code.validate', () {
    test('accepts distinct digits 1-9 of the right length', () {
      expect(Code.validate('1234', four), isNull);
      expect(Code.validate(' 9876 ', four), isNull);
    });
    test(
      'rejects zero',
      () => expect(Code.validate('1204', four), CodeError.invalidCharacter),
    );
    test(
      'rejects non-digits',
      () => expect(Code.validate('12a4', four), CodeError.invalidCharacter),
    );
    test('rejects wrong length', () {
      expect(Code.validate('123', four), CodeError.wrongLength);
      expect(Code.validate('12345', four), CodeError.wrongLength);
      expect(Code.validate('', four), CodeError.wrongLength);
    });
    test(
      'rejects repeats',
      () => expect(Code.validate('1123', four), CodeError.repeatedDigit),
    );
    test('respects configured digit count', () {
      expect(Code.validate('123', const GameConfig(digitCount: 3)), isNull);
      expect(Code.validate('123456', const GameConfig(digitCount: 6)), isNull);
    });
    test('parse throws on invalid input', () {
      expect(
        () => Code.parse('0123', four),
        throwsA(isA<InvalidCodeException>()),
      );
    });
  });

  group('Code.random', () {
    test('always produces valid secrets for every digit count', () {
      final rng = Random(42);
      for (var n = GameConfig.minDigits; n <= GameConfig.maxDigits; n++) {
        final config = GameConfig(digitCount: n);
        for (var i = 0; i < 200; i++) {
          final s = Code.random(config, random: rng);
          expect(Code.validate(s.toString(), config), isNull, reason: '$s');
        }
      }
    });
    test('is deterministic with a seeded Random', () {
      expect(
        Code.random(four, random: Random(7)),
        Code.random(four, random: Random(7)),
      );
    });
  });

  group('Score', () {
    Score score(String secret, String guess) =>
        Score.of(Code.parse(secret, four), Code.parse(guess, four));

    test(
      'nothing in common',
      () => expect(
        score('1234', '5678'),
        const Score(identified: 0, inPosition: 0),
      ),
    );
    test(
      'all found, none in place',
      () => expect(
        score('1234', '4321'),
        const Score(identified: 4, inPosition: 0),
      ),
    );
    test('solved', () {
      final s = score('1234', '1234');
      expect(s, const Score(identified: 4, inPosition: 4));
      expect(s.isSolved(4), isTrue);
    });
    test('mixed', () {
      // 1 in place, 3 and 2 present elsewhere, 5 absent.
      expect(score('1234', '1352'), const Score(identified: 3, inPosition: 1));
    });
    test('works for other lengths', () {
      const six = GameConfig(digitCount: 6);
      expect(
        Score.of(Code.parse('123456', six), Code.parse('654789', six)),
        const Score(identified: 3, inPosition: 0),
      );
    });
    test('json round trip', () {
      const s = Score(identified: 3, inPosition: 1);
      expect(Score.fromJson(s.toJson()), s);
    });
  });
}
