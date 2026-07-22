import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lightweight sound/haptic feedback service.
/// Uses system click sounds + haptics rather than bundled audio files,
/// keeping the app small while still giving tactile/audio feedback.
///
/// IMPORTANT: Haptics/system-sound platform channels are not consistently
/// implemented across every browser/OS combination on Flutter Web (some
/// browsers throw a MissingPluginException or similar when these are
/// called). Sound/haptic feedback is purely cosmetic and must NEVER be
/// allowed to throw -- if it did, an unhandled exception here would abort
/// the calling turn logic mid-flight and could leave the UI's "in progress"
/// flags stuck forever (the game appears frozen). Every call below is
/// wrapped so failures are swallowed silently.
class SoundService {
  static bool muted = false;

  static void _safe(void Function() action) {
    try {
      action();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundService: ignored feedback error: $e');
      }
    }
  }

  static void roll() {
    if (muted) return;
    _safe(() => HapticFeedback.mediumImpact());
    _safe(() => SystemSound.play(SystemSoundType.click));
  }

  static void step() {
    if (muted) return;
    _safe(() => HapticFeedback.selectionClick());
  }

  static void correct() {
    if (muted) return;
    _safe(() => HapticFeedback.lightImpact());
    _safe(() => SystemSound.play(SystemSoundType.click));
  }

  static void wrong() {
    if (muted) return;
    _safe(() => HapticFeedback.heavyImpact());
  }

  static void win() {
    if (muted) return;
    _safe(() => HapticFeedback.heavyImpact());
    _safe(() => SystemSound.play(SystemSoundType.click));
  }
}
