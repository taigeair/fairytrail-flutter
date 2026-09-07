import 'dart:async';

import 'package:fairytrail/ads/ads_service.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:fairytrail/analytics/meta_events_service.dart';
import 'package:flutter/foundation.dart';

enum AppTrackingConsentStatus {
  authorized,
  denied,
  restricted,
  notDetermined,
  notSupported,
}

abstract interface class TrackingAuthorizationClient {
  bool get usesAppTrackingTransparency;

  Future<AppTrackingConsentStatus> status();

  Future<AppTrackingConsentStatus> request();
}

class NativeTrackingAuthorizationClient implements TrackingAuthorizationClient {
  const NativeTrackingAuthorizationClient();

  @override
  bool get usesAppTrackingTransparency =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<AppTrackingConsentStatus> status() async {
    if (!usesAppTrackingTransparency) {
      return AppTrackingConsentStatus.notSupported;
    }
    return _mapStatus(
      await AppTrackingTransparency.trackingAuthorizationStatus,
    );
  }

  @override
  Future<AppTrackingConsentStatus> request() async {
    if (!usesAppTrackingTransparency) {
      return AppTrackingConsentStatus.notSupported;
    }
    return _mapStatus(
      await AppTrackingTransparency.requestTrackingAuthorization(),
    );
  }

  static AppTrackingConsentStatus _mapStatus(TrackingStatus status) {
    return switch (status) {
      TrackingStatus.authorized => AppTrackingConsentStatus.authorized,
      TrackingStatus.denied => AppTrackingConsentStatus.denied,
      TrackingStatus.restricted => AppTrackingConsentStatus.restricted,
      TrackingStatus.notDetermined => AppTrackingConsentStatus.notDetermined,
      TrackingStatus.notSupported => AppTrackingConsentStatus.notSupported,
    };
  }
}

typedef TrackingInitializer = Future<void> Function(bool trackingAllowed);

/// Coordinates native ATT with tracking-dependent SDK initialization.
///
/// Firebase Analytics is intentionally not managed here: the app uses it for
/// first-party, non-advertising analytics. Advertising and attribution SDKs
/// must be initialized from [initializeTracking] only.
class TrackingConsentService {
  TrackingConsentService({
    required this.client,
    required this.initializeTracking,
    this.delay = Future<void>.delayed,
  });

  static final TrackingConsentService instance = TrackingConsentService(
    client: const NativeTrackingAuthorizationClient(),
    initializeTracking: TrackingDependentServices.instance.initialize,
  );

  @visibleForTesting
  final TrackingAuthorizationClient client;
  @visibleForTesting
  final TrackingInitializer initializeTracking;
  @visibleForTesting
  final Future<void> Function(Duration) delay;

  bool _inFlight = false;
  bool _handled = false;

  Future<void> requestAfterInterfaceIsVisible({
    required bool Function() isAppActive,
    Duration presentationDelay = const Duration(milliseconds: 800),
  }) async {
    if (_handled || _inFlight || !isAppActive()) return;
    _inFlight = true;

    try {
      if (!client.usesAppTrackingTransparency) {
        await _complete(
          AppTrackingConsentStatus.notSupported,
          allowTracking: true,
        );
        return;
      }

      await delay(presentationDelay);
      if (!isAppActive()) return;

      var result = await client.status();
      _debugLog('current status: ${result.name}');
      if (result == AppTrackingConsentStatus.notDetermined) {
        result = await client.request();
        _debugLog('request result: ${result.name}');
      }
      await _complete(result);
    } catch (error) {
      _debugLog('request failed: $error');
      await _complete(
        AppTrackingConsentStatus.notSupported,
        allowTracking: false,
      );
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _complete(
    AppTrackingConsentStatus status, {
    bool? allowTracking,
  }) async {
    if (_handled) return;
    _handled = true;
    final allowed =
        allowTracking ?? status == AppTrackingConsentStatus.authorized;
    _debugLog(
      'tracking-dependent services ${allowed ? 'enabled' : 'disabled'} '
      '(${status.name})',
    );
    await initializeTracking(allowed);
  }

  static void _debugLog(String message) {
    if (kDebugMode) debugPrint('[TrackingConsent] $message');
  }
}

/// Single initialization point for advertising and attribution SDKs.
class TrackingDependentServices {
  TrackingDependentServices._();

  static final TrackingDependentServices instance =
      TrackingDependentServices._();

  bool _initialized = false;

  Future<void> initialize(bool trackingAllowed) async {
    if (_initialized) return;
    _initialized = true;
    await AdsService.instance.initialize(trackingAllowed: trackingAllowed);
    if (kDebugMode) {
      debugPrint(
        '[TrackingSDKs] initialized; trackingAllowed=$trackingAllowed',
      );
    }
    await MetaEventsService.instance.initialize(
      trackingAllowed: trackingAllowed,
    );
  }
}
