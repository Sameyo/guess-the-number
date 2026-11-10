import 'package:flutter/material.dart';

/// Bright "maths exercise book" palette: graph paper, navy ink, and a
/// colour for every digit so patterns between guesses jump out.
abstract final class Palette {
  static const paper = Color(0xFFFFFDF6);
  static const gridLine = Color(0xFFDDE8F8);
  static const gridLineBold = Color(0xFFC3D5F2);
  static const ink = Color(0xFF1E2A4A);
  static const inkSoft = Color(0xFF5B6685);

  static const identified = Color(0xFFFFA62B); // I column
  static const inPosition = Color(0xFF16B364); // P column
  static const coral = Color(0xFFFF5D73);
  static const violet = Color(0xFF7C5CFF);
  static const teal = Color(0xFF0FB5AE);
  static const sky = Color(0xFF3B82F6);
  static const pink = Color(0xFFEC4899);
  static const sun = Color(0xFFFFC53D);

  static const digits = <int, Color>{
    1: Color(0xFFEF4444),
    2: Color(0xFFF97316),
    3: Color(0xFFEAB308),
    4: Color(0xFF22C55E),
    5: Color(0xFF14B8A6),
    6: Color(0xFF3B82F6),
    7: Color(0xFF6366F1),
    8: Color(0xFFA855F7),
    9: Color(0xFFEC4899),
  };

  static Color digit(int d) => digits[d] ?? ink;
}

/// Monospace digits keep guess columns lined up like on paper.
const digitFont = 'monospace';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.violet,
    surface: Palette.paper,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Palette.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Palette.gridLineBold, width: 1.5),
      ),
    ),
  );
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
