import 'package:flutter_test/flutter_test.dart';
import 'package:guess_the_number/ui/theme.dart';

void main() {
  test('guessCountLabel uses the singular for one guess', () {
    expect(guessCountLabel(1), '1 guess');
    expect(guessCountLabel(2), '2 guesses');
    expect(guessCountLabel(0), '0 guesses');
  });
}
