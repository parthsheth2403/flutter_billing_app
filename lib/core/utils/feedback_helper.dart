import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class FeedbackHelper {
  FeedbackHelper._();

  static Future<void> vibrate() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate(duration: 120, amplitude: 180);
        return;
      }
    } catch (_) {
      // Fall through to haptic feedback.
    }

    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Ignore feedback failures.
    }
  }
}
