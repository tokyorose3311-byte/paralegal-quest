import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/region.dart';
import '../services/commerce_config.dart';
import '../services/game_provider.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import 'panel.dart';
import 'region_picker.dart';

/// Optional individual player account panel for the setup screen.
///
/// Signing in/registering is entirely OPTIONAL -- the free demo and
/// license-code flows work exactly as before with no account at all. The
/// benefit of an account is purely that a student's OWN stats (points,
/// correct answers, games, wins) are tied to a real Firebase uid and follow
/// them across devices, instead of just being whatever name they happened
/// to type at setup that session (which could collide with another student
/// typing the same name at the same school).
class StudentAccountPanel extends StatefulWidget {
  final GameColors colors;

  const StudentAccountPanel({super.key, required this.colors});

  @override
  State<StudentAccountPanel> createState() => _StudentAccountPanelState();
}

enum _Mode { signedOut, signIn, register }

class _StudentAccountPanelState extends State<StudentAccountPanel> {
  _Mode _mode = _Mode.signedOut;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  GameRegion? _region;
  bool _busy = false;
  String? _error;

  // Leaderboard counter state -- shown so the sign-in prompt reads as
  // "join the leaderboard" rather than "create an account" (which could be
  // mistaken for a paywall/unlock gate; it has nothing to do with access).
  int? _totalRanked;
  int? _myRank;

  @override
  void initState() {
    super.initState();
    _loadCounter();
  }

  Future<void> _loadCounter() async {
    final gp = context.read<GameProvider>();
    try {
      if (gp.isStudentSignedIn) {
        final rank = await gp.studentAuth.myRank();
        if (mounted) setState(() => _myRank = rank);
      } else {
        final total = await gp.studentAuth.totalRankedCount();
        if (mounted) setState(() => _totalRanked = total);
      }
    } catch (_) {
      // Offline or Firestore unavailable -- the counter is a nice-to-have,
      // never block the sign-in/register UI on it.
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(GameProvider gp) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    String? error;
    if (_mode == _Mode.register) {
      error = await gp.studentAuth.register(
        email: email,
        password: password,
        displayName: _nameCtrl.text,
        school: _schoolCtrl.text,
        region: _region,
        pilotCode: _codeCtrl.text,
      );
    } else {
      error = await gp.studentAuth.signIn(email, password);
    }
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    await gp.refreshStudentAccount();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _mode = _Mode.signedOut; // collapses back to the signed-in summary view
      _passCtrl.clear();
      _codeCtrl.clear();
    });
    _loadCounter();
  }

  Future<void> _signOut(GameProvider gp) async {
    await gp.studentAuth.signOut();
    await gp.refreshStudentAccount();
    if (mounted) setState(() {});
  }

  Future<void> _launchPilotCheckout() async {
    final uri = Uri.parse(kStripePilotUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore failures silently in-app; the link still exists for manual open
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final gp = context.watch<GameProvider>();

    if (gp.isStudentSignedIn) {
      final p = gp.studentProfile;
      return Panel(
        colors: colors,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: colors.brassBright, size: 18),
                const SizedBox(width: 8),
                Text(
                  'INDIVIDUAL LEADERBOARD',
                  style: AppText.cinzel(
                    fontSize: 11,
                    color: colors.brass,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (_myRank != null) _rankBadge(colors, _myRank!),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.verified_user, color: colors.brassBright, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p != null
                            ? 'Ranked as ${p.displayName}'
                            : 'Signed in — loading your stats…',
                        style: AppText.cinzel(
                          fontSize: 13,
                          color: colors.cream,
                        ),
                      ),
                      if (p != null)
                        Text(
                          '${p.points} pts • ${p.correct} correct • ${p.games} ${p.games == 1 ? "game" : "games"}'
                          '${p.region != null ? " • ${p.region!.emoji} ${p.region!.label}" : ""}',
                          style: AppText.spectral(
                            fontSize: 11,
                            color: colors.cream.withValues(alpha: 0.65),
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _signOut(gp),
                  child: Text(
                    'Sign out',
                    style: AppText.spectral(fontSize: 12, color: colors.brass),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_mode == _Mode.signedOut) {
      return Panel(
        colors: colors,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: colors.brassBright, size: 18),
                const SizedBox(width: 8),
                Text(
                  'INDIVIDUAL LEADERBOARD',
                  style: AppText.cinzel(
                    fontSize: 11,
                    color: colors.brass,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                _pilotBadge(colors),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: colors.cream.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _totalRanked != null && _totalRanked! > 0
                        ? "Individual Pilot ($_totalRanked joined so far) — get your own ranked profile with points, correct answers, and wins, on any device."
                        : 'Individual Pilot — get your own ranked profile with points, correct answers, and wins, on any device.',
                    style: AppText.spectral(
                      fontSize: 12,
                      color: colors.cream.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => setState(() => _mode = _Mode.signIn),
                  child: Text(
                    'Sign in',
                    style: AppText.cinzel(fontSize: 12, color: colors.brass),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _mode = _Mode.register),
                  child: Text(
                    'Join the pilot — \$20',
                    style: AppText.cinzel(
                      fontSize: 12,
                      color: colors.brassBright,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Sign-in / register form.
    final isRegister = _mode == _Mode.register;
    return Panel(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isRegister ? 'Join the Individual Pilot' : 'Sign in',
                  style: AppText.cinzel(
                    fontSize: 14,
                    color: colors.brassBright,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.cream, size: 18),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _mode = _Mode.signedOut;
                        _error = null;
                      }),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isRegister
                ? 'Optional and separate from your demo/license — a \$20, one-time '
                      'promotional pilot price for early testers. Pay via our secure '
                      'Stripe link, then enter the access code we email you below. '
                      'It puts your own points, correct answers, and wins on the '
                      'leaderboard under your name, following you across devices.'
                : 'Sign in to your existing Individual Pilot account.',
            style: AppText.spectral(
              fontSize: 11,
              color: colors.cream.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          if (isRegister) ...[
            _field(_nameCtrl, 'Your name', colors),
            const SizedBox(height: 8),
            _field(_schoolCtrl, 'School', colors),
            const SizedBox(height: 8),
          ],
          _field(_emailCtrl, 'Email', colors),
          const SizedBox(height: 8),
          _field(_passCtrl, 'Password', colors, obscure: true),
          if (isRegister) ...[
            const SizedBox(height: 10),
            Text(
              'REGION (optional)',
              style: AppText.cinzel(
                fontSize: 10.5,
                color: colors.brass,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            RegionPicker(
              selected: _region,
              onChanged: (r) => setState(() => _region = r),
              colors: colors,
            ),
            const SizedBox(height: 10),
            Text(
              'PILOT ACCESS CODE',
              style: AppText.cinzel(
                fontSize: 10.5,
                color: colors.brass,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            _field(_codeCtrl, 'Enter your code from Stripe payment', colors),
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 13,
                  color: colors.cream.withValues(alpha: 0.55),
                ),
                Text(
                  "Don't have a code yet? ",
                  style: AppText.spectral(
                    fontSize: 11,
                    color: colors.cream.withValues(alpha: 0.6),
                  ),
                ),
                InkWell(
                  onTap: _busy ? null : () => _launchPilotCheckout(),
                  child: Text(
                    'Pay \$20 pilot price →',
                    style: AppText.spectral(
                      fontSize: 11,
                      color: colors.brassBright,
                      fontWeight: FontWeight.w600,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: AppText.spectral(
                fontSize: 12,
                color: const Color(0xFFF0B8B6),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : () => _submit(gp),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brassBright,
                foregroundColor: const Color(0xFF1A140C),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1A140C),
                      ),
                    )
                  : Text(
                      isRegister ? 'Activate my pilot account' : 'Sign in',
                      style: AppText.cinzel(
                        fontSize: 13,
                        color: const Color(0xFF1A140C),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _mode = isRegister ? _Mode.signIn : _Mode.register;
                      _error = null;
                    }),
              child: Text(
                isRegister
                    ? 'Already have a pilot account? Sign in'
                    : "Don't have an account? Join the \$20 pilot",
                style: AppText.spectral(fontSize: 11.5, color: colors.brass),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(GameColors colors, int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.brassBright, width: 1.1),
      ),
      child: Text(
        '#$rank nationally',
        style: AppText.cinzel(fontSize: 10.5, color: colors.brassBright),
      ),
    );
  }

  Widget _pilotBadge(GameColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.brassBright, width: 1.1),
      ),
      child: Text(
        'Pilot price \$20',
        style: AppText.cinzel(fontSize: 10.5, color: colors.brassBright),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    GameColors colors, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: AppText.spectral(fontSize: 14, color: colors.cream),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.spectral(
          fontSize: 13,
          color: colors.cream.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colors.accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colors.accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.brassBright, width: 1.5),
        ),
      ),
    );
  }
}
