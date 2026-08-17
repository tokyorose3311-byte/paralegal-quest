import 'package:flutter/material.dart';
import '../models/region.dart';
import '../services/cloud_leaderboard_service.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import 'panel.dart';

/// Tabbed National + 4-region school leaderboard, backed entirely by the
/// real Firestore `schools` collection (see CloudLeaderboardService) -- so
/// every player everywhere sees the SAME standings. This replaces the old
/// implementation, which only ever read from on-device SharedPreferences
/// (so "national" standings were actually just "whatever games happened to
/// be played on this one phone").
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

/// Null == National tab. Non-null == that region's tab.
typedef _Tab = GameRegion?;

class LeaderboardPanelState extends State<LeaderboardPanel> {
  final _service = CloudLeaderboardService();
  List<SchoolBoardEntry> _schools = [];
  bool _loading = true;
  String? _error;
  _Tab _activeTab; // null = National

  // Lazily fetched MVP info for whichever school currently sits at #1 on
  // the active tab -- avoids an extra Firestore read per row.
  String? _topMvpName;
  String? _topMvpSchoolId;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final schools = await _service.getAllSchools();
      if (!mounted) return;
      setState(() {
        _schools = schools;
        _loading = false;
      });
      await _loadTopMvp();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load standings. Check your connection.';
        _loading = false;
      });
    }
  }

  Future<void> _loadTopMvp() async {
    final rows = _service.standings(_schools, region: _activeTab);
    if (rows.isEmpty) {
      setState(() {
        _topMvpName = null;
        _topMvpSchoolId = null;
      });
      return;
    }
    final topId = rows.first.id;
    try {
      final name = await _service.topPlayerNameFor(topId);
      if (!mounted) return;
      setState(() {
        _topMvpName = name;
        _topMvpSchoolId = topId;
      });
    } catch (_) {
      // Non-fatal -- the champion card just omits the MVP line.
    }
  }

  Future<void> refresh() => _load();

  void _selectTab(_Tab tab) {
    if (tab == _activeTab) return;
    setState(() {
      _activeTab = tab;
      _topMvpName = null;
      _topMvpSchoolId = null;
    });
    _loadTopMvp();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final rows = _service.standings(_schools, region: _activeTab);
    final title = _activeTab == null
        ? '🏆 NATIONAL SCHOOL STANDINGS'
        : '${_activeTab!.emoji} ${_activeTab!.label.toUpperCase()} STANDINGS';

    return Panel(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppText.cinzel(
              fontSize: 12,
              color: colors.brassBright,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          _tabBar(colors),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _error!,
                  style: AppText.spectral(
                    fontSize: 12,
                    color: const Color(0xFFF0B8B6),
                  ),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: _load,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.brass,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            )
          else if (rows.isEmpty)
            Text(
              _activeTab == null
                  ? 'No games recorded yet — finish a licensed game to put your school on the board.'
                  : 'No schools in ${_activeTab!.label} yet.',
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
              final here = widget.highlightSchools.contains(r.displayName);
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
                            r.displayName,
                            style: AppText.spectral(
                              fontSize: 13,
                              color: colors.cream,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${r.correct} correct • ${r.games} ${r.games == 1 ? "game" : "games"}'
                            '${r.region != null && _activeTab == null ? " • ${r.region!.emoji} ${r.region!.label}" : ""}',
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
                      r.points.toString(),
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

  Widget _tabBar(GameColors colors) {
    Widget chip(_Tab tab, String label) {
      final selected = tab == _activeTab;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          onTap: () => _selectTab(tab),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? colors.accent.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? colors.brassBright
                    : colors.accent.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Text(
              label,
              style: AppText.cinzel(
                fontSize: 10.5,
                color: selected ? colors.brassBright : colors.cream,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(null, '🇺🇸 National'),
          for (final r in GameRegion.values) chip(r, '${r.emoji} ${r.label}'),
        ],
      ),
    );
  }

  Widget _champCard(SchoolBoardEntry top, GameColors colors) {
    final mvp = (_topMvpSchoolId == top.id) ? _topMvpName : null;
    final label = _activeTab == null
        ? 'National champion'
        : '${_activeTab!.label} champion';
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
                  TextSpan(text: '$label\n'),
                  TextSpan(
                    text: top.displayName,
                    style: AppText.cinzel(
                      fontSize: 13,
                      color: colors.brassBright,
                    ),
                  ),
                  TextSpan(text: ' — ${top.points} pts'),
                  if (mvp != null)
                    TextSpan(
                      text: '\nSchool MVP: $mvp',
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
