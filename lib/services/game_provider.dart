import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player.dart';
import '../models/practice_area.dart';
import '../models/question.dart';
import '../models/region.dart';
import '../models/student_profile.dart';
import '../data/questions_data.dart';
import '../theme/app_theme.dart';
import 'auth_claims.dart';
import 'cloud_leaderboard_service.dart';
import 'leaderboard_service.dart';
import 'license_service.dart';
import 'practice_area_service.dart';
import 'question_service.dart';
import 'sound_service.dart';
import 'student_auth_service.dart';

class GameProvider extends ChangeNotifier {
  final LeaderboardService leaderboard = LeaderboardService();
  final CloudLeaderboardService cloudLeaderboard = CloudLeaderboardService();
  final LicenseService licenseService = LicenseService();
  final QuestionService questionService = QuestionService();
  final PracticeAreaService practiceAreaService = PracticeAreaService();
  final StudentAuthService studentAuth = StudentAuthService();
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

  /// The full practice-area menu, loaded from the Firestore `practiceAreas`
  /// collection (see PracticeAreaService). This drives the setup screen's
  /// tiles directly -- which areas exist, their display name/icon/order,
  /// and whether they're playable (`active: true`) or shown as a locked
  /// "Coming soon" card. Falls back to [kLocalFallbackPracticeAreas] if the
  /// collection can't be reached (offline) or hasn't been seeded yet, so
  /// the menu never renders blank.
  List<PracticeAreaDoc> practiceAreas = List.of(kLocalFallbackPracticeAreas);
  bool practiceAreasLoading = false;

  /// The Firestore document id (== `practiceArea` tag key used in the
  /// `questions` collection) of whichever area is currently selected/being
  /// played. Defaults to Civil Litigation so existing behavior is unchanged
  /// for anyone who never touches the practice-area menu.
  String chosenPracticeArea = kDefaultPracticeAreaKey;

  /// Convenience getter: the full [PracticeAreaDoc] for [chosenPracticeArea],
  /// or null if it's somehow not present in [practiceAreas] (e.g. a very
  /// brief window before the initial load completes).
  PracticeAreaDoc? get chosenPracticeAreaDoc {
    for (final a in practiceAreas) {
      if (a.id == chosenPracticeArea) return a;
    }
    return null;
  }

  /// Human-readable label for [chosenPracticeArea], for UI headers. Falls
  /// back to a title-cased version of the raw key if the doc isn't loaded
  /// yet, so the header never shows a blank/placeholder string.
  String get chosenPracticeAreaLabel {
    final doc = chosenPracticeAreaDoc;
    if (doc != null) return doc.displayName;
    return chosenPracticeArea
        .split('_')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Future<void> _loadPracticeAreas() async {
    practiceAreasLoading = true;
    notifyListeners();
    try {
      final areas = await practiceAreaService.getAll();
      if (areas.isNotEmpty) {
        practiceAreas = areas;
      }
      // If Firestore returned an empty collection (not yet seeded), keep
      // the local fallback list already in [practiceAreas] rather than
      // clearing the menu to nothing.
    } catch (e) {
      // Offline or Firestore unavailable -- silently keep using the local
      // fallback list. Not fatal to gameplay.
      if (kDebugMode) {
        debugPrint('PracticeAreaService query failed, using local list: $e');
      }
    }
    practiceAreasLoading = false;
    notifyListeners();
  }

  /// Re-fetches the practice-area menu from Firestore. Call after toggling
  /// an area's `active` flag in the Admin panel so the setup screen
  /// reflects the change immediately without needing to restart the app.
  Future<void> refreshPracticeAreas() => _loadPracticeAreas();

  Future<void> _loadQuestionsFromCloud() async {
    questionsLoading = true;
    notifyListeners();
    try {
      final remote = await questionService.getByPracticeArea(
        chosenPracticeArea,
      );
      if (remote.isNotEmpty) {
        _questionPool = remote;
        questionsLoadedFromCloud = true;
      } else if (chosenPracticeArea == kDefaultPracticeAreaKey) {
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

  /// Switches the active practice area (by its Firestore doc id / question
  /// tag key, e.g. 'family_law') and reloads its question bank. The setup
  /// screen only lets the user tap areas whose [PracticeAreaDoc.active] is
  /// true, but this method itself doesn't re-enforce that so it stays
  /// simple/testable -- the active check happens once, in the UI layer.
  Future<void> setChosenPracticeArea(String areaId) async {
    if (areaId == chosenPracticeArea) return;
    chosenPracticeArea = areaId;
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
    _loadPracticeAreas();
    _loadQuestionsFromCloud();
    _refreshAdminStatus();
    _loadStudentProfile();
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

  /// True if the currently signed-in Firebase user carries the `admin`
  /// custom claim. Admins get unlimited free play (bypasses both the
  /// license check and the one-play demo limit) so they can test the app
  /// without restriction.
  ///
  /// IMPORTANT: this is deliberately NOT "any signed-in Firebase user" --
  /// now that students can also sign in via [StudentAuthService], that
  /// looser check would have quietly given every registered student
  /// unlimited free play too. [_refreshAdminStatus] keeps [isAdmin] in
  /// sync with the actual custom claim.
  bool isAdmin = false;

  Future<void> _refreshAdminStatus() async {
    isAdmin = await currentUserIsAdmin();
    notifyListeners();
  }

  /// True if the user may start a new game right now: either they're the
  /// verified admin, they have a valid license, or they haven't used their
  /// one free demo game yet.
  bool get canStartGame => isAdmin || licensed || !demoPlayUsed;

  // ---- Individual student account (optional) ----
  // A student may play entirely without an account (the license/demo flow
  // above is unaffected either way). If they ARE signed in via
  // [studentAuth], their game results also post to their own persistent
  // `students/{uid}` profile (see StudentAuthService.recordGameResult) in
  // addition to the school-level board, so their personal stats follow
  // them across devices.
  StudentProfile? studentProfile;
  bool studentProfileLoading = false;

  bool get isStudentSignedIn => studentAuth.isSignedIn;

  Future<void> _loadStudentProfile() async {
    if (!studentAuth.isSignedIn) {
      studentProfile = null;
      return;
    }
    studentProfileLoading = true;
    notifyListeners();
    try {
      studentProfile = await studentAuth.getMyProfile();
      // Pre-fill setup fields from the account so a signed-in student
      // doesn't have to retype their school/region every game -- but never
      // overwrite something they've already typed this session.
      if (studentProfile != null) {
        if (studentProfile!.school.isNotEmpty &&
            setupSchools[0] == kDefaultSchools[0]) {
          setupSchools[0] = studentProfile!.school;
        }
        // Convention: when a student account is signed in, they are always
        // "player 1" (index 0) -- this is how finishGameAndSubmit knows
        // which GamePlayer's results to also post to the account's own
        // persistent stats (see StudentAuthService.recordGameResult).
        if (setupPlayerNames[0] == 'Player 1') {
          setupPlayerNames[0] = studentProfile!.displayName;
        }
        chosenRegion ??= studentProfile!.region;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('StudentAuthService profile load failed: $e');
    }
    studentProfileLoading = false;
    notifyListeners();
  }

  /// Call after a student registers or signs in from the setup screen, and
  /// after signing out, so the rest of the app (setup form pre-fill, game
  /// results attribution) reflects the change immediately.
  Future<void> refreshStudentAccount() async {
    await _loadStudentProfile();
    // A freshly created/renamed account never carries the admin claim, but
    // re-checking here is cheap and keeps the two auth states from ever
    // silently drifting relative to each other.
    await _refreshAdminStatus();
  }

  // ---- Setup state ----
  int chosenPlayers = 2;
  GameStyle chosenStyle = GameStyle.classic;
  bool licensed = false;
  String? licensedSchool;
  String licenseError = '';

  /// Which regional board (in addition to National) this game's results
  /// should count toward. Defaults to the signed-in student's saved region
  /// (if any) once their profile loads; otherwise stays null (National
  /// only) until the player picks one at setup.
  GameRegion? chosenRegion;

  void setChosenRegion(GameRegion? region) {
    chosenRegion = region;
    notifyListeners();
  }

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
        // A license code can pre-assign a region (set by the admin when
        // issuing it) -- auto-select that regional board so the school
        // doesn't have to remember to pick it every game. Doesn't override
        // a region the player already explicitly chose this session.
        if (rec.region != null) chosenRegion ??= rec.region;
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

  /// Recovery hook: if a turn is aborted partway through by an unexpected
  /// exception (see the try/catch in GameScreen._takeTurn), this makes sure
  /// [busy] doesn't remain stuck true, which would otherwise permanently
  /// disable the "Roll & answer" button even after the UI's own retry flag
  /// is cleared. Safe to call even if nothing is actually stuck.
  void forceUnstickTurn() {
    if (busy) {
      busy = false;
      hint = "Answer correctly to advance.";
      notifyListeners();
    }
  }

  /// Submits final results for a finished game to:
  ///  1. The local on-device board (kept for backward compatibility/offline
  ///     fallback -- NOT what the leaderboard UI reads from anymore).
  ///  2. The real cloud board (`schools` collection in Firestore) -- the
  ///     National board plus, if [chosenRegion] is set, that regional
  ///     board too. This is what every device/player actually sees.
  ///  3. The signed-in student's own persistent account stats, if any
  ///     student is signed in via [studentAuth] (player index 0 by
  ///     convention -- see [_loadStudentProfile]).
  ///
  /// Returns the local board (unchanged return type/shape) so existing
  /// callers of this method keep compiling; win_dialog.dart's own
  /// "national leader" summary line now queries [cloudLeaderboard]
  /// directly instead of relying on this return value -- see GameScreen.
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
            practiceArea: chosenPracticeArea,
            region: chosenRegion,
          ),
        )
        .toList();
    if (!countsForLeaderboard) {
      return leaderboard.loadBoard();
    }

    final localBoard = await leaderboard.addResults(results);

    try {
      await cloudLeaderboard.submitResults(results);
    } catch (e) {
      // Offline or Firestore unavailable -- the local board above still
      // recorded the game, so nothing is lost; the cloud board simply
      // won't reflect this game until connectivity returns. Not fatal.
      if (kDebugMode) {
        debugPrint('CloudLeaderboardService.submitResults failed: $e');
      }
    }

    if (studentAuth.isSignedIn && players.isNotEmpty) {
      final accountPlayer = players.first;
      try {
        await studentAuth.recordGameResult(
          pointsEarned:
              accountPlayer.correct * LeaderboardService.pointsPerCorrect +
              (accountPlayer == winner ? LeaderboardService.winBonus : 0),
          correctEarned: accountPlayer.correct,
          won: accountPlayer == winner,
        );
        // Refresh the in-memory profile so the setup screen's own-stats
        // display updates immediately without needing a manual re-fetch.
        studentProfile = await studentAuth.getMyProfile();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('StudentAuthService.recordGameResult failed: $e');
        }
      }
    }

    return localBoard;
  }
}
