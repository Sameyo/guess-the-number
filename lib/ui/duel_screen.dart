import 'dart:async';

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../engine.dart';
import 'solo_game_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Who player B is in a duel.
enum Opponent { kutir, local }

const kutirName = 'Kutir';

/// Both players pick a secret, then take turns guessing each other's.
/// Player A is always the person holding the phone (or Player 1).
class DuelScreen extends StatefulWidget {
  final DuelMatch match;
  final Opponent opponent;
  final List<String> names;
  final SolverLevel kutirLevel;
  final Map<PlayerSlot, DigitNotes> notes;

  const DuelScreen({
    super.key,
    required this.match,
    required this.opponent,
    required this.names,
    this.kutirLevel = SolverLevel.normal,
    this.notes = const {},
  });

  factory DuelScreen.restore(SavedGame saved) {
    final d = saved.data;
    return DuelScreen(
      match: DuelMatch.fromJson(d['match'] as Map<String, dynamic>),
      opponent: saved.kind == GameKind.kutir ? Opponent.kutir : Opponent.local,
      names: (d['names'] as List).cast<String>(),
      kutirLevel: SolverLevel.values.byName(
        d['kutirLevel'] as String? ?? 'normal',
      ),
      notes: {
        PlayerSlot.a: notesFromJson(d['notesA']),
        PlayerSlot.b: notesFromJson(d['notesB']),
      },
    );
  }

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> with WidgetsBindingObserver {
  DuelMatch get _match => widget.match;
  late final Map<PlayerSlot, DigitNotes> _notes = {
    for (final p in PlayerSlot.values) p: {...?widget.notes[p]},
  };
  late final Solver? _kutir = widget.opponent == Opponent.kutir
      ? Solver(_match.config, level: widget.kutirLevel)
      : null;
  late final AppStore _store;
  Timer? _kutirTimer;
  bool _showMySecret = false;
  bool _finished = false;

  bool get _vsKutir => widget.opponent == Opponent.kutir;
  GameKind get _kind => _vsKutir ? GameKind.kutir : GameKind.local;
  String _name(PlayerSlot p) => widget.names[p.index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _match
      ..start()
      ..resumeClocks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_match.outcome != null) {
        _finish();
      } else {
        _maybeKutirMove();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = StoreScope.read(context);
  }

  @override
  void dispose() {
    _kutirTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Deferred: the store notifies listeners, which isn't allowed mid-dispose.
    Future.microtask(_save);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _match.resumeClocks();
    } else if (state == AppLifecycleState.paused) {
      _save();
      _match.pauseClocks();
    }
  }

  void _save() {
    if (_match.outcome != null) return;
    final played = PlayerSlot.values.any(
      (p) => _match.sessionOf(p).guessCount > 0,
    );
    if (!played) return;
    _store.saveGame(_kind, {
      'match': _match.toJson(),
      'names': widget.names,
      'kutirLevel': widget.kutirLevel.name,
      'notesA': notesToJson(_notes[PlayerSlot.a]!),
      'notesB': notesToJson(_notes[PlayerSlot.b]!),
    });
  }

  String? _submit(String guess) {
    final me = _match.currentTurn;
    final rejection = _match.sessionOf(me).check(guess);
    if (rejection != null) {
      return rejectionMessage(rejection, _match.config.digitCount);
    }
    buzz(context, strong: true);
    setState(() => _match.submit(me, guess));
    _afterMove();
    return null;
  }

  void _afterMove() {
    if (_match.outcome != null) {
      _finish();
      return;
    }
    _save();
    _maybeKutirMove();
  }

  void _maybeKutirMove() {
    final kutir = _kutir;
    if (kutir == null || _match.outcome != null) return;
    if (_match.currentTurn != PlayerSlot.b) return;
    _kutirTimer?.cancel();
    _kutirTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _match.outcome != null) return;
      final guess = kutir.nextGuess(_match.sessionOf(PlayerSlot.b).guesses);
      setState(() => _match.submit(PlayerSlot.b, guess.toString()));
      _afterMove();
    });
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    final outcome = _match.outcome!;
    await _store.clearSavedGame();
    if (_vsKutir) await _store.recordKutirMatch(outcome);
    if (!mounted) return;
    final a = _match.sessionOf(PlayerSlot.a);
    final b = _match.sessionOf(PlayerSlot.b);
    final title = outcome.isDraw
        ? "It's a draw!"
        : _vsKutir
        ? (outcome.winner == PlayerSlot.a
              ? 'You beat Kutir!'
              : 'Kutir wins this time')
        : '${_name(outcome.winner!)} wins!';
    String line(PlayerSlot p, GameSession s) {
      final who = _vsKutir && p == PlayerSlot.a ? 'You' : _name(p);
      return s.status == GameStatus.won
          ? '$who cracked it in ${guessCountLabel(s.guessCount)}'
          : '$who made ${guessCountLabel(s.guessCount)}';
    }

    final again = await showResultDialog(
      context,
      won: !_vsKutir || outcome.winner == PlayerSlot.a,
      title: title,
      secret: b.secret,
      secretLabel: _vsKutir
          ? "Kutir's number"
          : "${_name(PlayerSlot.a)}'s target (${_name(PlayerSlot.b)}'s number)",
      otherSecret: a.secret,
      otherSecretLabel: _vsKutir
          ? 'Your number'
          : "${_name(PlayerSlot.b)}'s target (${_name(PlayerSlot.a)}'s number)",
      lines: [
        line(PlayerSlot.a, a),
        line(PlayerSlot.b, b),
        'Time ${formatDuration(a.elapsed)}',
        if (_vsKutir)
          'Overall vs Kutir: ${_store.kutirTally.wins}W ${_store.kutirTally.losses}L ${_store.kutirTally.draws}D',
      ],
    );
    if (!mounted) return;
    if (again == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SecretSetupScreen(
            opponent: widget.opponent,
            config: _match.config,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _match.config;
    final turn = _match.currentTurn;
    final humanTurn = !_vsKutir || turn == PlayerSlot.a;
    final over = _match.outcome != null;
    final round = PlayerSlot.values
        .map((p) => _match.sessionOf(p).guessCount)
        .reduce((x, y) => x > y ? x : y);
    final turnColor = turn == PlayerSlot.a ? Palette.teal : Palette.pink;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _vsKutir
              ? 'vs Kutir'
              : '${_name(PlayerSlot.a)} vs ${_name(PlayerSlot.b)}',
        ),
        actions: [
          IconButton(
            tooltip: 'How to play',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showHowToPlay(context),
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
                    elapsed: () => _match.sessionOf(PlayerSlot.a).elapsed,
                  ),
                  HudChip(
                    icon: Icons.tag,
                    value: '$round',
                    caption: 'round',
                    color: Palette.violet,
                    valueKey: const Key('stepCounter'),
                  ),
                  HudChip(
                    icon: humanTurn ? Icons.person : Icons.smart_toy,
                    value: over
                        ? 'Done'
                        : (_vsKutir
                              ? (humanTurn ? 'You' : 'Kutir')
                              : 'P${turn.index + 1}'),
                    caption: 'turn',
                    color: turnColor,
                  ),
                ],
              ),
              if (_vsKutir) _mySecretBar(),
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Board(
                        title: _vsKutir
                            ? "You → Kutir's number"
                            : '${_name(PlayerSlot.a)} guesses',
                        color: Palette.teal,
                        session: _match.sessionOf(PlayerSlot.a),
                        active: turn == PlayerSlot.a && !over,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _Board(
                        title: _vsKutir
                            ? 'Kutir → your number'
                            : '${_name(PlayerSlot.b)} guesses',
                        color: Palette.pink,
                        session: _match.sessionOf(PlayerSlot.b),
                        active: turn == PlayerSlot.b && !over,
                        thinking: _vsKutir && turn == PlayerSlot.b && !over,
                      ),
                    ),
                  ],
                ),
              ),
              NotesPad(
                notes: _notes[humanTurn ? turn : PlayerSlot.a]!,
                onTap: (d) => setState(() {
                  final n = _notes[humanTurn ? turn : PlayerSlot.a]!;
                  n[d] = (n[d] ?? DigitMark.unknown).next;
                }),
              ),
              const SizedBox(height: 6),
              GuessInput(
                key: ValueKey('input-$turn'),
                digitCount: cfg.digitCount,
                notes: _notes[humanTurn ? turn : PlayerSlot.a]!,
                enabled: humanTurn && !over,
                submitLabel: _vsKutir
                    ? 'GO'
                    : 'GO ${_name(turn).toUpperCase()}',
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mySecretBar() => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: InkWell(
      onTap: () => setState(() => _showMySecret = !_showMySecret),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Your number: ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Palette.inkSoft,
              ),
            ),
            for (final d in _match.sessionOf(PlayerSlot.b).secret.digits)
              DigitTile(d, size: 22, hidden: !_showMySecret),
            const SizedBox(width: 6),
            Icon(
              _showMySecret ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: Palette.inkSoft,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Board extends StatelessWidget {
  final String title;
  final Color color;
  final GameSession session;
  final bool active;
  final bool thinking;
  const _Board({
    required this.title,
    required this.color,
    required this.session,
    required this.active,
    this.thinking = false,
  });

  @override
  Widget build(BuildContext context) {
    final guesses = session.guesses;
    const tile = 20.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.12 : 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: active ? 1 : 0.35),
          width: active ? 2.5 : 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          BoardHeader(digitCount: session.config.digitCount, tileSize: tile),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: guesses.length + (thinking ? 1 : 0),
              itemBuilder: (context, i) {
                if (thinking && i == 0) return const _Thinking();
                final index = guesses.length - 1 - (i - (thinking ? 1 : 0));
                return GuessRow(
                  key: ValueKey('${session.hashCode}-$index'),
                  number: index + 1,
                  entry: guesses[index],
                  tileSize: tile,
                  animate: index == guesses.length - 1,
                  solved: guesses[index].score.isSolved(
                    session.config.digitCount,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Palette.pink),
        ),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            'Kutir is thinking…',
            style: TextStyle(
              color: Palette.pink,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Picks the secrets before a duel. Against Kutir you pick yours and Kutir
/// picks one at random; in pass-and-play each player picks theirs in turn.
class SecretSetupScreen extends StatefulWidget {
  final Opponent opponent;
  final GameConfig config;
  const SecretSetupScreen({
    super.key,
    required this.opponent,
    required this.config,
  });

  @override
  State<SecretSetupScreen> createState() => _SecretSetupScreenState();
}

class _SecretSetupScreenState extends State<SecretSetupScreen> {
  final _inputKey = GlobalKey<GuessInputState>();
  final _names = ['Player 1', 'Player 2'];
  Code? _secretA;
  bool _handover = false;
  bool _hide = true;

  bool get _vsKutir => widget.opponent == Opponent.kutir;
  int get _step => _secretA == null ? 0 : 1;

  String? _lock(String input) {
    final code = Code.parse(input, widget.config);
    if (_vsKutir) {
      _start(code, Code.random(widget.config));
    } else if (_secretA == null) {
      setState(() {
        _secretA = code;
        _handover = true;
      });
    } else {
      _start(_secretA!, code);
    }
    return null;
  }

  void _start(Code a, Code b) {
    final store = StoreScope.read(context);
    store.clearSavedGame();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DuelScreen(
          match: DuelMatch(config: widget.config, secretOfA: a, secretOfB: b),
          opponent: widget.opponent,
          names: _vsKutir ? ['You', kutirName] : _names,
          kutirLevel: store.kutirLevel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final who = _vsKutir ? 'your' : "${_names[_step]}'s";
    return Scaffold(
      appBar: AppBar(title: Text(_vsKutir ? 'vs Kutir' : 'Pass & play')),
      body: GraphPaper(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
          child: _handover
              ? _HandoverCard(
                  name: _names[1],
                  onReady: () => setState(() => _handover = false),
                )
              : Column(
                  children: [
                    Text(
                      _vsKutir ? '🤖' : (_step == 0 ? '🙂' : '😎'),
                      style: const TextStyle(fontSize: 54),
                    ),
                    Text(
                      'Pick $who secret number',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _vsKutir
                          ? 'Kutir will try to crack it while you crack Kutir\'s. You go first; if you solve it, Kutir gets one last turn to tie.'
                          : 'Keep it hidden from the other player. ${widget.config.digitCount} different digits, 1-9.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Palette.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          key: const Key('randomSecret'),
                          onPressed: () => _inputKey.currentState?.setDigits(
                            Code.random(widget.config).digits,
                          ),
                          icon: const Icon(Icons.casino_outlined),
                          label: const Text('Random'),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _hide = !_hide),
                          icon: Icon(
                            _hide ? Icons.visibility : Icons.visibility_off,
                          ),
                          label: Text(_hide ? 'Show' : 'Hide'),
                        ),
                      ],
                    ),
                    GuessInput(
                      key: _inputKey,
                      digitCount: widget.config.digitCount,
                      hideDigits: _hide,
                      submitLabel: 'LOCK IN',
                      onSubmit: _lock,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HandoverCard extends StatelessWidget {
  final String name;
  final VoidCallback onReady;
  const _HandoverCard({required this.name, required this.onReady});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('📱➡️', style: TextStyle(fontSize: 54)),
        Text(
          'Pass the phone to $name',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('handoverReady'),
          onPressed: onReady,
          child: Text("I'm $name"),
        ),
      ],
    ),
  );
}
