import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Semantic haptic intensities, mapped per platform so feedback stays subtle.
///
/// iOS uses Taptic Engine generators (selection / impact / notification).
/// Android uses system [HapticFeedbackConstants] via Flutter — never legacy
/// [HapticFeedback.vibrate], which maps to a harsh LONG_PRESS buzz.
///
/// Intensity ladder (soft → clear, never hard):
/// [selection] < [light] < [medium] < [success]
abstract final class HapticsService {
  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get _supported =>
      _ios || (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// Softest tick — tabs, chips, segmented controls, list selection.
  static Future<void> selection() async {
    if (!_supported) return;
    // iOS: UISelectionFeedbackGenerator
    // Android: CLOCK_TICK
    await HapticFeedback.selectionClick();
  }

  /// Soft press — secondary CTAs, skip, send, auth pills.
  static Future<void> light() async {
    if (!_supported) return;
    // iOS: UIImpactFeedbackStyleLight
    // Android: VIRTUAL_KEY
    await HapticFeedback.lightImpact();
  }

  /// Clear but restrained — primary CTAs (connect, purchase, continue).
  static Future<void> medium() async {
    if (!_supported) return;
    // iOS: UIImpactFeedbackStyleMedium (still under Heavy)
    // Android: KEYBOARD_TAP — clear without a buzz
    await HapticFeedback.mediumImpact();
  }

  /// Positive outcome — match, purchase / verification success.
  static Future<void> success() async {
    if (!_supported) return;
    if (_ios) {
      await HapticFeedback.successNotification();
    } else {
      // CONFIRM only exists on API 30+; KEYBOARD_TAP is the reliable
      // cross-device Android success feel without LONG_PRESS harshness.
      await HapticFeedback.mediumImpact();
    }
  }

  /// Cautionary outcome — soft warning, not an alarm.
  static Future<void> warning() async {
    if (!_supported) return;
    if (_ios) {
      await HapticFeedback.warningNotification();
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  /// Failed important action.
  static Future<void> error() async {
    if (!_supported) return;
    if (_ios) {
      await HapticFeedback.errorNotification();
    } else {
      // REJECT is API 30+ only; medium is a restrained stand-in.
      await HapticFeedback.mediumImpact();
    }
  }
}
