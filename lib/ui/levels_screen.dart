import 'package:flutter/material.dart';

import '../engine.dart';
import 'solo_game_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// The level path: numbers get longer, guess limits tighter, and some levels
/// add a timer. Earn stars to unlock the next ones.
class LevelsScreen extends StatelessWidget {
  const LevelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final progress = store.levelProgress;
    final path = defaultLevelPath;
    return Scaffold(
      appBar: AppBar(title: const Text('Levels')),
      body: GraphPaper(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, color: Palette.sun, size: 30),
                  Text(
                    ' ${progress.totalStars} / ${path.length * 3}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: path.length,
                itemBuilder: (context, i) {
                  final level = path[i];
                  final unlocked = progress.isUnlocked(level, path);
                  final stars = progress.bestStars[level.id] ?? 0;
                  final color = Palette.digit(level.config.digitCount + 2);
                  return _LevelTile(
                    level: level,
                    unlocked: unlocked,
                    stars: stars,
                    color: color,
                    onTap: unlocked
                        ? () => _play(context, level)
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Finish level ${level.number - 1}'
                                '${level.starsToUnlock > 0 ? ' and collect ${level.starsToUnlock} stars' : ''} to unlock',
                              ),
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _play(BuildContext context, Level level) async {
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SoloGameScreen(
          session: GameSession.random(level.config),
          level: level,
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final Level level;
  final bool unlocked;
  final int stars;
  final Color color;
  final VoidCallback onTap;
  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = level.config;
    return Material(
      color: unlocked ? color : const Color(0xFFE5E7EB),
      borderRadius: BorderRadius.circular(18),
      elevation: unlocked ? 3 : 0,
      shadowColor: color,
      child: InkWell(
        key: Key('level${level.number}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unlocked)
                  Text(
                    '${level.number}',
                    style: const TextStyle(
                      fontFamily: digitFont,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.lock, color: Palette.inkSoft, size: 30),
                Text(
                  '${cfg.digitCount} digits · ${cfg.maxGuesses} tries${cfg.timeLimit != null ? ' · ⏱' : ''}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: unlocked ? Colors.white : Palette.inkSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: i < stars
                            ? Palette.sun
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
