import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-player aggregate stats within a school.
class PlayerStats {
  int points;
  int correct;
  int games;
  int wins;

  PlayerStats({
    this.points = 0,
    this.correct = 0,
    this.games = 0,
    this.wins = 0,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> j) => PlayerStats(
    points: (j['points'] ?? 0) as int,
    correct: (j['correct'] ?? 0) as int,
    games: (j['games'] ?? 0) as int,
    wins: (j['wins'] ?? 0) as int,
  );

  Map<String, dynamic> toJson() => {
    'points': points,
    'correct': correct,
    'games': games,
    'wins': wins,
  };
}

/// Aggregate stats for a school, including a map of player name -> stats.
class SchoolStats {
  int points;
  int correct;
  int games;
  int wins;
  Map<String, PlayerStats> players;

  SchoolStats({
    this.points = 0,
    this.correct = 0,
    this.games = 0,
    this.wins = 0,
    Map<String, PlayerStats>? players,
  }) : players = players ?? {};

  factory SchoolStats.fromJson(Map<String, dynamic> j) => SchoolStats(
    points: (j['points'] ?? 0) as int,
    correct: (j['correct'] ?? 0) as int,
    games: (j['games'] ?? 0) as int,
    wins: (j['wins'] ?? 0) as int,
    players: (j['players'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, PlayerStats.fromJson(v as Map<String, dynamic>)),
    ),
  );

  Map<String, dynamic> toJson() => {
    'points': points,
    'correct': correct,
    'games': games,
    'wins': wins,
    'players': players.map((k, v) => MapEntry(k, v.toJson())),
  };

  PlayerStats? get mvp {
    if (players.isEmpty) return null;
    final entries = players.entries.toList()
      ..sort((a, b) {
        final byPoints = b.value.points.compareTo(a.value.points);
        if (byPoints != 0) return byPoints;
        return b.value.correct.compareTo(a.value.correct);
      });
    return entries.first.value;
  }

  String? get mvpName {
    if (players.isEmpty) return null;
    final entries = players.entries.toList()
      ..sort((a, b) {
        final byPoints = b.value.points.compareTo(a.value.points);
        if (byPoints != 0) return byPoints;
        return b.value.correct.compareTo(a.value.correct);
      });
    return entries.first.key;
  }
}

/// A single result to submit after a game ends.
class GameResult {
  final String school;
  final String player;
  final int points;
  final int correct;
  final bool win;

  GameResult({
    required this.school,
    required this.player,
    required this.points,
    required this.correct,
    required this.win,
  });
}

/// Persistent national-style leaderboard, stored locally via SharedPreferences.
/// Scores aggregate by school, across every game played on this device.
class LeaderboardService {
  static const _boardKey = 'qq_school_leaderboard_v2';
  static const _codesKey = 'qq_license_codes_v1';
  static const _seasonKey = 'qq_season_v1';

  static const int pointsPerCorrect = 10;
  static const int winBonus = 50;

  /// Built-in license codes (mirrors the web prototype).
  static final Map<String, Map<String, String>> builtInCodes = {
    'CTC-2026': {'school': 'Central Texas College', 'type': 'school'},
    'DEMO-CLASS': {'school': '', 'type': 'classroom'},
  };

  Future<Map<String, SchoolStats>> loadBoard() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_boardKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, SchoolStats.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveBoard(Map<String, SchoolStats> board) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(board.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_boardKey, raw);
  }

  Future<Map<String, SchoolStats>> addResults(List<GameResult> results) async {
    final board = await loadBoard();
    for (final r in results) {
      final s = board[r.school] ?? SchoolStats();
      s.points += r.points;
      s.correct += r.correct;
      s.games += 1;
      s.wins += r.win ? 1 : 0;
      final p = s.players[r.player] ?? PlayerStats();
      p.points += r.points;
      p.correct += r.correct;
      p.games += 1;
      p.wins += r.win ? 1 : 0;
      s.players[r.player] = p;
      board[r.school] = s;
    }
    await saveBoard(board);
    return board;
  }

  Future<void> removeSchool(String school) async {
    final board = await loadBoard();
    board.remove(school);
    await saveBoard(board);
  }

  Future<void> clearBoard() async {
    await saveBoard({});
  }

  List<MapEntry<String, SchoolStats>> standings(
    Map<String, SchoolStats> board,
  ) {
    final list = board.entries.toList();
    list.sort((a, b) {
      final byPoints = b.value.points.compareTo(a.value.points);
      if (byPoints != 0) return byPoints;
      final byCorrect = b.value.correct.compareTo(a.value.correct);
      if (byCorrect != 0) return byCorrect;
      return a.key.compareTo(b.key);
    });
    return list;
  }

  // ---------------- License codes ----------------

  Future<Map<String, Map<String, String>>> getCustomCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_codesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, Map<String, String>.from(v as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, Map<String, String>>> getAllCodes() async {
    final custom = await getCustomCodes();
    return {...builtInCodes, ...custom};
  }

  Future<void> saveCustomCode(String code, Map<String, String> rec) async {
    final prefs = await SharedPreferences.getInstance();
    final custom = await getCustomCodes();
    custom[code] = rec;
    await prefs.setString(_codesKey, jsonEncode(custom));
  }

  Future<void> deleteCustomCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final custom = await getCustomCodes();
    custom.remove(code);
    await prefs.setString(_codesKey, jsonEncode(custom));
  }

  // ---------------- Season ----------------

  Future<String> getSeason() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_seasonKey) ?? 'Season 1';
  }

  Future<void> setSeason(String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seasonKey, label);
  }
}
