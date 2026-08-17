import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/practice_area.dart';
import '../models/question.dart';
import '../services/admin_auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/license_service.dart';
import '../services/pilot_code_service.dart';
import '../services/practice_area_service.dart';
import '../services/question_service.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../widgets/panel.dart';

/// Admin back-office. Authentication is handled by real Firebase
/// Authentication (email/password) — no credentials are hardcoded in the
/// client bundle. To create an admin account:
///   Firebase Console -> Build -> Authentication -> Sign-in method ->
///   enable "Email/Password" -> Users tab -> Add user.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _leaderboardService = LeaderboardService();
  final _licenseService = LicenseService();
  final _pilotCodeService = PilotCodeService();
  final _questionService = QuestionService();
  final _practiceAreaService = PracticeAreaService();
  final _authService = AdminAuthService();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _err = '';
  bool _signingIn = false;

  Map<String, SchoolStats> _board = {};
  List<LicenseCode> _codes = [];
  List<PilotCode> _pilotCodes = [];
  List<QuizQuestion> _questions = [];
  List<PracticeAreaDoc> _practiceAreas = [];
  final Set<String> _togglingAreaIds = {};
  String _season = 'Season 1';
  bool _loading = true;
  bool _savingQuestion = false;

  final _newCodeCtrl = TextEditingController();
  final _newCodeSchoolCtrl = TextEditingController();
  final _newPilotCodeCtrl = TextEditingController();
  final _newPilotCodeNoteCtrl = TextEditingController();
  final _seasonCtrl = TextEditingController();

  // Question form controllers
  final _qCategoryCtrl = TextEditingController();
  final _qQuestionCtrl = TextEditingController();
  final _qOption0Ctrl = TextEditingController();
  final _qOption1Ctrl = TextEditingController();
  final _qOption2Ctrl = TextEditingController();
  final _qOption3Ctrl = TextEditingController();
  final _qExplanationCtrl = TextEditingController();
  int _qCorrectIndex = 0;
  QuestionType _qType = QuestionType.mountain;
  String? _editingQuestionId; // null = adding a new question

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _newCodeCtrl.dispose();
    _newCodeSchoolCtrl.dispose();
    _newPilotCodeCtrl.dispose();
    _newPilotCodeNoteCtrl.dispose();
    _seasonCtrl.dispose();
    _qCategoryCtrl.dispose();
    _qQuestionCtrl.dispose();
    _qOption0Ctrl.dispose();
    _qOption1Ctrl.dispose();
    _qOption2Ctrl.dispose();
    _qOption3Ctrl.dispose();
    _qExplanationCtrl.dispose();
    super.dispose();
  }

  bool get _authed => _authService.isSignedIn;

  Future<void> _tryLogin() async {
    setState(() {
      _signingIn = true;
      _err = '';
    });
    final error = await _authService.signIn(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _signingIn = false);
    if (error != null) {
      setState(() => _err = error);
      return;
    }
    setState(() {});
    _loadAll();
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) setState(() {});
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final board = await _leaderboardService.loadBoard();
    final codes = await _licenseService.getAll();
    final pilotCodes = await _pilotCodeService.getAll();
    final season = await _leaderboardService.getSeason();
    final questions = await _questionService.getAll();
    final practiceAreas = await _practiceAreaService.getAll();
    if (!mounted) return;
    setState(() {
      _board = board;
      _codes = codes;
      _pilotCodes = pilotCodes;
      _season = season;
      _seasonCtrl.text = season;
      _questions = questions;
      _practiceAreas = practiceAreas;
      _loading = false;
    });
  }

  // ---- Practice area management ----

  Future<void> _togglePracticeArea(PracticeAreaDoc area, bool newValue) async {
    setState(() => _togglingAreaIds.add(area.id));
    try {
      await _practiceAreaService.setActive(area.id, newValue);
      final areas = await _practiceAreaService.getAll();
      if (!mounted) return;
      setState(() {
        _practiceAreas = areas;
        _togglingAreaIds.remove(area.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _togglingAreaIds.remove(area.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update "${area.displayName}": $e')),
      );
    }
  }

  Future<void> _removeSchool(String school) async {
    final confirm = await _confirm(
      'Remove "$school" and all its scores from the board?',
    );
    if (confirm != true) return;
    await _leaderboardService.removeSchool(school);
    _loadAll();
  }

  Future<void> _removeCode(String code) async {
    final confirm = await _confirm('Delete license code "$code"?');
    if (confirm != true) return;
    await _licenseService.delete(code);
    _loadAll();
  }

  Future<void> _addCode() async {
    final code = _newCodeCtrl.text.trim().toUpperCase();
    final school = _newCodeSchoolCtrl.text.trim();
    if (code.isEmpty) return;
    await _licenseService.upsert(
      code: code,
      school: school,
      type: school.isEmpty ? 'classroom' : 'school',
    );
    _newCodeCtrl.clear();
    _newCodeSchoolCtrl.clear();
    _loadAll();
  }

  // ---- Individual Pilot ($20) code management ----
  // Option A / manual: there is no Stripe webhook for this collection. The
  // admin sees a $20 payment come in via their own Stripe dashboard/email,
  // then generates a code here (or types a custom one) and emails it to the
  // student, who redeems it once in the app's "Join the Individual Pilot"
  // form.

  String _generatePilotCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I/L
    final rand = Random();
    final suffix = List.generate(
      6,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
    return 'PILOT-$suffix';
  }

  Future<void> _addPilotCode() async {
    var code = _newPilotCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) code = _generatePilotCode();
    await _pilotCodeService.create(
      code: code,
      note: _newPilotCodeNoteCtrl.text,
    );
    _newPilotCodeCtrl.clear();
    _newPilotCodeNoteCtrl.clear();
    _loadAll();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Code "$code" created and copied to clipboard')),
    );
  }

  Future<void> _removePilotCode(String code) async {
    final confirm = await _confirm('Delete pilot code "$code"?');
    if (confirm != true) return;
    await _pilotCodeService.delete(code);
    _loadAll();
  }

  Future<void> _copyPilotCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied "$code"')));
  }

  Future<void> _saveSeason() async {
    final label = _seasonCtrl.text.trim().isEmpty
        ? 'Season 1'
        : _seasonCtrl.text.trim();
    await _leaderboardService.setSeason(label);
    _loadAll();
  }

  Future<void> _resetSeason() async {
    final confirm = await _confirm(
      'Clear ALL school and player scores to start a fresh season? This cannot be undone.',
    );
    if (confirm != true) return;
    await _leaderboardService.clearBoard();
    _loadAll();
  }

  // ---- Question management ----

  void _clearQuestionForm() {
    _editingQuestionId = null;
    _qCategoryCtrl.clear();
    _qQuestionCtrl.clear();
    _qOption0Ctrl.clear();
    _qOption1Ctrl.clear();
    _qOption2Ctrl.clear();
    _qOption3Ctrl.clear();
    _qExplanationCtrl.clear();
    _qCorrectIndex = 0;
    _qType = QuestionType.mountain;
  }

  void _startEditQuestion(QuizQuestion q) {
    setState(() {
      _editingQuestionId = q.id;
      _qCategoryCtrl.text = q.category;
      _qQuestionCtrl.text = q.question;
      _qOption0Ctrl.text = q.options.isNotEmpty ? q.options[0] : '';
      _qOption1Ctrl.text = q.options.length > 1 ? q.options[1] : '';
      _qOption2Ctrl.text = q.options.length > 2 ? q.options[2] : '';
      _qOption3Ctrl.text = q.options.length > 3 ? q.options[3] : '';
      _qExplanationCtrl.text = q.explanation;
      _qCorrectIndex = q.correctIndex;
      _qType = q.type;
    });
  }

  Future<void> _saveQuestion() async {
    final category = _qCategoryCtrl.text.trim();
    final question = _qQuestionCtrl.text.trim();
    final options = [
      _qOption0Ctrl.text.trim(),
      _qOption1Ctrl.text.trim(),
      _qOption2Ctrl.text.trim(),
      _qOption3Ctrl.text.trim(),
    ];
    final explanation = _qExplanationCtrl.text.trim();

    if (category.isEmpty ||
        question.isEmpty ||
        options.any((o) => o.isEmpty) ||
        explanation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in every field before saving.'),
        ),
      );
      return;
    }

    setState(() => _savingQuestion = true);
    final q = QuizQuestion(
      id: _editingQuestionId,
      category: category,
      type: _qType,
      question: question,
      options: options,
      correctIndex: _qCorrectIndex,
      explanation: explanation,
    );
    if (_editingQuestionId != null) {
      await _questionService.update(q);
    } else {
      await _questionService.add(q);
    }
    _clearQuestionForm();
    await _loadAll();
    if (!mounted) return;
    setState(() => _savingQuestion = false);
  }

  Future<void> _deleteQuestion(QuizQuestion q) async {
    if (q.id == null) return;
    final confirm = await _confirm('Delete this question?\n\n"${q.question}"');
    if (confirm != true) return;
    await _questionService.delete(q.id!);
    if (_editingQuestionId == q.id) _clearQuestionForm();
    _loadAll();
  }

  Future<bool?> _confirm(String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C3157),
        title: const Text('Confirm', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forStyle(GameStyle.classic);
    return Scaffold(
      backgroundColor: colors.navyDeep,
      appBar: AppBar(
        backgroundColor: colors.navy,
        title: Text(
          'Admin — Paralegal Quest',
          style: AppText.cinzel(fontSize: 16, color: colors.brassBright),
        ),
        actions: _authed
            ? [
                TextButton(
                  onPressed: _signOut,
                  child: Text(
                    'Sign out',
                    style: AppText.spectral(color: colors.brass),
                  ),
                ),
              ]
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.navy, colors.navyDeep],
          ),
        ),
        child: SafeArea(
          child: _authed
              ? (_loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBackOffice(colors))
              : _buildLogin(colors),
        ),
      ),
    );
  }

  Widget _buildLogin(GameColors colors) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Panel(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '🔧 Owner admin',
                  style: AppText.cinzel(
                    fontSize: 16,
                    color: colors.brassBright,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Sign in with your Firebase admin account.',
                  style: AppText.spectral(fontSize: 14, color: colors.cream),
                ),
                const SizedBox(height: 14),
                _field(_emailCtrl, 'Email', colors, obscure: false),
                const SizedBox(height: 10),
                _field(
                  _passCtrl,
                  'Password',
                  colors,
                  obscure: true,
                  onSubmit: (_) => _tryLogin(),
                ),
                if (_err.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _err,
                    style: const TextStyle(
                      color: Color(0xFFF0A8A6),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _signingIn ? null : _tryLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brassBright,
                    foregroundColor: const Color(0xFF1A140C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _signingIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Sign in',
                          style: AppText.cinzel(
                            fontSize: 14,
                            color: const Color(0xFF1A140C),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    GameColors colors, {
    bool obscure = false,
    ValueChanged<String>? onSubmit,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      onSubmitted: onSubmit,
      style: TextStyle(color: colors.cream),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.cream.withValues(alpha: 0.4)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.accent.withValues(alpha: 0.35)),
        ),
      ),
    );
  }

  Widget _buildBackOffice(GameColors colors) {
    final rows = _leaderboardService.standings(_board);
    final totalGames = rows.fold<int>(0, (n, r) => n + r.value.games);
    final totalPlayers = rows.fold<int>(
      0,
      (n, r) => n + r.value.players.length,
    );
    final adminEmail = _authService.currentUser?.email ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Panel(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$adminEmail — $_season',
                  style: AppText.cinzel(
                    fontSize: 13,
                    color: colors.brassBright,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _stat('${rows.length}', 'Schools', colors),
                    const SizedBox(width: 10),
                    _stat('$totalPlayers', 'Players', colors),
                    const SizedBox(width: 10),
                    _stat('$totalGames', 'Games played', colors),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'SCHOOL STANDINGS',
                  style: AppText.cinzel(
                    fontSize: 12,
                    color: colors.brass,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  Text(
                    'No scores yet.',
                    style: AppText.spectral(
                      fontSize: 12,
                      color: colors.cream.withValues(alpha: 0.6),
                    ),
                  )
                else
                  ...rows.asMap().entries.map((e) {
                    final i = e.key;
                    final r = e.value;
                    final players = r.value.players.entries
                        .map((p) => '${p.key} (${p.value.points})')
                        .join(', ');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(color: colors.brass),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.key,
                                  style: TextStyle(
                                    color: colors.cream,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  players.isEmpty ? '—' : players,
                                  style: TextStyle(
                                    color: colors.cream.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${r.value.points}',
                            style: TextStyle(color: colors.brassBright),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _removeSchool(r.key),
                            child: const Text(
                              'Remove',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 18),
                Text(
                  'LICENSE CODES',
                  style: AppText.cinzel(
                    fontSize: 12,
                    color: colors.brass,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stored in Firestore — codes work on any device instantly.',
                  style: AppText.spectral(
                    fontSize: 11,
                    color: colors.cream.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 8),
                if (_codes.isEmpty)
                  Text(
                    'No codes yet.',
                    style: AppText.spectral(
                      fontSize: 12,
                      color: colors.cream.withValues(alpha: 0.6),
                    ),
                  ),
                ..._codes.map((c) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${c.code}  ·  ${c.school.isNotEmpty ? c.school : "(any school)"}  ·  ${c.type}${c.used ? "  ·  used" : ""}',
                            style: TextStyle(
                              color: colors.cream,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _removeCode(c.code),
                          child: const Text(
                            'Delete',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 160,
                      child: _field(_newCodeCtrl, 'NEW-CODE', colors),
                    ),
                    SizedBox(
                      width: 200,
                      child: _field(
                        _newCodeSchoolCtrl,
                        'School (blank = classroom)',
                        colors,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _addCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brassBright,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Add code'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '🧪 INDIVIDUAL PILOT CODES — \$20',
                  style: AppText.cinzel(
                    fontSize: 12,
                    color: colors.brass,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manual (Option A): after seeing a \$20 payment in your Stripe '
                  'dashboard, generate a code below and email it to the student. '
                  'Each code works once. No webhook is wired to this collection.',
                  style: AppText.spectral(
                    fontSize: 11,
                    color: colors.cream.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 8),
                if (_pilotCodes.isEmpty)
                  Text(
                    'No pilot codes yet.',
                    style: AppText.spectral(
                      fontSize: 12,
                      color: colors.cream.withValues(alpha: 0.6),
                    ),
                  ),
                ..._pilotCodes.map((c) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${c.code}'
                            '${c.used ? "  ·  used${c.usedByEmail != null ? " by ${c.usedByEmail}" : ""}" : "  ·  unused"}'
                            '${c.note != null && c.note!.isNotEmpty ? "  ·  ${c.note}" : ""}',
                            style: TextStyle(
                              color: colors.cream,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _copyPilotCode(c.code),
                          child: const Text(
                            'Copy',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _removePilotCode(c.code),
                          child: const Text(
                            'Delete',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 160,
                      child: _field(
                        _newPilotCodeCtrl,
                        'Leave blank to auto-generate',
                        colors,
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: _field(
                        _newPilotCodeNoteCtrl,
                        'Note (e.g. student email)',
                        colors,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _addPilotCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brassBright,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Generate code'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'SEASON',
                  style: AppText.cinzel(
                    fontSize: 12,
                    color: colors.brass,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 200,
                      child: _field(_seasonCtrl, 'Season label', colors),
                    ),
                    OutlinedButton(
                      onPressed: _saveSeason,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.brass,
                      ),
                      child: const Text('Save label'),
                    ),
                    OutlinedButton(
                      onPressed: _resetSeason,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF0A8A6),
                      ),
                      child: const Text('Start new season (clear scores)'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'PRACTICE AREAS',
                  style: AppText.cinzel(
                    fontSize: 12,
                    color: colors.brass,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toggle an area on to unlock it in the setup screen menu '
                  'for every player, instantly -- no app update needed.',
                  style: AppText.spectral(
                    fontSize: 11,
                    color: colors.cream.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 8),
                if (_practiceAreas.isEmpty)
                  Text(
                    'No practice areas found. Seed the "practiceAreas" '
                    'Firestore collection to populate this list.',
                    style: AppText.spectral(
                      fontSize: 12,
                      color: colors.cream.withValues(alpha: 0.6),
                    ),
                  ),
                ..._practiceAreas.map((area) {
                  final busy = _togglingAreaIds.contains(area.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          practiceAreaEmoji(area.icon),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                area.displayName,
                                style: TextStyle(
                                  color: colors.cream,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${area.id}'
                                '${area.questionCount != null ? '  ·  ${area.questionCount} questions' : ''}',
                                style: TextStyle(
                                  color: colors.cream.withValues(alpha: 0.55),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          area.active ? 'Active' : 'Coming soon',
                          style: TextStyle(
                            color: area.active
                                ? const Color(0xFFA8E0B6)
                                : colors.cream.withValues(alpha: 0.5),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (busy)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Switch(
                            value: area.active,
                            activeThumbColor: colors.brassBright,
                            onChanged: (v) => _togglePracticeArea(area, v),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 18),
                Text(
                  'MANAGE QUESTIONS',
                  style: AppText.cinzel(
                    fontSize: 12,
                    color: colors.brass,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stored in Firestore — edits appear in the game for every '
                  'player, instantly, with no app update needed.',
                  style: AppText.spectral(
                    fontSize: 11,
                    color: colors.cream.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_questions.length} question${_questions.length == 1 ? '' : 's'} in the bank',
                  style: AppText.spectral(
                    fontSize: 11,
                    color: colors.cream.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                if (_questions.isEmpty)
                  Text(
                    'No questions yet.',
                    style: AppText.spectral(
                      fontSize: 12,
                      color: colors.cream.withValues(alpha: 0.6),
                    ),
                  ),
                ..._questions.map((q) {
                  final isEditing = _editingQuestionId == q.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isEditing
                          ? colors.brassBright.withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: isEditing
                          ? Border.all(
                              color: colors.brassBright.withValues(alpha: 0.6),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${q.category} · ${q.type == QuestionType.mountain ? "Mountain" : "Cave"}',
                                style: TextStyle(
                                  color: colors.brass,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                q.question,
                                style: TextStyle(
                                  color: colors.cream,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _startEditQuestion(q),
                          child: const Text(
                            'Edit',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _deleteQuestion(q),
                          child: const Text(
                            'Delete',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Text(
                  _editingQuestionId != null
                      ? 'EDITING QUESTION'
                      : 'ADD NEW QUESTION',
                  style: AppText.cinzel(
                    fontSize: 11,
                    color: colors.brassBright,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 200,
                      child: _field(_qCategoryCtrl, 'Category', colors),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<QuestionType>(
                        initialValue: _qType,
                        dropdownColor: const Color(0xFF1C3157),
                        style: TextStyle(color: colors.cream),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: colors.accent.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: QuestionType.mountain,
                            child: Text('Mountain'),
                          ),
                          DropdownMenuItem(
                            value: QuestionType.cave,
                            child: Text('Cave'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _qType = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _field(_qQuestionCtrl, 'Question text', colors),
                const SizedBox(height: 8),
                ...List.generate(4, (i) {
                  final ctrl = [
                    _qOption0Ctrl,
                    _qOption1Ctrl,
                    _qOption2Ctrl,
                    _qOption3Ctrl,
                  ][i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: i,
                          groupValue: _qCorrectIndex,
                          activeColor: colors.brassBright,
                          onChanged: (v) {
                            if (v != null) setState(() => _qCorrectIndex = v);
                          },
                        ),
                        Expanded(
                          child: _field(
                            ctrl,
                            'Option ${i + 1}${i == _qCorrectIndex ? " (correct)" : ""}',
                            colors,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Text(
                  'Select the radio button next to the correct answer.',
                  style: AppText.spectral(
                    fontSize: 10.5,
                    color: colors.cream.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                _field(
                  _qExplanationCtrl,
                  'Explanation (shown after answer)',
                  colors,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _savingQuestion ? null : _saveQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brassBright,
                        foregroundColor: Colors.black,
                      ),
                      child: _savingQuestion
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _editingQuestionId != null
                                  ? 'Save changes'
                                  : 'Add question',
                            ),
                    ),
                    if (_editingQuestionId != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => setState(_clearQuestionForm),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.brass,
                        ),
                        child: const Text('Cancel edit'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, GameColors colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppText.cinzel(fontSize: 20, color: colors.brassBright),
            ),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: colors.cream.withValues(alpha: 0.7),
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
