import 'package:flutter/services.dart';

/// Lightweight sound/haptic feedback service.
/// Uses system click sounds + haptics rather than bundled audio files,
/// keeping the app small while still giving tactile/audio feedback.
class SoundService {
  static bool muted = false;

  static void roll() {
    if (muted) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static void step() {
    if (muted) return;
    HapticFeedback.selectionClick();
  }

  static void correct() {
    if (muted) return;
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static void wrong() {
    if (muted) return;
    HapticFeedback.heavyImpact();
  }

  static void win() {
    if (muted) return;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
  }
}
