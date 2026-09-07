import 'dart:async';

import 'package:fairytrail/screens/review/write_review_screen.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

/// RN chat `askForReview` — prompt after the first message in an empty thread.
abstract final class ReviewPrompt {
  static Timer? _timer;

  /// Call **before** sending when the thread is still empty.
  ///
  /// Conditions (RN): not already reviewed, requested ≤ 2 times, store review
  /// available. Delay is 5s (RN uses 1s).
  static void maybeScheduleAfterFirstMessage(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);
    unawaited(_maybeSchedule(nav));
  }

  static void cancelPending() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _maybeSchedule(NavigatorState nav) async {
    final storage = LocalStorage.instance;
    if (await storage.isReviewLeft()) return;

    final times = await storage.getReviewRequestedTimes();
    if (times > 2) return;

    try {
      if (!await InAppReview.instance.isAvailable()) return;
    } catch (e) {
      debugPrint('[ReviewPrompt] isAvailable failed: $e');
      return;
    }

    await storage.setReviewRequested(times + 1);

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), () {
      _timer = null;
      if (!nav.mounted) return;
      nav.push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const WriteReviewScreen(),
        ),
      );
    });
  }
}
