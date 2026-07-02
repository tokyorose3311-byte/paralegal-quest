import 'package:flutter/material.dart';

enum GameStyle { classic, adventure, mystical, patriotic }

class GameColors {
  final Color navy;
  final Color navyDeep;
  final Color brass;
  final Color brassBright;
  final Color cream;
  final Color red;
  final Color blue;
  final Color accent;
  final Color accent2;
  final Color good;
  final Color bad;

  const GameColors({
    required this.navy,
    required this.navyDeep,
    required this.brass,
    required this.brassBright,
    required this.cream,
    required this.red,
    required this.blue,
    required this.accent,
    required this.accent2,
    required this.good,
    required this.bad,
  });

  static const _navy = Color(0xFF11203B);
  static const _navyDeep = Color(0xFF0B1426);
  static const _cream = Color(0xFFEFE2C4);
  static const _red = Color(0xFFB3322F);
  static const _blue = Color(0xFF2F4F8F);
  static const _good = Color(0xFF3F8B54);
  static const _bad = Color(0xFFB3322F);

  static GameColors forStyle(GameStyle style) {
    switch (style) {
      case GameStyle.classic:
        return const GameColors(
          navy: _navy,
          navyDeep: _navyDeep,
          brass: Color(0xFFC9A24B),
          brassBright: Color(0xFFE6CF8A),
          cream: _cream,
          red: _red,
          blue: _blue,
          accent: Color(0xFFC9A24B),
          accent2: Color(0xFF8A1F1D),
          good: _good,
          bad: _bad,
        );
      case GameStyle.adventure:
        return const GameColors(
          navy: _navy,
          navyDeep: _navyDeep,
          brass: Color(0xFF7FC08C),
          brassBright: Color(0xFFB8E6C0),
          cream: _cream,
          red: _red,
          blue: _blue,
          accent: Color(0xFF3F8B54),
          accent2: Color(0xFF1F5D34),
          good: _good,
          bad: _bad,
        );
      case GameStyle.mystical:
        return const GameColors(
          navy: _navy,
          navyDeep: _navyDeep,
          brass: Color(0xFFB79AE0),
          brassBright: Color(0xFFD9C6F5),
          cream: _cream,
          red: _red,
          blue: _blue,
          accent: Color(0xFF7C5BB0),
          accent2: Color(0xFF4A2F78),
          good: _good,
          bad: _bad,
        );
      case GameStyle.patriotic:
        return const GameColors(
          navy: _navy,
          navyDeep: _navyDeep,
          brass: Color(0xFFD9B24B),
          brassBright: Color(0xFFF0D488),
          cream: _cream,
          red: _red,
          blue: _blue,
          accent: Color(0xFF2F4F8F),
          accent2: Color(0xFFB3322F),
          good: _good,
          bad: _bad,
        );
    }
  }
}

const List<Color> kPawnColors = [
  Color(0xFFC0392B),
  Color(0xFF2F5FA3),
  Color(0xFFE8E2D0),
  Color(0xFF6C4A9C),
];

const List<Color> kPawnTextColors = [
  Colors.white,
  Colors.white,
  Color(0xFF1A140C),
  Colors.white,
];

const List<String> kDefaultSchools = [
  "Central Texas College",
  "UT Austin",
  "Thurgood Marshall Law School",
  "UCLA Law School",
];

/// Waypoints tracing the winding red/white/blue path across the courtroom
/// board art, in percentage coordinates (0-100), from START (top-left) to
/// FINISH (bottom-right, near the second judge's bench).
const List<Offset> kWaypoints = [
  Offset(24, 27),
  Offset(32, 23),
  Offset(39, 17),
  Offset(46, 15),
  Offset(53, 18),
  Offset(59, 23),
  Offset(63, 30),
  Offset(65, 38),
  Offset(67, 46),
  Offset(69, 54),
  Offset(71, 62),
  Offset(66, 69),
  Offset(58, 72),
  Offset(49, 74),
  Offset(44, 69),
  Offset(34, 60),
  Offset(25, 65),
  Offset(20, 73),
  Offset(27, 82),
  Offset(39, 87),
  Offset(51, 90),
  Offset(61, 89),
];
