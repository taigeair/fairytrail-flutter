import 'dart:async';

import 'package:fairytrail/api/activities.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:flutter/foundation.dart';

/// Process-lifetime warm Activities page. Does not need location — start before
/// the location gate so the Activities tab is ready when Explore opens.
class ActivitiesWarmPrefetch {
  ActivitiesWarmPrefetch._();
  static final ActivitiesWarmPrefetch instance = ActivitiesWarmPrefetch._();

  ActivitiesPageResponse? _page;
  Future<void>? _inFlight;

  bool get hasPage => _page != null;

  void start() {
    unawaited(ensureStarted());
  }

  Future<void> ensureStarted() {
    final existing = _inFlight;
    if (existing != null) return existing;
    if (_page != null) return Future<void>.value();

    final future = _run();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  /// Take a completed warm page (clears cache). Awaits in-flight if needed.
  Future<ActivitiesPageResponse?> take() async {
    await ensureStarted();
    final page = _page;
    _page = null;
    return page;
  }

  void clear() {
    _page = null;
    _inFlight = null;
  }

  Future<void> _run() async {
    try {
      _page = await getActivities(sortBy: 'trending');
    } catch (e) {
      debugPrint('[ActivitiesWarmPrefetch] failed: $e');
    }
  }
}
