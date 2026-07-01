import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../widgets/panel.dart';

/// ⚠️ SECURITY NOTE: These credentials live in the client app bundle and are
/// not truly secure (similar to the web prototype). Replace before publishing
/// and consider moving auth to a real backend (e.g. Firebase Auth) for
/// production-grade security.
const String kAdminEmail = 'rosedavenportt@gmail.com';
const String kAdminPassword = 'change-this';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _service = LeaderboardService();
  bool _authed = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _err = '';

  Map<String, SchoolStats> _board = {};
  Map<String, Map<String, String>> _codes = {};
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

  void _tryLogin() {
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text;
    if (email == kAdminEmail.toLowerCase() && pass == kAdminPassword) {
      setState(() => _authed = true);
      _loadAll();
    } else {
      setState(() => _err = 'Incorrect email or password.');
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final board = await _service.loadBoard();
    final codes = await _service.getAllCodes();
    final season = await _service.getSeason();
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
    await _service.removeSchool(school);
    _loadAll();
  }

  Future<void> _removeCode(String code) async {
    final confirm = await _confirm('Delete license code "$code"?');
    if (confirm != true) return;
    await _service.deleteCustomCode(code);
    _loadAll();
  }

  Future<void> _addCode() async {
    final code = _newCodeCtrl.text.trim().toUpperCase();
    final school = _newCodeSchoolCtrl.text.trim();
    if (code.isEmpty) return;
    await _service.saveCustomCode(code, {
      'school': school,
      'type': school.isEmpty ? 'classroom' : 'school',
    });
    _newCodeCtrl.clear();
    _newCodeSchoolCtrl.clear();
    _loadAll();
  }

  Future<void> _saveSeason() async {
    final label = _seasonCtrl.text.trim().isEmpty
        ? 'Season 1'
        : _seasonCtrl.text.trim();
    await _service.setSeason(label);
    _loadAll();
  }

  Future<void> _resetSeason() async {
    final confirm = await _confirm(
      'Clear ALL school and player scores to start a fresh season? This cannot be undone.',
    );
    if (confirm != true) return;
    await _service.clearBoard();
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
                  onPressed: () => setState(() => _authed = false),
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
          child: _authed ? _buildBackOffice(colors) : _buildLogin(colors),
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
                  'Sign in to your admin account.',
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
                  onPressed: _tryLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brassBright,
                    foregroundColor: const Color(0xFF1A140C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    final rows = _service.standings(_board);
    final totalGames = rows.fold<int>(0, (n, r) => n + r.value.games);
    final totalPlayers = rows.fold<int>(
      0,
      (n, r) => n + r.value.players.length,
    );

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
                  '$kAdminEmail — $_season',
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
                const SizedBox(height: 8),
                ..._codes.entries.map((e) {
                  final builtin = LeaderboardService.builtInCodes.containsKey(
                    e.key,
                  );
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
                            '${e.key}  ·  ${e.value['school']?.isNotEmpty == true ? e.value['school'] : "(any school)"}  ·  ${e.value['type']}',
                            style: TextStyle(
                              color: colors.cream,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        builtin
                            ? Text(
                                'built-in',
                                style: TextStyle(
                                  color: colors.cream.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              )
                            : TextButton(
                                onPressed: () => _removeCode(e.key),
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
