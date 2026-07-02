import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/license_service.dart';
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
  final _authService = AdminAuthService();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _err = '';
  bool _signingIn = false;

  Map<String, SchoolStats> _board = {};
  List<LicenseCode> _codes = [];
  String _season = 'Season 1';
  bool _loading = true;

  final _newCodeCtrl = TextEditingController();
  final _newCodeSchoolCtrl = TextEditingController();
  final _seasonCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _newCodeCtrl.dispose();
    _newCodeSchoolCtrl.dispose();
    _seasonCtrl.dispose();
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
    final season = await _leaderboardService.getSeason();
    if (!mounted) return;
    setState(() {
      _board = board;
      _codes = codes;
      _season = season;
      _seasonCtrl.text = season;
      _loading = false;
    });
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
