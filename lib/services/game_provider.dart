import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player.dart';
import '../models/practice_area.dart';
import '../models/question.dart';
import '../data/questions_data.dart';
import '../theme/app_theme.dart';
import 'leaderboard_service.dart';
import 'license_service.dart';
import 'question_service.dart';
import 'sound_service.dart';

class GameProvider extends ChangeNotifier {
  final LeaderboardService leaderboard = LeaderboardService();
  final LicenseService licenseService = LicenseService();
  final QuestionService questionService = QuestionService();
  final Random _rand = Random();
  bool licenseChecking = false;

  // ---- Question bank ----
  // Starts with the built-in local questions (kQuestions) so gameplay works
  // immediately, even offline or before Firestore responds. Once the cloud
  // fetch completes successfully, _questionPool is swapped to the live
  // Firestore data so admin-added/edited questions show up without needing
  // an app update. If the fetch fails (offline, etc.) the local fallback
  // list keeps being used -- gameplay is never blocked on network access.
  List<QuizQuestion> _questionPool = List.of(kQuestions);
  bool questionsLoadedFromCloud = false;
  bool questionsLoading = false;

  /// Which practice area's question bank is currently loaded/playing.
  /// Defaults to Civil Litigation (the original bank) so existing behavior
  /// is unchanged for anyone who never touches the new practice-area menu.
  PracticeArea chosenPracticeArea = PracticeArea.civilLitigation;

  Future<void> _loadQuestionsFromCloud() async {
    questionsLoading = true;
    notifyListeners();
    try {
      final areaKey = practiceAreaKey(chosenPracticeArea);
      final remote = await questionService.getByPracticeArea(areaKey);
      if (remote.isNotEmpty) {
        _questionPool = remote;
        questionsLoadedFromCloud = true;
      } else if (chosenPracticeArea == PracticeArea.civilLitigation) {
        // Defensive fallback: if the civil-litigation query somehow comes
        // back empty (e.g. older docs not yet tagged), fall back to the
        // full unfiltered fetch so gameplay never silently breaks.
        final all = await questionService.getAll();
        _questionPool = all.isNotEmpty ? all : List.of(kQuestions);
        questionsLoadedFromCloud = all.isNotEmpty;
      } else {
        // No questions yet for this (presumably "coming soon") area --
        // keep whatever pool was already loaded rather than clearing it.
      }
    } catch (e) {
      // Offline or Firestore unavailable -- silently keep using the local
      // fallback pool. Not fatal to gameplay.
      if (kDebugMode) {
        debugPrint('QuestionService query failed, using local pool: $e');
      }
    }
    questionsLoading = false;
    notifyListeners();
  }

  /// Re-fetches the question pool from Firestore. Call after adding/editing
  /// questions in the Admin panel so gameplay reflects changes immediately
  /// without needing to restart the app.
  Future<void> refreshQuestions() => _loadQuestionsFromCloud();

  /// Switches the active practice area and reloads its question bank from
  /// Firestore. Only areas in [kPlayablePracticeAreas] have real question
  /// banks today; selecting any other area is blocked in the UI, but this
  /// method itself doesn't enforce that so it stays simple/testable.
  Future<void> setChosenPracticeArea(PracticeArea area) async {
    if (area == chosenPracticeArea) return;
    chosenPracticeArea = area;
    notifyListeners();
    await _loadQuestionsFromCloud();
  }

  // ---- Demo play limit ----
  // Unlicensed users get exactly ONE free game on a given device/browser.
  // After that, startGame() will not proceed until a valid license code is
  // activated. This is a local, device-level check (SharedPreferences), not
  // a server-side one -- clearing browser data or reinstalling the app
  // resets it, but it stops the common case of casually replaying demo mode
  // indefinitely on the same device.
  static const _kDemoPlayUsedKey = 'demo_play_used';
  bool demoPlayUsed = false;
  bool demoStateLoaded = false;

  GameProvider() {
    _loadDemoState();
    _loadQuestionsFromCloud();
  }

  Future<void> _loadDemoState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      demoPlayUsed = prefs.getBool(_kDemoPlayUsedKey) ?? false;
    } catch (_) {
      // If local storage is unavailable for any reason, fail open (don't
      // block play) rather than crash the app.
      demoPlayUsed = false;
    }
    demoStateLoaded = true;
    notifyListeners();
  }

  Future<void> _markDemoPlayUsed() async {
    demoPlayUsed = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDemoPlayUsedKey, true);
    } catch (_) {
      // Ignore persistence failures; the in-memory flag still blocks replay
      // for the remainder of this session.
    }
  }

  /// True if the currently signed-in Firebase user is the admin. Admins get
  /// unlimited free play (bypasses both the license check and the one-play
  /// demo limit) so they can test the app without restriction.
  bool get isAdmin => FirebaseAuth.instance.currentUser != null;

  /// True if the user may start a new game right now: either they're the
  /// signed-in admin, they have a valid license, or they haven't used their
  /// one free demo game yet.
  bool get canStartGame => isAdmin || licensed || !demoPlayUsed;

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

  // ---- Question de-duplication ----
  // Tracks which question indices have already been asked during the
  // *current* game so the same question doesn't repeat. Once every question
  // in the pool has been used, the pool is reshuffled/cleared so play can
  // continue without ever blocking on an empty pool.
  final Set<int> _usedQuestionIndices = {};

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
      licenseError = '';
      notifyListeners();
      return;
    }
    licenseChecking = true;
    notifyListeners();
    try {
      final rec = await licenseService.validate(code);
      if (rec != null) {
        licensed = true;
        licensedSchool = rec.school.isNotEmpty ? rec.school : null;
        licenseError = '';
      } else {
        licensed = false;
        licensedSchool = null;
        licenseError = 'Code not recognized.';
      }
    } catch (e) {
      licensed = false;
      licensedSchool = null;
      licenseError = 'Could not verify code. Check your connection.';
    }
    licenseChecking = false;
    notifyListeners();
  }

  /// Attempts to start a game. Returns false (and does nothing else) if the
  /// user has already used their one free demo game and has no license.
  bool startGame() {
    if (!canStartGame) {
      return false;
    }
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
    if (!licensed && !isAdmin) {
      // This is their one free demo game -- consume it now so a second
      // attempt (even without finishing this one) is blocked. Signed-in
      // admins are exempt so they can freely test the app.
      _markDemoPlayUsed();
    }
    current = 0;
    busy = false;
    gameStarted = true;
    hint = "Answer correctly to advance.";
    _usedQuestionIndices.clear();
    notifyListeners();
    return true;
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
    final pool = _questionPool.isNotEmpty ? _questionPool : kQuestions;
    // If every question has been used already this game, reset the pool so
    // we never run out -- questions can start repeating again only after
    // the *entire* set has been seen at least once.
    if (_usedQuestionIndices.length >= pool.length) {
      _usedQuestionIndices.clear();
    }
    int index;
    do {
      index = _rand.nextInt(pool.length);
    } while (_usedQuestionIndices.contains(index));
    _usedQuestionIndices.add(index);
    currentPlayer.asked++;
    return pool[index];
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
