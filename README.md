# Guess the Number

A number-guessing game for iOS and Android, built with Flutter.

The game picks a secret number (4 digits by default, 3 to 9 configurable) using
the digits 1-9 with no repeats. After each guess you get two numbers:

- **I** (identified): how many of the secret's digits appear in your guess
- **P** (position): how many of those are also in the right place

You win when P equals the number of digits.

## Project layout

- `lib/engine/` is the pure-Dart game engine (no Flutter imports), exported from `lib/engine.dart`:
  - `code.dart`: secrets and guesses, validation, random generation
  - `score.dart`: I/P scoring
  - `game_session.dart`: one player's game, with timer, guess/time limits and a `GameResult`
  - `stats.dart`: win rate, best records (fewest guesses, fastest time), streaks
  - `levels.dart`: level path (3 to 6 digits, guess limits, timers), 1-3 stars, unlocks
  - `multiplayer.dart`: 2-player duel (guess each other's number) and race (same number)
- `lib/main.dart` is a placeholder screen; the real UI comes next.

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```
