import 'dart:async';
import 'dart:io' show Platform;

import 'package:fairytrail/api/location.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationShareResult {
  success,
  permissionDenied,
  permissionPermanentlyDenied,
  serviceDisabled,
  unavailable,
  postFailed,
}

class LocationShareOutcome {
  const LocationShareOutcome({
    required this.result,
    this.errorMessage,
    this.skippedDueToBuffer = false,
    this.latitude,
    this.longitude,
  });

  final LocationShareResult result;
  final String? errorMessage;

  /// True when GPS succeeded but POST was skipped (within distance buffer).
  final bool skippedDueToBuffer;

  /// Fix used for the share attempt (when GPS succeeded).
  final double? latitude;
  final double? longitude;

  bool get isSuccess => result == LocationShareResult.success;
}

/// Foreground location permission + one-shot GPS + POST /location.
abstract final class LocationService {
  static String get appLocationSettingsMessage {
    if (!kIsWeb && Platform.isIOS) {
      return 'Settings -> Location -> While Using the App.';
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'Permissions -> Location -> Allow only while using the app.';
    }
    return 'Open Settings and allow Fairytrail to access your location.';
  }

  static Future<bool> isServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  static Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  /// Checks whether location can be read without presenting a permission UI.
  static Future<bool> hasLocationPermission() async {
    final permission = await checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static const locationRefreshGap = Duration(hours: 2);

  /// Only POST /location (and the server `set_location` track event) when the
  /// user has moved farther than this from the last stored coords.
  static const minLocationUpdateDistanceMeters = 5000.0;

  /// Profile "tap current country" buffer — skip refresh when closer than this.
  static const profileCountryUpdateBufferMiles = 0.5;
  static const profileCountryUpdateBufferMeters =
      profileCountryUpdateBufferMiles * 1609.344;

  /// True when there is no prior update, or the last update is older than [gap].
  static Future<bool> isLocationStale({
    Duration gap = locationRefreshGap,
  }) async {
    final last = await LocalStorage.instance.getLastLocationUpdateAt();
    if (last == null) return true;
    return DateTime.now().difference(last) >= gap;
  }

  static Future<({double latitude, double longitude})?>
  readStoredLocation() async {
    final previous = await LocalStorage.instance.getLocation();
    if (previous == null) return null;
    final lat = (previous['latitude'] as num?)?.toDouble();
    final lng = (previous['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return (latitude: lat, longitude: lng);
  }

  /// Last coords successfully POSTed. Used for the 5 km server buffer.
  static Future<({double latitude, double longitude})?>
  readLastPostedLocation() async {
    final previous = await LocalStorage.instance.getLocation();
    if (previous == null) return null;
    final lat = (previous['lastPostedLatitude'] as num?)?.toDouble();
    final lng = (previous['lastPostedLongitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return (latitude: lat, longitude: lng);
  }

  /// Whether [latitude]/[longitude] should be POSTed (5 km server buffer).
  ///
  /// Compares against [previousLatitude]/[previousLongitude] when provided;
  /// otherwise against the last **posted** baseline in LocalStorage.
  static Future<bool> shouldPostLocationUpdate({
    required double latitude,
    required double longitude,
    double? previousLatitude,
    double? previousLongitude,
    double minDistanceMeters = minLocationUpdateDistanceMeters,
    String logTag = 'Location',
  }) async {
    var prevLat = previousLatitude;
    var prevLng = previousLongitude;
    if (prevLat == null || prevLng == null) {
      final posted = await readLastPostedLocation();
      prevLat = posted?.latitude;
      prevLng = posted?.longitude;
    }

    if (prevLat == null || prevLng == null) {
      debugPrint(
        '[$logTag] no previous location — will post '
        'current=($latitude, $longitude) '
        'threshold=${minDistanceMeters.toStringAsFixed(1)}m '
        '(${(minDistanceMeters / 1609.344).toStringAsFixed(3)}mi)',
      );
      return true;
    }

    final meters = Geolocator.distanceBetween(
      prevLat,
      prevLng,
      latitude,
      longitude,
    );
    final miles = meters / 1609.344;
    final shouldUpdate = meters > minDistanceMeters;
    debugPrint(
      '[$logTag] previous=($prevLat, $prevLng) '
      'current=($latitude, $longitude) '
      'distance=${meters.toStringAsFixed(1)}m '
      '(${miles.toStringAsFixed(3)}mi) '
      'threshold=${minDistanceMeters.toStringAsFixed(1)}m '
      '(${(minDistanceMeters / 1609.344).toStringAsFixed(3)}mi) '
      'decision=${shouldUpdate ? 'UPDATE' : 'SKIP_POST'}',
    );
    return shouldUpdate;
  }

  static Future<void>? _backgroundRefreshInFlight;

  /// Default: return stored LocalStorage coords immediately (if any) and
  /// refresh in the background (fresh GPS → update stored → POST / lastPosted
  /// if moved > [minDistanceMeters]).
  ///
  /// Set [awaitFresh] to wait for GPS and update stored before returning
  /// (e.g. profile country, first share).
  static Future<LocationShareOutcome> shareCurrentLocation({
    bool updateCountry = true,
    double minDistanceMeters = minLocationUpdateDistanceMeters,
    String logTag = 'Location',
    bool awaitFresh = false,
  }) async {
    final gate = await _ensurePermission(requestIfNeeded: true);
    if (gate != null) return gate;

    final stored = await readStoredLocation();
    if (!awaitFresh && stored != null) {
      debugPrint(
        '[$logTag] using stored local='
        '(${stored.latitude}, ${stored.longitude}) — '
        'fresh GPS refresh in background',
      );
      unawaited(
        refreshLocationInBackground(
          updateCountry: updateCountry,
          minDistanceMeters: minDistanceMeters,
          logTag: logTag,
        ),
      );
      return LocationShareOutcome(
        result: LocationShareResult.success,
        latitude: stored.latitude,
        longitude: stored.longitude,
      );
    }

    return _fetchUpdateStoredAndMaybePost(
      updateCountry: updateCountry,
      minDistanceMeters: minDistanceMeters,
      logTag: logTag,
      previousPosted: await readLastPostedLocation(),
    );
  }

  /// Background: get location (last-known OK), update stored lat/lng, then
  /// POST / update lastPosted only when moved > [minDistanceMeters].
  static Future<void> refreshLocationInBackground({
    bool updateCountry = true,
    double minDistanceMeters = minLocationUpdateDistanceMeters,
    String logTag = 'Location',
  }) async {
    if (_backgroundRefreshInFlight != null) {
      await _backgroundRefreshInFlight;
      return;
    }

    late final Future<void> run;
    run = () async {
      try {
        if (!await hasLocationPermission()) {
          debugPrint('[$logTag] background refresh skipped — no permission');
          return;
        }
        if (!await isServiceEnabled()) {
          debugPrint('[$logTag] background refresh skipped — services off');
          return;
        }

        final outcome = await _fetchFreshAndMaybeUpdatePosted(
          updateCountry: updateCountry,
          minDistanceMeters: minDistanceMeters,
          logTag: '$logTag/bg',
          previousPosted: await readLastPostedLocation(),
        );
        debugPrint(
          '[$logTag] background posted refresh done '
          'success=${outcome.isSuccess} '
          'skippedPost=${outcome.skippedDueToBuffer} '
          'coords=(${outcome.latitude}, ${outcome.longitude})',
        );
      } catch (e) {
        // Never let a background refresh crash the app (e.g. Geolocator
        // Null check when the platform returns a map with null lat/lng).
        debugPrint('[$logTag] background refresh failed: $e');
      }
    }();

    _backgroundRefreshInFlight = run;
    try {
      await run;
    } finally {
      if (identical(_backgroundRefreshInFlight, run)) {
        _backgroundRefreshInFlight = null;
      }
    }
  }

  static Future<LocationShareOutcome?> _ensurePermission({
    required bool requestIfNeeded,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationShareOutcome(
        result: LocationShareResult.serviceDisabled,
        errorMessage: 'Turn on Location Services to continue.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestIfNeeded) {
      await LocalStorage.instance.setHasRequestedLocationPermission();
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      unawaited(track('location_permission_denied', {'status': 'denied'}));
      return const LocationShareOutcome(
        result: LocationShareResult.permissionDenied,
        errorMessage:
            'Share location to meet people. You can turn it off anytime.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      unawaited(
        track('location_permission_denied', {'status': 'deniedForever'}),
      );
      return LocationShareOutcome(
        result: LocationShareResult.permissionPermanentlyDenied,
        errorMessage: appLocationSettingsMessage,
      );
    }

    return null;
  }

  /// Foreground / first-share: GPS → update **stored** → POST if needed.
  static Future<LocationShareOutcome> _fetchUpdateStoredAndMaybePost({
    required bool updateCountry,
    required double minDistanceMeters,
    required String logTag,
    ({double latitude, double longitude})? previousPosted,
  }) async {
    try {
      final position = await _getOneShotPosition(preferLastKnown: true);
      if (position == null) {
        unawaited(track('location_not_available', {'status': 'null'}));
        return const LocationShareOutcome(
          result: LocationShareResult.unavailable,
          errorMessage: 'Location not available, please try again.',
        );
      }

      final shouldPost = await shouldPostLocationUpdate(
        latitude: position.latitude,
        longitude: position.longitude,
        previousLatitude: previousPosted?.latitude,
        previousLongitude: previousPosted?.longitude,
        minDistanceMeters: minDistanceMeters,
        logTag: logTag,
      );

      await LocalStorage.instance.setLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      await LocalStorage.instance.setLastLocationUpdateAt(DateTime.now());
      debugPrint(
        '[$logTag] stored location updated '
        '(${position.latitude}, ${position.longitude})',
      );

      if (!shouldPost) {
        debugPrint(
          '[$logTag] skip server post — within '
          '${minDistanceMeters.toStringAsFixed(1)}m buffer',
        );
        return LocationShareOutcome(
          result: LocationShareResult.success,
          skippedDueToBuffer: true,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }

      final posted = await _postAndMarkPosted(
        latitude: position.latitude,
        longitude: position.longitude,
        updateCountry: updateCountry,
        logTag: logTag,
      );
      if (posted != null) return posted;

      return LocationShareOutcome(
        result: LocationShareResult.success,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationServiceDisabledException {
      return const LocationShareOutcome(
        result: LocationShareResult.serviceDisabled,
        errorMessage: 'Turn on Location Services to continue.',
      );
    } catch (e) {
      debugPrint('[$logTag] unavailable: $e');
      unawaited(track('location_not_available', {'status': e.toString()}));
      return const LocationShareOutcome(
        result: LocationShareResult.unavailable,
        errorMessage: 'Location not available, please try again.',
      );
    }
  }

  /// Background posted refresh: get a position (prefer last-known), always
  /// update stored lat/lng, then POST / update lastPosted if past buffer.
  static Future<LocationShareOutcome> _fetchFreshAndMaybeUpdatePosted({
    required bool updateCountry,
    required double minDistanceMeters,
    required String logTag,
    ({double latitude, double longitude})? previousPosted,
  }) async {
    try {
      debugPrint('[$logTag] getting location…');
      final position = await _getOneShotPosition(preferLastKnown: true);
      if (position == null) {
        unawaited(track('location_not_available', {'status': 'null'}));
        return const LocationShareOutcome(
          result: LocationShareResult.unavailable,
          errorMessage: 'Location not available, please try again.',
        );
      }

      final shouldPost = await shouldPostLocationUpdate(
        latitude: position.latitude,
        longitude: position.longitude,
        previousLatitude: previousPosted?.latitude,
        previousLongitude: previousPosted?.longitude,
        minDistanceMeters: minDistanceMeters,
        logTag: logTag,
      );

      // Fresh fix is in — update stored immediately (no distance buffer).
      await LocalStorage.instance.setLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      await LocalStorage.instance.setLastLocationUpdateAt(DateTime.now());
      debugPrint(
        '[$logTag] stored location updated '
        '(${position.latitude}, ${position.longitude})',
      );

      if (!shouldPost) {
        debugPrint(
          '[$logTag] skip server post — within '
          '${minDistanceMeters.toStringAsFixed(1)}m buffer',
        );
        return LocationShareOutcome(
          result: LocationShareResult.success,
          skippedDueToBuffer: true,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }

      final posted = await _postAndMarkPosted(
        latitude: position.latitude,
        longitude: position.longitude,
        updateCountry: updateCountry,
        logTag: logTag,
      );
      if (posted != null) return posted;

      return LocationShareOutcome(
        result: LocationShareResult.success,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationServiceDisabledException {
      return const LocationShareOutcome(
        result: LocationShareResult.serviceDisabled,
        errorMessage: 'Turn on Location Services to continue.',
      );
    } catch (e) {
      debugPrint('[$logTag] unavailable: $e');
      unawaited(track('location_not_available', {'status': e.toString()}));
      return const LocationShareOutcome(
        result: LocationShareResult.unavailable,
        errorMessage: 'Location not available, please try again.',
      );
    }
  }

  /// POSTs and writes lastPosted*. Returns an error outcome, or null on success.
  static Future<LocationShareOutcome?> _postAndMarkPosted({
    required double latitude,
    required double longitude,
    required bool updateCountry,
    required String logTag,
  }) async {
    try {
      await postLocation(
        latitude: latitude,
        longitude: longitude,
        updateCountry: updateCountry,
      );
    } catch (e) {
      debugPrint('[$logTag] post failed: $e');
      unawaited(
        track('location_post_error', {
          'error': e.toString(),
          'coords': {'latitude': latitude, 'longitude': longitude},
        }),
      );
      return LocationShareOutcome(
        result: LocationShareResult.postFailed,
        errorMessage: "Couldn't save your location. Please try again.",
        latitude: latitude,
        longitude: longitude,
      );
    }

    await LocalStorage.instance.setLastPostedLocation(
      latitude: latitude,
      longitude: longitude,
    );
    debugPrint('[$logTag] lastPosted updated ($latitude, $longitude)');
    return null;
  }

  /// Max age for accepting a cached OS fix before forcing a fresh read.
  static const _lastKnownMaxAge = Duration(minutes: 30);

  /// One-shot position. Prefers a recent last-known fix, then falls back to
  /// a fresh provider read.
  static Future<Position?> _getOneShotPosition({
    bool preferLastKnown = true,
  }) async {
    try {
      Position? lastKnown;
      if (preferLastKnown) {
        lastKnown = await _tryLastKnown();
        if (_isUsablePosition(lastKnown)) {
          final age = DateTime.now().difference(lastKnown!.timestamp);
          if (age <= _lastKnownMaxAge) {
            debugPrint(
              '[Location] using lastKnown age=${age.inSeconds}s '
              '(${lastKnown.latitude}, ${lastKnown.longitude})',
            );
            return lastKnown;
          }
          debugPrint(
            '[Location] lastKnown too old age=${age.inSeconds}s — fetching fresh',
          );
        } else {
          lastKnown = null;
        }
      }

      if (!kIsWeb && Platform.isAndroid) {
        final fresh = await _getAndroidPosition();
        if (_isUsablePosition(fresh)) return fresh;
        if (preferLastKnown && _isUsablePosition(lastKnown)) {
          debugPrint(
            '[Location] fresh failed — falling back to stale lastKnown',
          );
          return lastKnown;
        }
        return null;
      }

      final fresh = await _getDefaultPosition();
      if (_isUsablePosition(fresh)) return fresh;
      return preferLastKnown && _isUsablePosition(lastKnown) ? lastKnown : null;
    } catch (e) {
      debugPrint('[Location] getOneShot failed: $e');
      return null;
    }
  }

  static bool _isUsablePosition(Position? position) {
    if (position == null) return false;
    final lat = position.latitude;
    final lng = position.longitude;
    return lat.isFinite && lng.isFinite;
  }

  static Future<Position?> _tryLastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      debugPrint('[Location] lastKnown failed: $e');
      return null;
    }
  }

  /// Coarse-only accuracies (no medium/high — we never need precise GPS).
  static const _approxAccuracies = [
    LocationAccuracy.lowest,
    LocationAccuracy.low,
  ];

  /// Android: race Fused + LocationManager with short timeouts.
  /// Manifest declares COARSE only — keep requests approximate.
  static Future<Position?> _getAndroidPosition() async {
    for (final accuracy in _approxAccuracies) {
      final got = await _raceCurrent(accuracy, const Duration(seconds: 6));
      if (got != null) return got;
    }

    return _raceWatch(const Duration(seconds: 12));
  }

  /// iOS / others: reduced/low accuracy only (approximate when possible).
  static Future<Position?> _getDefaultPosition() async {
    for (final accuracy in _approxAccuracies) {
      final got = await _tryCurrent(accuracy, const Duration(seconds: 10));
      if (got != null) return got;
    }
    return _watchFirst(const Duration(seconds: 15));
  }

  /// First non-null result from Fused vs classic LocationManager.
  static Future<Position?> _raceCurrent(
    LocationAccuracy accuracy,
    Duration timeLimit,
  ) async {
    final completer = Completer<Position?>();
    var pending = 2;

    void onDone(Position? position) {
      if (_isUsablePosition(position)) {
        if (!completer.isCompleted) completer.complete(position);
        return;
      }
      pending--;
      if (pending == 0 && !completer.isCompleted) completer.complete(null);
    }

    unawaited(
      _tryCurrent(
        accuracy,
        timeLimit,
        forceLocationManager: false,
      ).then(onDone, onError: (_) => onDone(null)),
    );
    unawaited(
      _tryCurrent(
        accuracy,
        timeLimit,
        forceLocationManager: true,
      ).then(onDone, onError: (_) => onDone(null)),
    );
    return completer.future;
  }

  static Future<Position?> _raceWatch(Duration timeout) async {
    final completer = Completer<Position?>();
    var pending = 2;

    void onDone(Position? position) {
      if (_isUsablePosition(position)) {
        if (!completer.isCompleted) completer.complete(position);
        return;
      }
      pending--;
      if (pending == 0 && !completer.isCompleted) completer.complete(null);
    }

    unawaited(
      _watchFirst(
        timeout,
        forceLocationManager: false,
      ).then(onDone, onError: (_) => onDone(null)),
    );
    unawaited(
      _watchFirst(
        timeout,
        forceLocationManager: true,
      ).then(onDone, onError: (_) => onDone(null)),
    );
    return completer.future;
  }

  static LocationSettings _settings(
    LocationAccuracy accuracy,
    Duration timeLimit, {
    bool forceLocationManager = false,
  }) {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        timeLimit: timeLimit,
        forceLocationManager: forceLocationManager,
        // Prefer a coarse/network fix quickly when GPS is cold.
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        // lowest → kCLLocationAccuracyReduced (approx) on iOS 14+.
        accuracy: accuracy,
        timeLimit: timeLimit,
        showBackgroundLocationIndicator: false,
      );
    }
    return LocationSettings(accuracy: accuracy, timeLimit: timeLimit);
  }

  static Future<Position?> _tryCurrent(
    LocationAccuracy accuracy,
    Duration timeLimit, {
    bool forceLocationManager = false,
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _settings(
          accuracy,
          timeLimit,
          forceLocationManager: forceLocationManager,
        ),
      );
    } catch (e) {
      debugPrint(
        '[Location] getCurrent($accuracy, lm=$forceLocationManager) failed: $e',
      );
      return null;
    }
  }

  static Future<Position?> _watchFirst(
    Duration timeout, {
    bool forceLocationManager = false,
  }) async {
    StreamSubscription<Position>? sub;
    try {
      final completer = Completer<Position?>();
      final timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(null);
      });

      sub =
          Geolocator.getPositionStream(
            locationSettings: _settings(
              LocationAccuracy.lowest,
              timeout,
              forceLocationManager: forceLocationManager,
            ),
          ).listen(
            (pos) {
              if (!completer.isCompleted) completer.complete(pos);
            },
            onError: (Object e) {
              debugPrint('[Location] watch failed: $e');
              if (!completer.isCompleted) completer.complete(null);
            },
          );

      final result = await completer.future;
      timer.cancel();
      return result;
    } catch (e) {
      debugPrint('[Location] watch setup failed: $e');
      return null;
    } finally {
      await sub?.cancel();
    }
  }

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static Future<bool> openLocationSettings() =>
      Geolocator.openLocationSettings();
}
