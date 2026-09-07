import 'dart:async';

import 'package:fairytrail/api/chat.dart' as chat_api;
import 'package:fairytrail/api/explore.dart';
import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/explore/begin_journey_prefs.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/image_warm.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/foundation.dart';

/// Warms the People deck after location is on the server.
///
/// Same sequence as tapping Begin Journey then opening Explore:
/// 1. Seed match-with prefs (Get Started)
/// 2. Resolve no_match via matches
/// 3. GET /profiles/prefetch (with firstime when pending)
class ExploreWarmPrefetch {
  ExploreWarmPrefetch._();
  static final ExploreWarmPrefetch instance = ExploreWarmPrefetch._();

  PrefetchProfilesResponse? _response;
  bool _usedFirstTime = false;
  bool _prefsSeeded = false;
  Future<void>? _inFlight;

  bool get prefsSeeded => _prefsSeeded;
  bool get hasResponse => _response != null;

  /// Start once location is known. Safe to call repeatedly.
  void start({ProfileMetaDto? profileMeta}) {
    unawaited(ensureStarted(profileMeta: profileMeta));
  }

  Future<void> ensureStarted({ProfileMetaDto? profileMeta}) {
    final existing = _inFlight;
    if (existing != null) return existing;
    if (_response != null) return Future<void>.value();

    final future = _run(profileMeta: profileMeta);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  /// Consume warm result for Explore bootstrap. Does not start a new fetch.
  Future<({PrefetchProfilesResponse response, bool firstTime})?> take() async {
    final flight = _inFlight;
    if (flight != null) await flight;
    final res = _response;
    if (res == null) return null;
    final firstTime = _usedFirstTime;
    _response = null;
    _usedFirstTime = false;
    return (response: res, firstTime: firstTime);
  }

  void clear() {
    _response = null;
    _usedFirstTime = false;
    _prefsSeeded = false;
    _inFlight = null;
  }

  Future<void> _run({ProfileMetaDto? profileMeta}) async {
    try {
      debugPrint('[ExploreWarmPrefetch] seeding Begin Journey prefs…');
      final seeded = await seedBeginJourneyPrefsIfNeeded(profileMeta);
      if (seeded) _prefsSeeded = true;
      debugPrint('[ExploreWarmPrefetch] prefsSeeded=$seeded');

      final storage = LocalStorage.instance;
      final firstTime = await storage.hasPendingSignupFirstExplore();
      final noMatch = await _resolveNoMatch();
      debugPrint(
        '[ExploreWarmPrefetch] matches done → prefetch '
        'firstTime=$firstTime noMatch=$noMatch',
      );

      final res = await prefetchProfiles(
        firstTime: firstTime,
        noMatch: noMatch,
      );
      _response = res;
      _usedFirstTime = firstTime;
      if (firstTime) {
        await storage.clearPendingSignupFirstExplore();
      }
      final first = res.profiles.isEmpty ? null : res.profiles.first;
      if (first != null) {
        unawaited(storage.setLastExploreProfile(first.toJson()));
      }
      warmExploreProfilePhotos(res.profiles);
      debugPrint(
        '[ExploreWarmPrefetch] ready profiles=${res.profiles.length} '
        'firstTime=$firstTime',
      );
    } catch (e) {
      debugPrint('[ExploreWarmPrefetch] failed: $e');
    }
  }

  Future<bool> _resolveNoMatch() async {
    final cached = await LocalStorage.instance.getNoMatch();
    if (cached != null) return cached;

    try {
      final matches = await chat_api.fetchMatches(
        timestamp: EndPoints.matchesSyncEpoch,
      );
      final noMatch = matches.isEmpty;
      await LocalStorage.instance.setNoMatch(noMatch);
      return noMatch;
    } catch (e) {
      debugPrint('[ExploreWarmPrefetch] no_match failed: $e');
      await LocalStorage.instance.setNoMatch(true);
      return true;
    }
  }
}
