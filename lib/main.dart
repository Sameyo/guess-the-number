import 'package:flutter/material.dart';

import 'engine.dart';

void main() => runApp(const GuessTheNumberApp());

class GuessTheNumberApp extends StatelessWidget {
  const GuessTheNumberApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Guess the Number',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: const PlaceholderGameScreen(),
  );
}

/// Minimal screen to exercise the engine. The real UI comes in step 2.
class PlaceholderGameScreen extends StatefulWidget {
  const PlaceholderGameScreen({super.key});

  @override
  State<PlaceholderGameScreen> createState() => _PlaceholderGameScreenState();
}

class _PlaceholderGameScreenState extends State<PlaceholderGameScreen> {
  GameSession _game = GameSession.random(GameConfig.standard);
  final _controller = TextEditingController();
  String? _error;

  void _submit() {
    final rejection = _game.check(_controller.text);
    setState(() {
      if (rejection != null) {
        _error = rejection.alreadyGuessed
            ? 'Already guessed'
            : switch (rejection.codeError!) {
                CodeError.wrongLength =>
                  'Enter ${_game.config.digitCount} digits',
                CodeError.invalidCharacter => 'Use digits 1-9 only',
                CodeError.repeatedDigit => 'No repeated digits',
              };
        return;
      }
      _error = null;
      _game.submit(_controller.text);
      _controller.clear();
    });
  }

  void _newGame() => setState(() {
    _game = GameSession.random(GameConfig.standard);
    _error = null;
  });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final won = _game.status == GameStatus.won;
    return Scaffold(
      appBar: AppBar(title: const Text('Guess the Number')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (won)
              Text('Solved ${_game.secret} in ${_game.guessCount} guesses!')
            else
              TextField(
                key: const Key('guessField'),
                controller: _controller,
                keyboardType: TextInputType.number,
                maxLength: _game.config.digitCount,
                decoration: InputDecoration(
                  labelText: 'Your guess',
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(child: Text('Guess')),
                SizedBox(width: 40, child: Text('I')),
                SizedBox(width: 40, child: Text('P')),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final g in _game.guesses.reversed)
                    Row(
                      children: [
                        Expanded(child: Text('${g.guess}')),
                        SizedBox(
                          width: 40,
                          child: Text('${g.score.identified}'),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text('${g.score.inPosition}'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: won ? _newGame : _submit,
        child: Icon(won ? Icons.refresh : Icons.check),
      ),
    );
  }
}
