import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine.dart';

/// The kinds of game that can be saved and resumed.
enum GameKind { solo, level, kutir, local }

/// A player's note on a digit in the notes pad.
enum DigitMark {
  unknown,

  /// Crossed out: not in the number.
  out,

  /// Known to be in the number.
  inside;

  DigitMark get next => values[(index + 1) % values.length];
}

typedef DigitNotes = Map<int, DigitMark>;

Map<String, String> notesToJson(DigitNotes notes) => {
  for (final e in notes.entries)
    if (e.value != DigitMark.unknown) '${e.key}': e.value.name,
};

DigitNotes notesFromJson(Object? json) => {
  if (json is Map)
    for (final e in json.entries)
      int.parse(e.key as String): DigitMark.values.byName(e.value as String),
};

/// An unfinished game kept on the device so it can be resumed later.
class SavedGame {
  final GameKind kind;
  final DateTime savedAt;
  final Map<String, dynamic> data;

  const SavedGame(this.kind, this.savedAt, this.data);

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'data': data,
  };

  factory SavedGame.fromJson(Map<String, dynamic> json) => SavedGame(
    GameKind.values.byName(json['kind'] as String),
    DateTime.parse(json['savedAt'] as String),
    json['data'] as Map<String, dynamic>,
  );
}

/// Win/loss/draw count against the computer.
class Tally {
  final int wins;
  final int losses;
  final int draws;
  const Tally({this.wins = 0, this.losses = 0, this.draws = 0});

  int get played => wins + losses + draws;

  Tally add(MatchOutcome outcome, PlayerSlot me) => Tally(
    wins: wins + (outcome.winner == me ? 1 : 0),
    losses: losses + (outcome.winner == me.other ? 1 : 0),
    draws: draws + (outcome.isDraw ? 1 : 0),
  );

  Map<String, dynamic> toJson() => {'w': wins, 'l': losses, 'd': draws};
  factory Tally.fromJson(Map<String, dynamic> json) => Tally(
    wins: json['w'] as int? ?? 0,
    losses: json['l'] as int? ?? 0,
    draws: json['d'] as int? ?? 0,
  );
}

/// App-wide state kept on the device: settings, finished games, level stars,
/// the score against Kutir, and the one unfinished game that can be resumed.
class AppStore extends ChangeNotifier implements ResultsRepository {
  final SharedPreferences _prefs;

  static const _kDigits = 'settings.digitCount';
  static const _kKutirLevel = 'settings.kutirLevel';
  static const _kHaptics = 'settings.haptics';
  static const _kResults = 'results';
  static const _kLevels = 'levelProgress';
  static const _kKutirTally = 'kutirTally';
  static const _kSaved = 'savedGame';

  AppStore(this._prefs) {
    _load();
  }

  int digitCount = 4;
  SolverLevel kutirLevel = SolverLevel.normal;
  bool haptics = true;
  List<GameResult> _results = [];
  LevelProgress levelProgress = LevelProgress();
  Tally kutirTally = const Tally();
  SavedGame? savedGame;

  /// Stats from free play only, so level limits don't skew the records.
  PlayerStats get stats =>
      PlayerStats(_results.where((r) => r.levelId == null));

  GameConfig get freePlayConfig => GameConfig(digitCount: digitCount);

  void _load() {
    digitCount = _prefs.getInt(_kDigits) ?? 4;
    final level = _prefs.getString(_kKutirLevel);
    if (level != null) kutirLevel = SolverLevel.values.byName(level);
    haptics = _prefs.getBool(_kHaptics) ?? true;
    _results = _readList(_kResults)
        .map((j) => GameResult.fromJson(j as Map<String, dynamic>))
        .toList();
    final levels = _readMap(_kLevels);
    if (levels != null) levelProgress = LevelProgress.fromJson(levels);
    final tally = _readMap(_kKutirTally);
    if (tally != null) kutirTally = Tally.fromJson(tally);
    final saved = _readMap(_kSaved);
    if (saved != null) {
      try {
        savedGame = SavedGame.fromJson(saved);
      } catch (_) {
        _prefs.remove(_kSaved);
      }
    }
  }

  List<dynamic> _readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic>? _readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void setDigitCount(int value) {
    digitCount = value;
    _prefs.setInt(_kDigits, value);
    notifyListeners();
  }

  void setKutirLevel(SolverLevel value) {
    kutirLevel = value;
    _prefs.setString(_kKutirLevel, value.name);
    notifyListeners();
  }

  void setHaptics(bool value) {
    haptics = value;
    _prefs.setBool(_kHaptics, value);
    notifyListeners();
  }

  @override
  Future<List<GameResult>> loadAll() async => List.of(_results);

  @override
  Future<void> add(GameResult result) => recordResult(result);

  Future<void> recordResult(GameResult result) async {
    _results = [..._results, result];
    // Keep storage bounded; records come from wins, which are kept anyway.
    if (_results.length > 500) {
      _results = _results.sublist(_results.length - 500);
    }
    await _prefs.setString(
      _kResults,
      jsonEncode(_results.map((r) => r.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Records a level result. Returns the stars earned this time.
  Future<int> recordLevel(Level level, GameResult result) async {
    final stars = levelProgress.record(level, result);
    await _prefs.setString(_kLevels, jsonEncode(levelProgress.toJson()));
    await recordResult(result.withLevel(level.id));
    return stars;
  }

  Future<void> recordKutirMatch(MatchOutcome outcome) async {
    kutirTally = kutirTally.add(outcome, PlayerSlot.a);
    await _prefs.setString(_kKutirTally, jsonEncode(kutirTally.toJson()));
    notifyListeners();
  }

  Future<void> saveGame(GameKind kind, Map<String, dynamic> data) async {
    savedGame = SavedGame(kind, DateTime.now(), data);
    await _prefs.setString(_kSaved, jsonEncode(savedGame!.toJson()));
    notifyListeners();
  }

  Future<void> clearSavedGame() async {
    if (savedGame == null) return;
    savedGame = null;
    await _prefs.remove(_kSaved);
    notifyListeners();
  }

  /// Wipes records and progress (kept settings).
  Future<void> resetStats() async {
    _results = [];
    levelProgress = LevelProgress();
    kutirTally = const Tally();
    await _prefs.remove(_kResults);
    await _prefs.remove(_kLevels);
    await _prefs.remove(_kKutirTally);
    notifyListeners();
  }
}
