import 'package:flutter/material.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import 'panel.dart';

class ScorePanel extends StatelessWidget {
  final List<GamePlayer> players;
  final int current;
  final int totalSteps;
  final GameColors colors;

  const ScorePanel({
    super.key,
    required this.players,
    required this.current,
    required this.totalSteps,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'THIS GAME',
            style: AppText.cinzel(
              fontSize: 12,
              color: colors.brassBright,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(players.length, (i) {
            final p = players[i];
            final pct = ((p.pos / (totalSteps - 1)) * 100).round();
            final active = i == current;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: active
                    ? colors.accent.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: active
                    ? Border.all(color: colors.accent, width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.color,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      p.tag,
                      style: AppText.cinzel(fontSize: 10, color: p.textColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: AppText.spectral(
                            fontSize: 13.5,
                            color: colors.cream,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${p.school} • ${p.correct} correct',
                          style: AppText.spectral(
                            fontSize: 10.5,
                            color: colors.cream.withValues(alpha: 0.65),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(colors.brassBright),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.right,
                      style: AppText.spectral(
                        fontSize: 11.5,
                        color: colors.cream.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
