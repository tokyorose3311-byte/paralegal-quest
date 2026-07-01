import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_provider.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../widgets/panel.dart';
import '../widgets/game_pawn.dart';
import '../widgets/die_widget.dart';
import '../widgets/score_panel.dart';
import '../widgets/leaderboard_panel.dart';
import '../widgets/question_dialog.dart';
import '../widgets/win_dialog.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _muted = false;
  int _leaderboardTick = 0;
  bool _rollInFlight = false;

  Future<void> _takeTurn() async {
    if (_rollInFlight) return;
    final gp = context.read<GameProvider>();
    if (gp.busy) return;
    setState(() => _rollInFlight = true);

    final roll = await gp.rollDie();
    if (!mounted) return;

    final colors = GameColors.forStyle(gp.chosenStyle);
    final question = gp.randomQuestion();
    final chosen = await showQuestionDialog(
      context: context,
      question: question,
      roll: roll,
      colors: colors,
    );
    if (!mounted) return;

    final correct = chosen != null && chosen == question.correctIndex;
    final winnerReached = await gp.resolveAnswer(
      correct: correct,
      roll: roll,
      onStep: () {
        if (mounted) setState(() {});
      },
    );

    if (!mounted) return;

    if (winnerReached) {
      final winner = gp.currentPlayer;
      final winnerPoints = winner.correct * 10 + 50;
      final board = await gp.finishGameAndSubmit(winner);
      if (!mounted) return;
      setState(() => _leaderboardTick++);
      await showWinDialog(
        context: context,
        winner: winner,
        winnerPoints: winnerPoints,
        countsForLeaderboard: gp.countsForLeaderboard,
        board: board,
        colors: colors,
        onPlayAgain: () {
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
      );
    }

    if (mounted) setState(() => _rollInFlight = false);
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
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 820;
                final board = _buildBoard(gp, colors);
                final side = _buildSide(context, gp, colors);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: board),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: side),
                    ],
                  );
                }
                return Column(
                  children: [board, const SizedBox(height: 16), side],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(GameProvider gp, GameColors colors) {
    return AspectRatio(
      aspectRatio: 920 / 593,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.accent, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 26,
              offset: Offset(0, 10),
            ),
          ],
          image: const DecorationImage(
            image: AssetImage('assets/images/board_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              right: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      _muted = !_muted;
                      SoundService.muted = _muted;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      _muted ? '🔇 Muted' : '🔊 Sound',
                      style: AppText.cinzel(
                        fontSize: 11,
                        color: colors.brassBright,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, box) {
                return Stack(
                  children: List.generate(gp.players.length, (i) {
                    final p = gp.players[i];
                    final wp = kWaypoints[p.pos];
                    const offsets = [
                      Offset(-10, -10),
                      Offset(10, -10),
                      Offset(-10, 10),
                      Offset(10, 10),
                    ];
                    final off = offsets[i % offsets.length];
                    final left = (wp.dx / 100) * box.maxWidth + off.dx;
                    final top = (wp.dy / 100) * box.maxHeight + off.dy;
                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      left: left - 13,
                      top: top - 13,
                      child: GamePawn(
                        player: p,
                        isTurn: i == gp.current,
                        hopping: gp.hoppingIndex == i,
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSide(BuildContext context, GameProvider gp, GameColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          colors: colors,
          child: Column(
            children: [
              Text(
                '${gp.currentPlayer.name} — your move',
                style: AppText.cinzel(fontSize: 17, color: colors.cream),
              ),
              const SizedBox(height: 12),
              DieWidget(value: gp.lastRoll, rolling: gp.rolling),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_rollInFlight || gp.busy) ? null : _takeTurn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brassBright,
                    foregroundColor: const Color(0xFF1A140C),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Roll & answer',
                    style: AppText.cinzel(
                      fontSize: 15,
                      color: const Color(0xFF1A140C),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                gp.hint,
                textAlign: TextAlign.center,
                style: AppText.spectral(
                  fontSize: 12.5,
                  color: colors.cream.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ScorePanel(
          players: gp.players,
          current: gp.current,
          totalSteps: GameProvider.totalSteps,
          colors: colors,
        ),
        const SizedBox(height: 14),
        LeaderboardPanel(
          colors: colors,
          refreshTick: _leaderboardTick,
          highlightSchools: gp.players.map((p) => p.school).toSet(),
        ),
        const SizedBox(height: 14),
        Panel(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOW TO PLAY',
                style: AppText.cinzel(
                  fontSize: 12,
                  color: colors.brassBright,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              _rule(
                '🎲',
                'Roll, then answer the Mountain or Cave question',
                colors,
              ),
              _rule(
                '✅',
                'Each correct answer earns points for your school',
                colors,
              ),
              _rule(
                '🏆',
                'The school with the highest total score leads the nation',
                colors,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.brass,
                    side: BorderSide(color: colors.accent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'New game',
                    style: AppText.cinzel(fontSize: 13, color: colors.brass),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rule(String emoji, String text, GameColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppText.spectral(
                fontSize: 12.5,
                color: colors.cream.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
