import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/question.dart';
import '../data/questions_data.dart';
import '../theme/app_theme.dart';
import 'leaderboard_service.dart';
import 'sound_service.dart';

class GameProvider extends ChangeNotifier {
  final LeaderboardService leaderboard = LeaderboardService();
  final Random _rand = Random();

  // ---- Setup state ----
  int chosenPlayers = 2;
  GameStyle chosenStyle = GameStyle.classic;
  bool licensed = false;
  String? licensedSchool;
  String licenseError = '';

  List<String> setupPlayerNames = List.generate(4, (i) => 'Player ${i + 1}');
  List<String> setupSchools = List.of(kDefaultSchools);

  // ---- Game state ----
  bool gameStarted = false;
  bool countsForLeaderboard = false;
  List<GamePlayer> players = [];
  int current = 0;
  bool busy = false;
  int lastRoll = 1;
  bool rolling = false;
  String hint = "Answer correctly to advance.";
  int? hoppingIndex;

  static final int totalSteps = kWaypoints.length;

  void setChosenPlayers(int n) {
    chosenPlayers = n;
    notifyListeners();
  }

  void setChosenStyle(GameStyle s) {
    chosenStyle = s;
    notifyListeners();
  }

  void setPlayerName(int i, String v) {
    setupPlayerNames[i] = v;
  }

  void setSchoolName(int i, String v) {
    setupSchools[i] = v;
  }

  Future<void> activateLicense(String codeRaw) async {
    final code = codeRaw.trim().toUpperCase();
    if (code.isEmpty) {
      licensed = false;
      licensedSchool = null;
      notifyListeners();
      return;
    }
    final codes = await leaderboard.getAllCodes();
    final rec = codes[code];
    if (rec != null) {
      licensed = true;
      licensedSchool = (rec['school']?.isNotEmpty ?? false)
          ? rec['school']
          : null;
      licenseError = '';
    } else {
      licensed = false;
      licensedSchool = null;
      licenseError = 'Code not recognized.';
    }
    notifyListeners();
  }

  void startGame() {
    players = [];
    for (int p = 0; p < chosenPlayers; p++) {
      final name = setupPlayerNames[p].trim().isNotEmpty
          ? setupPlayerNames[p].trim()
          : 'Player ${p + 1}';
      String school = setupSchools[p].trim().isNotEmpty
          ? setupSchools[p].trim()
          : (p < kDefaultSchools.length
                ? kDefaultSchools[p]
                : 'School ${p + 1}');
      if (licensed && licensedSchool != null) school = licensedSchool!;
      players.add(
        GamePlayer(
          name: name,
          school: school,
          tag: GamePlayer.tagFor(name),
          color: kPawnColors[p % kPawnColors.length],
          textColor: kPawnTextColors[p % kPawnTextColors.length],
        ),
      );
    }
    countsForLeaderboard = licensed;
    current = 0;
    busy = false;
    gameStarted = true;
    hint = "Answer correctly to advance.";
    notifyListeners();
  }

  void resetToSetup() {
    gameStarted = false;
    players = [];
    current = 0;
    busy = false;
    notifyListeners();
  }

  GamePlayer get currentPlayer => players[current];

  double progressFor(GamePlayer p) => p.pos / (totalSteps - 1);

  Future<int> rollDie() async {
    busy = true;
    rolling = true;
    hint = "Rolling…";
    notifyListeners();
    SoundService.roll();
    final roll = 1 + _rand.nextInt(6);
    await Future.delayed(const Duration(milliseconds: 500));
    rolling = false;
    lastRoll = roll;
    hint = "Rolled a $roll. Answer correctly to advance $roll.";
    notifyListeners();
    return roll;
  }

  QuizQuestion randomQuestion() {
    final q = kQuestions[_rand.nextInt(kQuestions.length)];
    currentPlayer.asked++;
    return q;
  }

  /// Returns true if the game ended (someone reached the end).
  Future<bool> resolveAnswer({
    required bool correct,
    required int roll,
    required VoidCallback onStep,
  }) async {
    final p = currentPlayer;
    if (correct) {
      p.correct++;
      SoundService.correct();
    } else {
      SoundService.wrong();
    }
    notifyListeners();

    if (!correct) {
      _endTurn();
      return false;
    }

    final target = min(p.pos + roll, totalSteps - 1);
    while (p.pos < target) {
      p.pos++;
      hoppingIndex = current;
      SoundService.step();
      notifyListeners();
      onStep();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    hoppingIndex = null;

    if (p.pos >= totalSteps - 1) {
      notifyListeners();
      return true;
    }
    _endTurn();
    return false;
  }

  void _endTurn() {
    busy = false;
    current = (current + 1) % players.length;
    hint = "Answer correctly to advance.";
    notifyListeners();
  }

  Future<Map<String, SchoolStats>> finishGameAndSubmit(
    GamePlayer winner,
  ) async {
    SoundService.win();
    final results = players
        .map(
          (p) => GameResult(
            school: p.school,
            player: p.name,
            correct: p.correct,
            win: p == winner,
            points:
                p.correct * LeaderboardService.pointsPerCorrect +
                (p == winner ? LeaderboardService.winBonus : 0),
          ),
        )
        .toList();
    if (!countsForLeaderboard) {
      return leaderboard.loadBoard();
    }
    return leaderboard.addResults(results);
  }
}
