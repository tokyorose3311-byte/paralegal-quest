import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

class ChoiceCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;
  final GameColors colors;

  /// When true, the card renders as a dimmed, non-interactive "coming
  /// soon" placeholder: greyed out, a small lock badge, and taps do
  /// nothing. Used for practice areas that don't have a live question
  /// bank in Firestore yet.
  final bool locked;

  const ChoiceCard({
    super.key,
    required this.emoji,
    required this.name,
    this.sub,
    required this.selected,
    required this.onTap,
    required this.colors,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: locked ? 0.55 : 1.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              constraints: const BoxConstraints(minWidth: 100),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                color: selected
                    ? colors.accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? colors.brassBright
                      : colors.accent.withValues(alpha: locked ? 0.18 : 0.35),
                  width: 2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: colors.brass.withValues(alpha: 0.2),
                          blurRadius: 0,
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: AppText.cinzel(
                      fontSize: 13,
                      color: colors.cream,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      textAlign: TextAlign.center,
                      style: AppText.spectral(
                        fontSize: 11,
                        color: colors.cream.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (locked)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.navyDeep,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.lock,
                    size: 12,
                    color: colors.cream.withValues(alpha: 0.85),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
