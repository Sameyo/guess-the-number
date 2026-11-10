import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/store.dart';
import '../engine.dart';
import 'theme.dart';

/// Makes the [AppStore] available to every screen and rebuilds on change.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Reads the store without rebuilding when it changes.
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

/// Light haptic feedback, if the player has it switched on.
void buzz(BuildContext context, {bool strong = false}) {
  if (!StoreScope.read(context).haptics) return;
  strong ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
}

/// Graph-paper background behind every screen.
class GraphPaper extends StatelessWidget {
  final Widget child;
  const GraphPaper({super.key, required this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GridPainter(),
    child: SafeArea(child: child),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 22.0;
    final thin = Paint()
      ..color = Palette.gridLine
      ..strokeWidth = 1;
    final bold = Paint()
      ..color = Palette.gridLineBold
      ..strokeWidth = 1.2;
    var i = 0;
    for (var x = 0.0; x < size.width; x += step, i++) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i % 5 == 0 ? bold : thin,
      );
    }
    i = 0;
    for (var y = 0.0; y < size.height; y += step, i++) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        i % 5 == 0 ? bold : thin,
      );
    }
    // Red margin line, like an exercise book.
    canvas.drawLine(
      const Offset(14, 0),
      Offset(14, size.height),
      Paint()
        ..color = Palette.coral.withValues(alpha: 0.35)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

/// One digit on a coloured tile. An empty tile shows a dashed slot.
class DigitTile extends StatelessWidget {
  final int? digit;
  final double size;
  final bool hidden;
  final bool faded;
  const DigitTile(
    this.digit, {
    super.key,
    this.size = 34,
    this.hidden = false,
    this.faded = false,
  });

  @override
  Widget build(BuildContext context) {
    final d = digit;
    final color = d == null || hidden ? Palette.inkSoft : Palette.digit(d);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size * 1.15,
      margin: EdgeInsets.symmetric(horizontal: size * 0.06),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: d == null
            ? Colors.white
            : color.withValues(alpha: faded ? 0.25 : 0.95),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: d == null ? Palette.gridLineBold : color,
          width: 2,
        ),
        boxShadow: d == null || faded
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Text(
        d == null ? '' : (hidden ? '•' : '$d'),
        style: TextStyle(
          fontFamily: digitFont,
          fontSize: size * 0.6,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// A round I or P badge.
class ScoreBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final double size;
  const ScoreBadge({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    margin: const EdgeInsets.symmetric(horizontal: 3),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: value == 0 ? Colors.white : color,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 2),
    ),
    child: Text(
      '$value',
      style: TextStyle(
        fontFamily: digitFont,
        fontWeight: FontWeight.w900,
        fontSize: size * 0.5,
        color: value == 0 ? color : Colors.white,
      ),
    ),
  );
}

/// Header for the board: "#  guess  I  P".
class BoardHeader extends StatelessWidget {
  final int digitCount;
  final double tileSize;
  const BoardHeader({super.key, required this.digitCount, this.tileSize = 34});

  @override
  Widget build(BuildContext context) {
    TextStyle style(Color c) => TextStyle(
      fontWeight: FontWeight.w900,
      color: c,
      fontSize: tileSize * 0.45,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: tileSize * 0.9,
            child: Text('#', style: style(Palette.inkSoft)),
          ),
          Expanded(
            child: Center(child: Text('Guess', style: style(Palette.inkSoft))),
          ),
          SizedBox(
            width: tileSize + 6,
            child: Center(child: Text('I', style: style(Palette.identified))),
          ),
          SizedBox(
            width: tileSize + 6,
            child: Center(child: Text('P', style: style(Palette.inPosition))),
          ),
        ],
      ),
    );
  }
}

/// One row on the board, sliding in when it first appears.
class GuessRow extends StatelessWidget {
  final int number;
  final GuessEntry entry;
  final double tileSize;
  final bool animate;
  final bool solved;
  const GuessRow({
    super.key,
    required this.number,
    required this.entry,
    this.tileSize = 34,
    this.animate = false,
    this.solved = false,
  });

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: solved
            ? Palette.inPosition.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: solved ? Palette.inPosition : Palette.gridLine,
          width: solved ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: tileSize * 0.9,
            child: Text(
              '$number',
              style: TextStyle(
                fontFamily: digitFont,
                color: Palette.inkSoft,
                fontWeight: FontWeight.w700,
                fontSize: tileSize * 0.4,
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final d in entry.guess.digits)
                    DigitTile(d, size: tileSize),
                ],
              ),
            ),
          ),
          ScoreBadge(
            label: 'I',
            value: entry.score.identified,
            color: Palette.identified,
            size: tileSize,
          ),
          ScoreBadge(
            label: 'P',
            value: entry.score.inPosition,
            color: Palette.inPosition,
            size: tileSize,
          ),
        ],
      ),
    );
    if (!animate) return row;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -24),
          child: child,
        ),
      ),
      child: row,
    );
  }
}

/// A stat bubble for the top bar: icon, value and a small caption.
class HudChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String caption;
  final Color color;
  final Key? valueKey;
  const HudChip({
    super.key,
    required this.icon,
    required this.value,
    required this.caption,
    required this.color,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.white, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            offset: const Offset(0, 3),
            blurRadius: 4,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  key: valueKey,
                  style: const TextStyle(
                    fontFamily: digitFont,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    height: 1.1,
                  ),
                ),
                Text(
                  caption,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// The live game timer. Ticks itself so only this chip rebuilds each second.
class TimerChip extends StatefulWidget {
  final Duration Function() elapsed;

  /// Counts down from this limit when set.
  final Duration? limit;

  /// Called every tick, e.g. to check a time limit.
  final VoidCallback? onTick;
  const TimerChip({super.key, required this.elapsed, this.limit, this.onTick});

  @override
  State<TimerChip> createState() => _TimerChipState();
}

class _TimerChipState extends State<TimerChip> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      widget.onTick?.call();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final limit = widget.limit;
    final elapsed = widget.elapsed();
    if (limit == null) {
      return HudChip(
        icon: Icons.timer_outlined,
        value: formatDuration(elapsed),
        caption: 'time',
        color: Palette.sky,
        valueKey: const Key('timer'),
      );
    }
    final left = limit - elapsed;
    final safe = left.isNegative ? Duration.zero : left;
    return HudChip(
      icon: Icons.hourglass_bottom,
      value: formatDuration(safe + const Duration(milliseconds: 999)),
      caption: 'time left',
      color: safe.inSeconds < 30 ? Palette.coral : Palette.sky,
      valueKey: const Key('timer'),
    );
  }
}

/// Tap a digit to cross it out, tap again to mark it as in the number.
class NotesPad extends StatelessWidget {
  final DigitNotes notes;
  final ValueChanged<int> onTap;
  const NotesPad({super.key, required this.notes, required this.onTap});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Padding(
        padding: EdgeInsets.only(right: 6),
        child: Icon(Icons.edit_note, color: Palette.inkSoft, size: 22),
      ),
      for (final d in GameConfig.allowedDigits)
        Expanded(
          child: GestureDetector(
            key: Key('note$d'),
            onTap: () => onTap(d),
            child: _NoteCell(d, notes[d] ?? DigitMark.unknown),
          ),
        ),
    ],
  );
}

class _NoteCell extends StatelessWidget {
  final int digit;
  final DigitMark mark;
  const _NoteCell(this.digit, this.mark);

  @override
  Widget build(BuildContext context) {
    final color = Palette.digit(digit);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: switch (mark) {
          DigitMark.unknown => Colors.white,
          DigitMark.out => const Color(0xFFE5E7EB),
          DigitMark.inside => Palette.inPosition,
        },
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: mark == DigitMark.inside
              ? Palette.inPosition
              : color.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Text(
        '$digit',
        style: TextStyle(
          fontFamily: digitFont,
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: switch (mark) {
            DigitMark.unknown => color,
            DigitMark.out => Palette.inkSoft.withValues(alpha: 0.5),
            DigitMark.inside => Colors.white,
          },
          decoration: mark == DigitMark.out ? TextDecoration.lineThrough : null,
          decorationThickness: 2.5,
        ),
      ),
    );
  }
}

/// Builds a guess one digit at a time: digits already used in the guess are
/// disabled, so a guess can never repeat a digit or contain 0.
class GuessInput extends StatefulWidget {
  final int digitCount;
  final DigitNotes notes;
  final bool enabled;
  final bool hideDigits;
  final String submitLabel;

  /// Returns an error message to show, or null if accepted.
  final String? Function(String guess) onSubmit;
  const GuessInput({
    super.key,
    required this.digitCount,
    required this.onSubmit,
    this.notes = const {},
    this.enabled = true,
    this.hideDigits = false,
    this.submitLabel = 'GO',
  });

  @override
  State<GuessInput> createState() => GuessInputState();
}

class GuessInputState extends State<GuessInput>
    with SingleTickerProviderStateMixin {
  final List<int> _digits = [];
  String? _error;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _full => _digits.length == widget.digitCount;

  /// Fills the slots, e.g. with a random secret.
  void setDigits(List<int> digits) => setState(() {
    _digits
      ..clear()
      ..addAll(digits);
    _error = null;
  });

  void _tap(int d) {
    if (_full || _digits.contains(d)) return;
    buzz(context);
    setState(() {
      _digits.add(d);
      _error = null;
    });
  }

  void _back() {
    if (_digits.isEmpty) return;
    buzz(context);
    setState(() {
      _digits.removeLast();
      _error = null;
    });
  }

  void _clear() => setState(() {
    _digits.clear();
    _error = null;
  });

  void _submit() {
    if (!_full) return;
    final error = widget.onSubmit(_digits.join());
    setState(() {
      _error = error;
      if (error == null) _digits.clear();
    });
    if (error != null) _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              sin(_shake.value * pi * 6) * 10 * (1 - _shake.value),
              0,
            ),
            child: child,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.digitCount; i++)
                  DigitTile(
                    i < _digits.length ? _digits[i] : null,
                    size: 44,
                    hidden: widget.hideDigits,
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 22,
          child: _error == null
              ? null
              : Text(
                  _error!,
                  key: const Key('guessError'),
                  style: const TextStyle(
                    color: Palette.coral,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        for (final row in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Row(
            children: [
              for (final d in row)
                _Key(
                  key: Key('key$d'),
                  color: Palette.digit(d),
                  enabled: enabled && !_full && !_digits.contains(d),
                  crossed: widget.notes[d] == DigitMark.out,
                  onTap: () => _tap(d),
                  child: Text(
                    '$d',
                    style: const TextStyle(
                      fontFamily: digitFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        Row(
          children: [
            _Key(
              key: const Key('keyBack'),
              color: Palette.inkSoft,
              enabled: enabled && _digits.isNotEmpty,
              onTap: _back,
              onLongPress: _clear,
              child: const Icon(Icons.backspace_outlined, color: Colors.white),
            ),
            _Key(
              key: const Key('keyGo'),
              flex: 2,
              color: Palette.inPosition,
              enabled: enabled && _full,
              onTap: _submit,
              child: Text(
                widget.submitLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  final Color color;
  final bool enabled;
  final bool crossed;
  final int flex;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  const _Key({
    super.key,
    required this.color,
    required this.enabled,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.crossed = false,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Opacity(
        opacity: enabled ? (crossed ? 0.45 : 1) : 0.3,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(14),
          elevation: enabled ? 2 : 0,
          shadowColor: color,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            onLongPress: enabled ? onLongPress : null,
            child: SizedBox(height: 50, child: Center(child: child)),
          ),
        ),
      ),
    ),
  );
}

/// A burst of colourful confetti, for wins.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  final _pieces = List.generate(90, (i) => _Piece(Random(i * 7919)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_pieces, _c.value),
      ),
    ),
  );
}

class _Piece {
  final double x, speed, drift, spin, size;
  final Color color;
  _Piece(Random r)
    : x = r.nextDouble(),
      speed = 0.6 + r.nextDouble() * 0.8,
      drift = (r.nextDouble() - 0.5) * 0.3,
      spin = r.nextDouble() * 10,
      size = 6 + r.nextDouble() * 6,
      color = Palette.digits.values.elementAt(r.nextInt(9));
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final y = (t * p.speed * 1.4 - 0.15) * size.height;
      final x = (p.x + p.drift * t) * size.width;
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t * 3);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.5,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// A big, bright rounded button used on the home screen.
class BigButton extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const BigButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Material(
      borderRadius: BorderRadius.circular(20),
      color: color,
      elevation: 3,
      shadowColor: color,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [color, Color.lerp(color, Colors.white, 0.22)!],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    ),
  );
}
