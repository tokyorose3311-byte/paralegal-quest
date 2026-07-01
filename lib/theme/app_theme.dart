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

/// Waypoints tracing a path across the board art, in percentage coordinates (0-100).
const List<Offset> kWaypoints = [
  Offset(26, 25),
  Offset(33, 18),
  Offset(42, 15),
  Offset(50, 18),
  Offset(57, 15),
  Offset(64, 18),
  Offset(69, 26),
  Offset(68, 35),
  Offset(67, 43),
  Offset(70, 50),
  Offset(71, 57),
  Offset(62, 62),
  Offset(51, 64),
  Offset(40, 67),
  Offset(31, 73),
  Offset(27, 80),
  Offset(33, 87),
  Offset(44, 91),
  Offset(55, 92),
  Offset(63, 93),
];
