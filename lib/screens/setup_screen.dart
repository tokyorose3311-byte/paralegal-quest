import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/game_provider.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../widgets/plaque_header.dart';
import '../widgets/panel.dart';
import '../widgets/choice_card.dart';
import 'game_screen.dart';
import 'admin_screen.dart';

// ===================== COMMERCE CONFIG — edit these =====================
const String kStripeSeasonUrl =
    "https://buy.stripe.com/3cI14p64O979cXO8kcdMI00";
const String kStripeSchoolUrl =
    "https://buy.stripe.com/aFa00l0Ku1EH7Du9ogdMI02";
const String kStripeClassroomUrl =
    "https://buy.stripe.com/3cI28t0Ku0AD8HygQIdMI01";
// =========================================================================

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _licenseCtrl = TextEditingController();
  late List<TextEditingController> _nameCtrls;
  late List<TextEditingController> _schoolCtrls;

  @override
  void initState() {
    super.initState();
    final gp = context.read<GameProvider>();
    _nameCtrls = List.generate(
      4,
      (i) => TextEditingController(text: gp.setupPlayerNames[i]),
    );
    _schoolCtrls = List.generate(
      4,
      (i) => TextEditingController(text: gp.setupSchools[i]),
    );
  }

  @override
  void dispose() {
    _licenseCtrl.dispose();
    for (final c in _nameCtrls) {
      c.dispose();
    }
    for (final c in _schoolCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _activate() async {
    final gp = context.read<GameProvider>();
    await gp.activateLicense(_licenseCtrl.text);
    if (gp.licensed && gp.licensedSchool != null) {
      for (int i = 0; i < 4; i++) {
        _schoolCtrls[i].text = gp.licensedSchool!;
      }
    }
    setState(() {});
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore failures silently in-app; the link still exists for manual open
    }
  }

  void _start() {
    final gp = context.read<GameProvider>();
    for (int i = 0; i < gp.chosenPlayers; i++) {
      gp.setPlayerName(i, _nameCtrls[i].text);
      gp.setSchoolName(i, _schoolCtrls[i].text);
    }
    gp.startGame();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final colors = GameColors.forStyle(gp.chosenStyle);

    return Scaffold(
      backgroundColor: colors.navyDeep,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.navy, colors.navyDeep],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                PlaqueHeader(colors: colors),
                const SizedBox(height: 18),
                Panel(
                  colors: colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'Build your case',
                          style: AppText.cinzel(
                            fontSize: 20,
                            color: colors.brassBright,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // License
                      _label('School / classroom license', colors),
                      Row(
                        children: [
                          Expanded(
                            child: _textField(
                              controller: _licenseCtrl,
                              hint: 'Enter license code (e.g. CTC-2026)',
                              colors: colors,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ghostButton('Activate', colors, _activate),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: gp.licensed
                              ? colors.good.withValues(alpha: 0.18)
                              : colors.bad.withValues(alpha: 0.16),
                          border: Border.all(
                            color: gp.licensed
                                ? colors.good.withValues(alpha: 0.5)
                                : colors.bad.withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          gp.licensed
                              ? (gp.licensedSchool != null
                                    ? "✓ Licensed — competing as ${gp.licensedSchool}. Scores count nationally."
                                    : "✓ Licensed — scores count nationally.")
                              : "Demo mode — scores won't count nationally. Enter a license to compete.",
                          style: AppText.spectral(
                            fontSize: 12.5,
                            color: gp.licensed
                                ? const Color(0xFFA8E0B6)
                                : const Color(0xFFF0B8B6),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),
                      _label('Number of attorneys', colors),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _playerChoice(
                            1,
                            '⚖️',
                            'Solo',
                            'Practice run',
                            gp,
                            colors,
                          ),
                          _playerChoice(
                            2,
                            '⚔️',
                            '2 Players',
                            'Head to head',
                            gp,
                            colors,
                          ),
                          _playerChoice(
                            3,
                            '👥',
                            '3 Players',
                            'Full bench',
                            gp,
                            colors,
                          ),
                          _playerChoice(
                            4,
                            '🏛️',
                            '4 Players',
                            'Open court',
                            gp,
                            colors,
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),
                      _label('Players & their school', colors),
                      ...List.generate(
                        gp.chosenPlayers,
                        (i) => _nameRow(i, gp, colors),
                      ),

                      const SizedBox(height: 22),
                      _label('Choose your style', colors),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _styleChoice(
                            GameStyle.classic,
                            '😄',
                            'Classic',
                            gp,
                            colors,
                          ),
                          _styleChoice(
                            GameStyle.adventure,
                            '😎',
                            'Adventure',
                            gp,
                            colors,
                          ),
                          _styleChoice(
                            GameStyle.mystical,
                            '🤩',
                            'Mystical',
                            gp,
                            colors,
                          ),
                          _styleChoice(
                            GameStyle.patriotic,
                            '🤓',
                            'Patriotic',
                            gp,
                            colors,
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),
                      Center(
                        child: ElevatedButton(
                          onPressed: _start,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.brassBright,
                            foregroundColor: const Color(0xFF1A140C),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 34,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 6,
                          ),
                          child: Text(
                            'Take the bench',
                            style: AppText.cinzel(
                              fontSize: 16,
                              color: const Color(0xFF1A140C),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      _stripePlan(
                        icon: '⭐',
                        name: 'Season Pass',
                        desc:
                            'Full access for individual players — billed quarterly',
                        price: '\$60',
                        priceSub: '/qtr',
                        btnLabel: 'Subscribe',
                        btnColor: colors.brassBright,
                        btnFg: const Color(0xFF1A140C),
                        onTap: () => _launch(kStripeSeasonUrl),
                        colors: colors,
                      ),
                      const SizedBox(height: 10),
                      _stripePlan(
                        icon: '🏛️',
                        name: 'School License',
                        desc: 'Unlimited students at your institution',
                        price: '\$2,500',
                        priceSub: '',
                        btnLabel: 'Get License',
                        btnColor: const Color(0xFF2F6FAD),
                        btnFg: Colors.white,
                        onTap: () => _launch(kStripeSchoolUrl),
                        colors: colors,
                      ),
                      const SizedBox(height: 10),
                      _stripePlan(
                        icon: '👥',
                        name: 'Classroom License',
                        desc: 'One class, one semester',
                        price: '\$850',
                        priceSub: '',
                        btnLabel: 'Get License',
                        btnColor: colors.good,
                        btnFg: Colors.white,
                        onTap: () => _launch(kStripeClassroomUrl),
                        colors: colors,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            text: '🔒 Secured by ',
                            style: AppText.spectral(
                              fontSize: 11.5,
                              color: colors.cream.withValues(alpha: 0.6),
                            ),
                            children: [
                              TextSpan(
                                text: 'Stripe',
                                style: AppText.spectral(
                                  fontSize: 11.5,
                                  color: colors.brass,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  ),
                  child: Text(
                    'Admin',
                    style: AppText.spectral(
                      fontSize: 12,
                      color: colors.brass,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, GameColors colors) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: AppText.cinzel(
        fontSize: 12,
        color: colors.brass,
        letterSpacing: 1.4,
      ),
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required GameColors colors,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: AppText.spectral(fontSize: 15, color: colors.cream),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.spectral(
          fontSize: 14,
          color: colors.cream.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: enabled ? 0.06 : 0.03),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
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

  Widget _ghostButton(String label, GameColors colors, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.brass,
        side: BorderSide(color: colors.accent, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: AppText.cinzel(fontSize: 13, color: colors.brass),
      ),
    );
  }

  Widget _playerChoice(
    int n,
    String emoji,
    String name,
    String sub,
    GameProvider gp,
    GameColors colors,
  ) {
    return SizedBox(
      width: 130,
      child: ChoiceCard(
        emoji: emoji,
        name: name,
        sub: sub,
        selected: gp.chosenPlayers == n,
        onTap: () => gp.setChosenPlayers(n),
        colors: colors,
      ),
    );
  }

  Widget _styleChoice(
    GameStyle style,
    String emoji,
    String name,
    GameProvider gp,
    GameColors colors,
  ) {
    return SizedBox(
      width: 100,
      child: ChoiceCard(
        emoji: emoji,
        name: name,
        selected: gp.chosenStyle == style,
        onTap: () => gp.setChosenStyle(style),
        colors: GameColors.forStyle(style),
      ),
    );
  }

  Widget _nameRow(int i, GameProvider gp, GameColors colors) {
    final locked = gp.licensed && gp.licensedSchool != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kPawnColors[i % kPawnColors.length],
              shape: BoxShape.circle,
            ),
            child: Text(
              '${i + 1}',
              style: AppText.cinzel(
                fontSize: 13,
                color: kPawnTextColors[i % kPawnTextColors.length],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: _textField(
              controller: _nameCtrls[i],
              hint: 'Player name',
              colors: colors,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: _textField(
              controller: _schoolCtrls[i],
              hint: 'School',
              colors: colors,
              enabled: !locked,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stripePlan({
    required String icon,
    required String name,
    required String desc,
    required String price,
    required String priceSub,
    required String btnLabel,
    required Color btnColor,
    required Color btnFg,
    required VoidCallback onTap,
    required GameColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.navy.withValues(alpha: 0.7),
            colors.navyDeep.withValues(alpha: 0.75),
          ],
        ),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppText.cinzel(
                    fontSize: 13.5,
                    color: colors.brassBright,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: AppText.spectral(
                    fontSize: 11.5,
                    color: colors.cream.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text.rich(
                TextSpan(
                  text: price,
                  style: AppText.cinzel(
                    fontSize: 17,
                    color: colors.brassBright,
                  ),
                  children: [
                    if (priceSub.isNotEmpty)
                      TextSpan(
                        text: priceSub,
                        style: AppText.spectral(
                          fontSize: 11,
                          color: colors.cream.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor: btnFg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  btnLabel,
                  style: AppText.cinzel(fontSize: 12, color: btnFg),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
