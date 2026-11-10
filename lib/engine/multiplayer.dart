import 'clock.dart';
import 'code.dart';
import 'game_config.dart';
import 'game_session.dart';

/// The two 2-player modes.
enum MatchMode {
  /// Each player picks a secret and they take turns guessing the other's.
  duel,

  /// Both players race to crack the same random secret.
  race,
}

enum PlayerSlot {
  a,
  b;

  PlayerSlot get other => this == a ? b : a;
}

enum MatchStatus { inProgress, finished }

/// Final outcome of a match. [winner] is null for a draw.
class MatchOutcome {
  final PlayerSlot? winner;
  const MatchOutcome(this.winner);
  bool get isDraw => winner == null;
}

/// Shared shape of both modes so the UI and the Firebase layer (step 3) can
/// treat them the same way. Each player has a [GameSession] against the secret
/// they are trying to crack.
abstract class Match {
  MatchMode get mode;
  GameConfig get config;
  GameSession sessionOf(PlayerSlot player);
  MatchStatus get status;
  MatchOutcome? get outcome;

  /// Submits [player]'s guess. Throws [MatchRuleException] if it is not
  /// allowed right now.
  GuessEntry submit(PlayerSlot player, String guess);
}

class MatchRuleException implements Exception {
  final String message;
  const MatchRuleException(this.message);
  @override
  String toString() => 'MatchRuleException($message)';
}

/// Turn-based: A guesses B's secret, then B guesses A's, and so on.
///
/// If the player who moved first cracks it, the other player gets one last
/// turn to equal it (when [equalTurns] is true), so moving first is no
/// advantage. Both solving in the same round is a draw.
class DuelMatch implements Match {
  @override
  final GameConfig config;
  final PlayerSlot firstPlayer;
  final bool equalTurns;
  final Map<PlayerSlot, GameSession> _sessions;
  PlayerSlot _turn;
  MatchOutcome? _outcome;

  /// [secretOfA] is the number player A chose, which B tries to guess.
  DuelMatch({
    required this.config,
    required Code secretOfA,
    required Code secretOfB,
    this.firstPlayer = PlayerSlot.a,
    this.equalTurns = true,
    Clock clock = systemClock,
  }) : _turn = firstPlayer,
       _sessions = {
         PlayerSlot.a: GameSession(
           config: config,
           secret: secretOfB,
           clock: clock,
         ),
         PlayerSlot.b: GameSession(
           config: config,
           secret: secretOfA,
           clock: clock,
         ),
       };

  DuelMatch._restored({
    required this.config,
    required this.firstPlayer,
    required this.equalTurns,
    required Map<PlayerSlot, GameSession> sessions,
    required PlayerSlot turn,
  }) : _sessions = sessions,
       // ignore: prefer_initializing_formals
       _turn = turn {
    final last = sessions.values.every((s) => s.guessCount == 0)
        ? null
        : (sessions[firstPlayer]!.guessCount >
                  sessions[firstPlayer.other]!.guessCount
              ? firstPlayer
              : firstPlayer.other);
    if (last != null) _resolve(last);
  }

  /// Saves the match so it can be resumed with [DuelMatch.fromJson].
  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'firstPlayer': firstPlayer.name,
    'equalTurns': equalTurns,
    'turn': _turn.name,
    'a': sessionOf(PlayerSlot.a).toJson(),
    'b': sessionOf(PlayerSlot.b).toJson(),
  };

  /// Rebuilds a match saved with [toJson]. Unfinished sessions come back
  /// paused; call [resumeClocks] when play continues.
  factory DuelMatch.fromJson(
    Map<String, dynamic> json, {
    Clock clock = systemClock,
  }) => DuelMatch._restored(
    config: GameConfig.fromJson(json['config'] as Map<String, dynamic>),
    firstPlayer: PlayerSlot.values.byName(json['firstPlayer'] as String),
    equalTurns: json['equalTurns'] as bool,
    turn: PlayerSlot.values.byName(json['turn'] as String),
    sessions: {
      for (final p in PlayerSlot.values)
        p: GameSession.fromJson(
          json[p.name] as Map<String, dynamic>,
          clock: clock,
        ),
    },
  );

  /// Starts both players' timers, e.g. when the board first appears.
  void start() {
    for (final s in _sessions.values) {
      s.start();
    }
  }

  void pauseClocks() {
    for (final s in _sessions.values) {
      s.pause();
    }
  }

  void resumeClocks() {
    for (final s in _sessions.values) {
      s.resume();
    }
  }

  @override
  MatchMode get mode => MatchMode.duel;
  @override
  GameSession sessionOf(PlayerSlot player) => _sessions[player]!;
  PlayerSlot get currentTurn => _turn;
  @override
  MatchStatus get status =>
      _outcome == null ? MatchStatus.inProgress : MatchStatus.finished;
  @override
  MatchOutcome? get outcome => _outcome;

  @override
  GuessEntry submit(PlayerSlot player, String guess) {
    if (_outcome != null) throw const MatchRuleException('Match is over');
    if (player != _turn) throw const MatchRuleException('Not your turn');

    final entry = sessionOf(player).submit(guess);
    _resolve(player);
    if (_outcome == null) {
      // Alternate, but skip a player who is out of guesses.
      final next = player.other;
      _turn = sessionOf(next).isOver ? player : next;
    }
    return entry;
  }

  void _resolve(PlayerSlot justMoved) {
    final first = sessionOf(firstPlayer);
    final second = sessionOf(firstPlayer.other);
    final firstWon = first.status == GameStatus.won;
    final secondWon = second.status == GameStatus.won;

    if (firstWon || secondWon) {
      final roundComplete = justMoved == firstPlayer.other;
      final secondCanReply = equalTurns && !second.isOver;
      if (roundComplete || !secondCanReply) {
        _outcome = MatchOutcome(
          firstWon && secondWon
              ? null
              : (firstWon ? firstPlayer : firstPlayer.other),
        );
      }
    } else if (first.isOver && second.isOver) {
      _outcome = const MatchOutcome(null);
    }
  }
}

/// Both players work on the same secret at the same time. First to crack it
/// wins; if both run out of guesses or time it is a draw.
class RaceMatch implements Match {
  @override
  final GameConfig config;
  final Code secret;
  final Map<PlayerSlot, GameSession> _sessions;

  RaceMatch({
    required this.config,
    required this.secret,
    Clock clock = systemClock,
  }) : _sessions = {
         for (final p in PlayerSlot.values)
           p: GameSession(config: config, secret: secret, clock: clock),
       };

  factory RaceMatch.random(GameConfig config, {Clock clock = systemClock}) =>
      RaceMatch(config: config, secret: Code.random(config), clock: clock);

  @override
  MatchMode get mode => MatchMode.race;
  @override
  GameSession sessionOf(PlayerSlot player) => _sessions[player]!;

  /// Starts both timers together so the race is fair.
  void start() {
    for (final s in _sessions.values) {
      s.start();
    }
  }

  @override
  MatchOutcome? get outcome {
    final winners = PlayerSlot.values
        .where((p) => sessionOf(p).status == GameStatus.won)
        .toList();
    if (winners.length == 1) return MatchOutcome(winners.single);
    if (winners.length == 2) {
      final a = sessionOf(PlayerSlot.a).endedAt!;
      final b = sessionOf(PlayerSlot.b).endedAt!;
      if (a.isBefore(b)) {
        return const MatchOutcome(PlayerSlot.a);
      }
      if (b.isBefore(a)) {
        return const MatchOutcome(PlayerSlot.b);
      }
      return const MatchOutcome(null);
    }
    if (_sessions.values.every((s) => s.isOver)) {
      return const MatchOutcome(null);
    }
    return null;
  }

  @override
  MatchStatus get status =>
      outcome == null ? MatchStatus.inProgress : MatchStatus.finished;

  @override
  GuessEntry submit(PlayerSlot player, String guess) {
    if (status == MatchStatus.finished) {
      throw const MatchRuleException('Match is over');
    }
    return sessionOf(player).submit(guess);
  }
}
