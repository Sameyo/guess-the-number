import 'package:flutter/material.dart';

import '../app/store.dart';
import '../engine.dart';
import 'theme.dart';
import 'widgets.dart';

String rejectionMessage(GuessRejection r, int digitCount) => r.alreadyGuessed
    ? 'You already tried that one'
    : switch (r.codeError!) {
        CodeError.wrongLength => 'Enter $digitCount digits',
        CodeError.invalidCharacter => 'Use digits 1-9 only',
        CodeError.repeatedDigit => 'No repeated digits',
      };

/// Single-player game: free play, or one level when [level] is set.
class SoloGameScreen extends StatefulWidget {
  final GameSession session;
  final Level? level;
  final DigitNotes notes;
  const SoloGameScreen({
    super.key,
    required this.session,
    this.level,
    this.notes = const {},
  });

  /// Rebuilds a screen from a saved game.
  factory SoloGameScreen.restore(SavedGame saved) {
    final levelId = saved.data['levelId'] as String?;
    return SoloGameScreen(
      session: GameSession.fromJson(
        saved.data['session'] as Map<String, dynamic>,
      ),
      level: levelId == null
          ? null
          : defaultLevelPath.firstWhere((l) => l.id == levelId),
      notes: notesFromJson(saved.data['notes']),
    );
  }

  @override
  State<SoloGameScreen> createState() => _SoloGameScreenState();
}

class _SoloGameScreenState extends State<SoloGameScreen>
    with WidgetsBindingObserver {
  late GameSession _game = widget.session;
  late DigitNotes _notes = {...widget.notes};
  bool _finished = false;
  late final AppStore _store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game
      ..start()
      ..resume();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = StoreScope.read(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Deferred: the store notifies listeners, which isn't allowed mid-dispose.
    Future.microtask(_saveIfUnfinished);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _game.resume();
    } else if (state == AppLifecycleState.paused) {
      // Stop the clock while the app is in the background.
      _saveIfUnfinished();
      _game.pause();
    }
  }

  void _saveIfUnfinished() {
    if (_game.isOver) return;
    if (_game.guessCount == 0) {
      // Nothing worth resuming yet.
      if (_store.savedGame?.kind == _kind) _store.clearSavedGame();
      return;
    }
    _store.saveGame(_kind, {
      'session': _game.toJson(),
      if (widget.level != null) 'levelId': widget.level!.id,
      'notes': notesToJson(_notes),
    });
  }

  GameKind get _kind => widget.level == null ? GameKind.solo : GameKind.level;

  String? _submit(String guess) {
    final rejection = _game.check(guess);
    if (rejection != null) {
      return rejectionMessage(rejection, _game.config.digitCount);
    }
    buzz(context, strong: true);
    setState(() => _game.submit(guess));
    if (_game.isOver) {
      _finish();
    } else {
      _saveIfUnfinished();
    }
    return null;
  }

  void _onTick() {
    if (_game.checkTimeout()) {
      setState(() {});
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    await _store.clearSavedGame();
    final result = _game.result;
    final records = _store.stats.newRecordsFor(result);
    int? stars;
    if (widget.level != null) {
      stars = await _store.recordLevel(widget.level!, result);
    } else {
      await _store.recordResult(result);
    }
    if (!mounted) return;
    final again = await showResultDialog(
      context,
      won: result.won,
      title: result.won
          ? 'Cracked it!'
          : switch (result.lossReason) {
              LossReason.outOfTime => 'Out of time',
              LossReason.outOfGuesses => 'Out of guesses',
              _ => 'Better luck next time',
            },
      secret: _game.secret,
      lines: [
        '${guessCountLabel(result.guessCount)} in ${formatDuration(result.duration)}',
        if (widget.level == null && records.fewestGuesses)
          'New record: fewest guesses!',
        if (widget.level == null && records.fastestTime)
          'New record: fastest time!',
      ],
      stars: stars,
    );
    if (!mounted) return;
    if (again == true) {
      setState(() {
        _game = GameSession.random(_game.config)..start();
        _notes = {};
        _finished = false;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _giveUp() async {
    final ok = await confirm(
      context,
      'Give up?',
      'The number will be revealed and this counts as a loss.',
      'Give up',
    );
    if (ok != true) return;
    setState(_game.giveUp);
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _game.config;
    final level = widget.level;
    final guesses = _game.guesses;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          level == null
              ? '${cfg.digitCount}-digit game'
              : 'Level ${level.number}',
        ),
        actions: [
          IconButton(
            tooltip: 'How to play',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showHowToPlay(context),
          ),
          IconButton(
            key: const Key('giveUp'),
            tooltip: 'Give up',
            icon: const Icon(Icons.flag_outlined),
            onPressed: _game.isOver ? null : _giveUp,
          ),
        ],
      ),
      body: GraphPaper(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
          child: Column(
            children: [
              Row(
                children: [
                  TimerChip(
                    elapsed: () => _game.elapsed,
                    limit: cfg.timeLimit,
                    onTick: _onTick,
                  ),
                  HudChip(
                    icon: Icons.tag,
                    value: cfg.maxGuesses == null
                        ? '${_game.guessCount}'
                        : '${_game.guessCount}/${cfg.maxGuesses}',
                    caption: 'guesses',
                    color: Palette.violet,
                    valueKey: const Key('stepCounter'),
                  ),
                  if (level != null)
                    HudChip(
                      icon: Icons.star_rounded,
                      value: '≤${level.threeStarGuesses}',
                      caption: 'for 3 stars',
                      color: Palette.sun,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              BoardHeader(digitCount: cfg.digitCount),
              Expanded(
                child: guesses.isEmpty
                    ? const _EmptyBoard()
                    : ListView.builder(
                        reverse: true,
                        itemCount: guesses.length,
                        itemBuilder: (context, i) {
                          final index = guesses.length - 1 - i;
                          return GuessRow(
                            key: ValueKey('row$index'),
                            number: index + 1,
                            entry: guesses[index],
                            animate: i == 0,
                            solved: guesses[index].score.isSolved(
                              cfg.digitCount,
                            ),
                          );
                        },
                      ),
              ),
              NotesPad(
                notes: _notes,
                onTap: (d) => setState(
                  () => _notes[d] = (_notes[d] ?? DigitMark.unknown).next,
                ),
              ),
              const SizedBox(height: 6),
              GuessInput(
                digitCount: cfg.digitCount,
                notes: _notes,
                enabled: !_game.isOver,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'I = digits in the number\nP = of those, how many are in the right place\n\nTap digits on the notes row to cross them out.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Palette.inkSoft,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    ),
  );
}

Future<bool?> confirm(
  BuildContext context,
  String title,
  String body,
  String action,
) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text(body),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('confirm'),
        onPressed: () => Navigator.pop(context, true),
        child: Text(action),
      ),
    ],
  ),
);

/// End-of-game card with confetti on a win. Returns true for "play again".
Future<bool?> showResultDialog(
  BuildContext context, {
  required bool won,
  required String title,
  required Code secret,
  required List<String> lines,
  int? stars,
  String? secretLabel,
  Code? otherSecret,
  String? otherSecretLabel,
}) => showGeneralDialog<bool>(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.black38,
  transitionDuration: const Duration(milliseconds: 350),
  transitionBuilder: (context, a, _, child) => ScaleTransition(
    scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
    child: child,
  ),
  pageBuilder: (context, _, _) => Stack(
    children: [
      if (won) const Positioned.fill(child: Confetti()),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Palette.paper,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(won ? '🎉' : '🤔', style: const TextStyle(fontSize: 44)),
                  Text(
                    title,
                    key: const Key('resultTitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: won ? Palette.inPosition : Palette.coral,
                    ),
                  ),
                  if (stars != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Icon(
                            Icons.star_rounded,
                            size: 40,
                            color: i < stars
                                ? Palette.sun
                                : Palette.gridLineBold,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _SecretLine(secretLabel ?? 'The number', secret),
                  if (otherSecret != null)
                    _SecretLine(otherSecretLabel ?? '', otherSecret),
                  const SizedBox(height: 12),
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        line,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: line.startsWith('New record')
                              ? Palette.violet
                              : Palette.ink,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('resultHome'),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Home'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('playAgain'),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Play again'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);

class _SecretLine extends StatelessWidget {
  final String label;
  final Code secret;
  const _SecretLine(this.label, this.secret);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Palette.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final d in secret.digits) DigitTile(d, size: 38)],
          ),
        ),
      ],
    ),
  );
}

void showHowToPlay(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Palette.paper,
  showDragHandle: true,
  builder: (context) => const Padding(
    padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to play',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 12),
        Text(
          'There is a secret number made of different digits from 1 to 9 (no 0, no repeats).\n\n'
          'After each guess you get two clues:\n'
          '  • I: how many of your digits are in the number\n'
          '  • P: how many of those are also in the right place\n\n'
          'Keep going until P equals the number of digits.\n\n'
          'Notes row: tap a digit once to cross it out, twice to mark it as in the number.',
          style: TextStyle(height: 1.45, fontSize: 15),
        ),
      ],
    ),
  ),
);
