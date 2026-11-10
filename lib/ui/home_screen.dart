import 'package:flutter/material.dart';

import '../app/store.dart';
import '../engine.dart';
import 'duel_screen.dart';
import 'levels_screen.dart';
import 'solo_game_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final saved = store.savedGame;
    return Scaffold(
      body: GraphPaper(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(26, 8, 16, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'How to play',
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => showHowToPlay(context),
                ),
                IconButton(
                  key: const Key('settings'),
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => _showSettings(context),
                ),
              ],
            ),
            const _Logo(),
            const SizedBox(height: 18),
            if (saved != null) ...[
              _ResumeCard(saved: saved),
              const SizedBox(height: 10),
            ],
            _RecordsCard(store: store),
            const SizedBox(height: 14),
            BigButton(
              key: const Key('playSolo'),
              title: saved == null ? 'Start game' : 'New game',
              subtitle: 'Crack a ${store.digitCount}-digit number',
              icon: Icons.play_arrow_rounded,
              color: Palette.violet,
              onTap: () => _startNew(
                context,
                (_) => SoloGameScreen(
                  session: GameSession.random(store.freePlayConfig),
                ),
              ),
            ),
            BigButton(
              key: const Key('playKutir'),
              title: 'Play vs Kutir',
              subtitle:
                  'The computer · ${_levelLabel(store.kutirLevel)} · '
                  '${store.kutirTally.wins}W ${store.kutirTally.losses}L ${store.kutirTally.draws}D',
              icon: Icons.smart_toy_outlined,
              color: Palette.pink,
              onTap: () => _startNew(
                context,
                (_) => SecretSetupScreen(
                  opponent: Opponent.kutir,
                  config: store.freePlayConfig,
                ),
              ),
            ),
            BigButton(
              key: const Key('play2p'),
              title: '2 Players',
              subtitle: 'Pass & play on this phone · online coming soon',
              icon: Icons.people_alt_outlined,
              color: Palette.teal,
              onTap: () => _startNew(
                context,
                (_) => SecretSetupScreen(
                  opponent: Opponent.local,
                  config: store.freePlayConfig,
                ),
              ),
            ),
            BigButton(
              key: const Key('playLevels'),
              title: 'Levels',
              subtitle:
                  '${store.levelProgress.totalStars}/${defaultLevelPath.length * 3} stars · '
                  'harder numbers, fewer tries',
              icon: Icons.emoji_events_outlined,
              color: Palette.identified,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LevelsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNew(BuildContext context, WidgetBuilder builder) async {
    final store = StoreScope.read(context);
    if (store.savedGame != null) {
      final ok = await confirm(
        context,
        'Start a new game?',
        'Your unfinished game will be discarded.',
        'Start',
      );
      if (ok != true) return;
      await store.clearSavedGame();
    }
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }
}

String _levelLabel(SolverLevel l) => switch (l) {
  SolverLevel.easy => 'Easy',
  SolverLevel.normal => 'Normal',
  SolverLevel.hard => 'Hard',
};

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text(
        'GUESS THE',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
          color: Palette.inkSoft,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, d) in const [7, 3, 9, 1, 5].indexed)
            Transform.rotate(
              angle: (i.isEven ? -1 : 1) * 0.08,
              child: DigitTile(d, size: 46),
            ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'NUMBER',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          letterSpacing: 8,
          color: Palette.ink,
        ),
      ),
    ],
  );
}

class _ResumeCard extends StatelessWidget {
  final SavedGame saved;
  const _ResumeCard({required this.saved});

  @override
  Widget build(BuildContext context) {
    final (label, detail) = _describe(saved);
    return Material(
      key: const Key('resume'),
      color: Palette.inPosition,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: Palette.inPosition,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => switch (saved.kind) {
              GameKind.solo || GameKind.level => SoloGameScreen.restore(saved),
              GameKind.kutir || GameKind.local => DuelScreen.restore(saved),
            },
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.replay_rounded, color: Colors.white, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resume $label',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
            ],
          ),
        ),
      ),
    );
  }

  static (String, String) _describe(SavedGame saved) {
    try {
      final d = saved.data;
      switch (saved.kind) {
        case GameKind.solo:
        case GameKind.level:
          final s = d['session'] as Map<String, dynamic>;
          final cfg = s['config'] as Map<String, dynamic>;
          final guesses = (s['guesses'] as List).length;
          final time = formatDuration(
            Duration(milliseconds: s['elapsedMs'] as int),
          );
          final label = saved.kind == GameKind.level
              ? 'level ${(d['levelId'] as String).substring(1)}'
              : '${cfg['digitCount']}-digit game';
          return (label, '$guesses guesses · $time');
        case GameKind.kutir:
        case GameKind.local:
          final m = d['match'] as Map<String, dynamic>;
          final a = m['a'] as Map<String, dynamic>;
          final rounds = (a['guesses'] as List).length;
          final time = formatDuration(
            Duration(milliseconds: a['elapsedMs'] as int),
          );
          return (
            saved.kind == GameKind.kutir ? 'vs Kutir' : '2-player game',
            'Round $rounds · $time',
          );
      }
    } catch (_) {
      return ('game', '');
    }
  }
}

class _RecordsCard extends StatelessWidget {
  final AppStore store;
  const _RecordsCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final stats = store.stats;
    final best = stats.best(store.digitCount);
    final played = stats.results.where(
      (r) => r.config.digitCount == store.digitCount,
    );
    final won = played.where((r) => r.won).length;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text(
                    'Number length',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                for (var n = 3; n <= 6; n++)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      key: Key('digits$n'),
                      label: Text(
                        '$n',
                        style: const TextStyle(
                          fontFamily: digitFont,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      selected: store.digitCount == n,
                      selectedColor: Palette.digit(n + 2)
                          .withValues(alpha: 0.3),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => store.setDigitCount(n),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(
                  key: const Key('bestGuesses'),
                  icon: Icons.emoji_events,
                  color: Palette.sun,
                  value: best.fewestGuesses?.toString() ?? '–',
                  label: 'High score\n(fewest guesses)',
                ),
                _Stat(
                  key: const Key('bestTime'),
                  icon: Icons.bolt,
                  color: Palette.sky,
                  value: best.fastestTime == null
                      ? '–'
                      : formatDuration(best.fastestTime!),
                  label: 'Fastest\ntime',
                ),
                _Stat(
                  icon: Icons.check_circle,
                  color: Palette.inPosition,
                  value: '$won/${played.length}',
                  label: 'Won /\nplayed',
                ),
                _Stat(
                  icon: Icons.local_fire_department,
                  color: Palette.coral,
                  value: '${stats.currentStreak}',
                  label: 'Win\nstreak',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _Stat({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: color, size: 26),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: digitFont,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Palette.inkSoft,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

void _showSettings(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Palette.paper,
  showDragHandle: true,
  builder: (context) {
    final store = StoreScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          const Text(
            'Kutir difficulty',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SegmentedButton<SolverLevel>(
            segments: [
              for (final l in SolverLevel.values)
                ButtonSegment(value: l, label: Text(_levelLabel(l))),
            ],
            selected: {store.kutirLevel},
            onSelectionChanged: (s) => store.setKutirLevel(s.single),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Vibration',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            value: store.haptics,
            onChanged: store.setHaptics,
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Palette.coral),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Reset records and level stars'),
            onPressed: () async {
              final ok = await confirm(
                context,
                'Reset everything?',
                'Records, stats, level stars and the Kutir score will be cleared.',
                'Reset',
              );
              if (ok == true) await store.resetStats();
            },
          ),
        ],
      ),
    );
  },
);
