import 'package:flutter/material.dart';
import '../models/region.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

/// Lets the player pick which regional leaderboard (in addition to
/// National, which every game always counts toward) this game's results
/// should contribute to. Chips only -- selecting one doesn't remove a
/// school from the National board, it's purely additive.
class RegionPicker extends StatelessWidget {
  final GameRegion? selected;
  final ValueChanged<GameRegion?> onChanged;
  final GameColors colors;

  const RegionPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(GameRegion? region, String label) {
      final isSelected = region == selected;
      return InkWell(
        onTap: () => onChanged(region),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? colors.brassBright
                  : colors.accent.withValues(alpha: 0.3),
              width: 1.4,
            ),
          ),
          child: Text(
            label,
            style: AppText.cinzel(
              fontSize: 11.5,
              color: isSelected ? colors.brassBright : colors.cream,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(null, 'National only'),
        for (final r in GameRegion.values) chip(r, '${r.emoji} ${r.label}'),
      ],
    );
  }
}
