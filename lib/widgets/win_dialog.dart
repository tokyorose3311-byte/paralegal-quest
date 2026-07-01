import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/leaderboard_service.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import 'confetti_overlay.dart';

Future<void> showWinDialog({
  required BuildContext context,
  required GamePlayer winner,
  required int winnerPoints,
  required bool countsForLeaderboard,
  required Map<String, SchoolStats> board,
  required GameColors colors,
  required VoidCallback onPlayAgain,
}) {
  final service = LeaderboardService();
  final rows = service.standings(board);
  MapEntry<String, SchoolStats>? top = rows.isNotEmpty ? rows.first : null;
  final mySchool = board[winner.school];
  final myMvp = mySchool?.mvpName;

  String champLine;
  if (!countsForLeaderboard) {
    champLine =
        "Demo game — not counted nationally. Add a school license to compete on the board.";
  } else if (top != null) {
    final leadIsHere = winner.school == top.key;
    String tier2 = '';
    if (myMvp != null) {
      tier2 = myMvp == winner.name
          ? "🥇 You're the top player for ${winner.school}."
          : "Top player for ${winner.school}: $myMvp — catch them!";
    }
    champLine =
        "👑 National leader: ${top.key} — ${top.value.points} pts"
        "${leadIsHere ? ' (that\'s your school — defend it!)' : ''}"
        "${tier2.isNotEmpty ? '\n$tier2' : ''}";
  } else {
    champLine = '';
  }

  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xE6060C18),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1C3157), Color(0xFF0D1A31)],
                ),
                border: Border.all(color: colors.accent, width: 2),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 40,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚖️', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 6),
                  Text(
                    'Case won!',
                    style: AppText.cinzel(
                      fontSize: 28,
                      color: colors.brassBright,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      style: AppText.spectral(
                        fontSize: 16,
                        color: colors.cream,
                      ),
                      children: [
                        TextSpan(
                          text: winner.name,
                          style: AppText.spectral(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' of '),
                        TextSpan(
                          text: winner.school,
                          style: AppText.spectral(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' reached the judge and earned '),
                        TextSpan(
                          text: winnerPoints.toString(),
                          style: AppText.spectral(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' points.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (champLine.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      champLine,
                      textAlign: TextAlign.center,
                      style: AppText.spectral(
                        fontSize: 13,
                        color: countsForLeaderboard
                            ? colors.cream.withValues(alpha: 0.85)
                            : const Color(0xFFF0B8B6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onPlayAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brassBright,
                      foregroundColor: const Color(0xFF1A140C),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Play again',
                      style: AppText.cinzel(
                        fontSize: 15,
                        color: const Color(0xFF1A140C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: ConfettiOverlay(),
            ),
          ],
        ),
      ),
    ),
  );
}
