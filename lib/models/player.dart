import 'package:flutter/material.dart';

class GamePlayer {
  String name;
  String school;
  final String tag;
  final Color color;
  final Color textColor;
  int pos;
  int correct;
  int asked;

  GamePlayer({
    required this.name,
    required this.school,
    required this.tag,
    required this.color,
    required this.textColor,
    this.pos = 0,
    this.correct = 0,
    this.asked = 0,
  });

  static String tagFor(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    final s = name.trim();
    if (s.length >= 2) return s.substring(0, 2).toUpperCase();
    if (s.length == 1) return s.toUpperCase();
    return "P";
  }
}
