import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import 'panel.dart';

class LeaderboardPanel extends StatefulWidget {
  final GameColors colors;
  final Set<String> highlightSchools;
  final int refreshTick;

  const LeaderboardPanel({
    super.key,
    required this.colors,
    this.highlightSchools = const {},
    this.refreshTick = 0,
  });

  @override
  State<LeaderboardPanel> createState() => LeaderboardPanelState();
}

class LeaderboardPanelState extends State<LeaderboardPanel> {
  final _service = LeaderboardService();
  Map<String, SchoolStats> _board = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LeaderboardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _load();
  }

  Future<void> _load() async {
    final board = await _service.loadBoard();
    if (!mounted) return;
    setState(() {
      _board = board;
      _loading = false;
    });
  }

  Future<void> refresh() => _load();

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final rows = _service.standings(_board);

    return Panel(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '🏆 NATIONAL SCHOOL STANDINGS',
            style: AppText.cinzel(
              fontSize: 12,
              color: colors.brassBright,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            Text(
              'No games recorded yet — finish a licensed game to put your school on the board.',
              style: AppText.spectral(
                fontSize: 12,
                color: colors.cream.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            _champCard(rows.first, colors),
            const SizedBox(height: 6),
            ...rows.take(8).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final mvp = r.value.mvpName;
              final here = widget.highlightSchools.contains(r.key);
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: here
                      ? colors.accent.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(7),
                  border: here
                      ? Border.all(color: colors.accent, width: 1)
                      : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.center,
                        style: AppText.cinzel(
                          fontSize: 12,
                          color: colors.brass,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.key,
                            style: AppText.spectral(
                              fontSize: 13,
                              color: colors.cream,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${r.value.correct} correct • ${r.value.games} ${r.value.games == 1 ? "game" : "games"}${mvp != null ? " • MVP: $mvp" : ""}',
                            style: AppText.spectral(
                              fontSize: 10.5,
                              color: colors.cream.withValues(alpha: 0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      r.value.points.toString(),
                      style: AppText.cinzel(
                        fontSize: 13,
                        color: colors.brassBright,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
          Text(
            'Scores from every game everywhere add up here.',
            style: AppText.spectral(
              fontSize: 10.5,
              color: colors.cream.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _champCard(MapEntry<String, SchoolStats> top, GameColors colors) {
    final mvp = top.value.mvpName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.brass.withValues(alpha: 0.28),
            colors.brass.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: colors.brass),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Text('👑', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppText.spectral(fontSize: 12.5, color: colors.cream),
                children: [
                  const TextSpan(text: 'National champion\n'),
                  TextSpan(
                    text: top.key,
                    style: AppText.cinzel(
                      fontSize: 13,
                      color: colors.brassBright,
                    ),
                  ),
                  TextSpan(text: ' — ${top.value.points} pts'),
                  if (mvp != null)
                    TextSpan(
                      text:
                          '\nSchool MVP: $mvp (${top.value.mvp?.points ?? 0})',
                      style: AppText.spectral(
                        fontSize: 11,
                        color: colors.cream.withValues(alpha: 0.65),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
