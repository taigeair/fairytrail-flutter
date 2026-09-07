import 'dart:async';

import 'package:fairytrail/ads/ad_config.dart';
import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// ATT-aware single initialization, preloading, and backoff point for ads.
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();
  static const _cacheLifetime = Duration(minutes: 55);
  static const _loadBackoff = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  final Completer<void> _ready = Completer<void>();
  bool _initialized = false;
  bool _initializing = false;
  bool _trackingAllowed = false;

  InterstitialAd? _interstitial;
  DateTime? _interstitialLoadedAt;
  Completer<bool>? _interstitialLoad;
  int _interstitialFailures = 0;
  DateTime? _interstitialRetryAfter;

  RewardedAd? _rewarded;
  DateTime? _rewardedLoadedAt;
  Completer<bool>? _rewardedLoad;
  int _rewardedFailures = 0;
  DateTime? _rewardedRetryAfter;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  bool get isInitialized => _initialized;
  Future<void> get ready => _ready.future;

  Future<void> initialize({required bool trackingAllowed}) async {
    if (_initialized || _initializing) return ready;
    _initializing = true;
    _trackingAllowed = trackingAllowed;
    try {
      if (!isSupported) return;
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(),
      );
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await MobileAds.instance.setSameAppKeyEnabled(trackingAllowed);
      }
      await MobileAds.instance.initialize();
      _initialized = true;
      _log('initialized; personalized=$trackingAllowed');
    } catch (error) {
      _log('initialization failed: $error');
    } finally {
      _initializing = false;
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  AdRequest interstitialRequest() => AdRequest(
    keywords: AdConfig.bannerKeywords,
    nonPersonalizedAds:
        defaultTargetPlatform == TargetPlatform.iOS && !_trackingAllowed,
  );

  AdRequest rewardedRequest() => AdRequest(
    keywords: AdConfig.rewardedKeywords,
    nonPersonalizedAds:
        defaultTargetPlatform == TargetPlatform.iOS && !_trackingAllowed,
  );

  String get interstitialUnitId =>
      AdConfig.interstitialUnitId(defaultTargetPlatform);
  String get rewardedUnitId => AdConfig.rewardedUnitId(defaultTargetPlatform);

  Future<bool> prefetchInterstitial() async {
    await ready;
    if (!_initialized) return false;
    _expireInterstitialIfNeeded();
    if (_interstitial != null) return true;
    final activeLoad = _interstitialLoad;
    if (activeLoad != null) return activeLoad.future;
    if (_isCoolingDown(_interstitialRetryAfter)) return false;

    final completion = Completer<bool>();
    _interstitialLoad = completion;
    try {
      await InterstitialAd.load(
        adUnitId: interstitialUnitId,
        request: interstitialRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
            _interstitialLoadedAt = DateTime.now();
            _interstitialFailures = 0;
            _interstitialRetryAfter = null;
            _finishInterstitialLoad(completion, true);
            _log('interstitial prefetched');
          },
          onAdFailedToLoad: (error) {
            _recordInterstitialFailure(error);
            _finishInterstitialLoad(completion, false);
          },
        ),
      );
    } catch (error) {
      _recordUnexpectedFailure('interstitial', error);
      _finishInterstitialLoad(completion, false);
    }
    return completion.future;
  }

  Future<bool> showInterstitial({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    _expireInterstitialIfNeeded();
    if (_interstitial == null) {
      try {
        await prefetchInterstitial().timeout(timeout);
      } on TimeoutException {
        _log('interstitial load timed out; using fallback');
      }
    }
    _expireInterstitialIfNeeded();
    final ad = _interstitial;
    _interstitial = null;
    _interstitialLoadedAt = null;
    if (ad == null) return false;

    final completion = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissedAd) {
        dismissedAd.dispose();
        if (!completion.isCompleted) completion.complete(true);
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        failedAd.dispose();
        _recordLoadFailure('interstitial_show', error.code, error.domain);
        if (!completion.isCompleted) completion.complete(false);
      },
    );
    try {
      ad.show();
    } catch (error) {
      ad.dispose();
      _recordUnexpectedFailure('interstitial_show', error);
      if (!completion.isCompleted) completion.complete(false);
    }
    return completion.future;
  }

  Future<bool> prefetchRewarded() async {
    await ready;
    if (!_initialized) return false;
    _expireRewardedIfNeeded();
    if (_rewarded != null) return true;
    final activeLoad = _rewardedLoad;
    if (activeLoad != null) return activeLoad.future;
    if (_isCoolingDown(_rewardedRetryAfter)) return false;

    final completion = Completer<bool>();
    _rewardedLoad = completion;
    try {
      await RewardedAd.load(
        adUnitId: rewardedUnitId,
        request: rewardedRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewarded = ad;
            _rewardedLoadedAt = DateTime.now();
            _rewardedFailures = 0;
            _rewardedRetryAfter = null;
            _finishRewardedLoad(completion, true);
            _log('rewarded ad prefetched');
          },
          onAdFailedToLoad: (error) {
            _recordRewardedFailure(error);
            _finishRewardedLoad(completion, false);
          },
        ),
      );
    } catch (error) {
      _recordUnexpectedFailure('rewarded', error);
      _finishRewardedLoad(completion, false);
    }
    return completion.future;
  }

  Future<RewardedAd?> takeOrLoadRewarded({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    _expireRewardedIfNeeded();
    if (_rewarded == null) {
      try {
        await prefetchRewarded().timeout(timeout);
      } on TimeoutException {
        _log('rewarded load timed out; continuing Explore');
      }
    }
    _expireRewardedIfNeeded();
    final ad = _rewarded;
    _rewarded = null;
    _rewardedLoadedAt = null;
    return ad;
  }

  void _finishInterstitialLoad(Completer<bool> completion, bool loaded) {
    if (!completion.isCompleted) completion.complete(loaded);
    if (identical(_interstitialLoad, completion)) _interstitialLoad = null;
  }

  void _finishRewardedLoad(Completer<bool> completion, bool loaded) {
    if (!completion.isCompleted) completion.complete(loaded);
    if (identical(_rewardedLoad, completion)) _rewardedLoad = null;
  }

  void _recordInterstitialFailure(LoadAdError error) {
    _interstitialFailures++;
    _interstitialRetryAfter = DateTime.now().add(
      _backoffFor(_interstitialFailures),
    );
    _log(
      'interstitial unavailable: code=${error.code}; '
      'retry=$_interstitialRetryAfter',
    );
    _recordLoadFailure('interstitial', error.code, error.domain);
  }

  void _recordRewardedFailure(LoadAdError error) {
    _rewardedFailures++;
    _rewardedRetryAfter = DateTime.now().add(_backoffFor(_rewardedFailures));
    _log(
      'rewarded unavailable: code=${error.code}; retry=$_rewardedRetryAfter',
    );
    _recordLoadFailure('rewarded', error.code, error.domain);
  }

  void _recordUnexpectedFailure(String format, Object error) {
    if (format.startsWith('interstitial')) {
      _interstitialFailures++;
      _interstitialRetryAfter = DateTime.now().add(
        _backoffFor(_interstitialFailures),
      );
    } else {
      _rewardedFailures++;
      _rewardedRetryAfter = DateTime.now().add(_backoffFor(_rewardedFailures));
    }
    _log('$format load failed: $error');
    _recordLoadFailure(format, -1, error.runtimeType.toString());
  }

  void _recordLoadFailure(String format, int code, String domain) {
    unawaited(
      AnalyticsService.instance.logEvent('ad_load_failed', {
        'format': format,
        'code': code,
        'domain': domain,
      }),
    );
  }

  void _expireInterstitialIfNeeded() {
    final loadedAt = _interstitialLoadedAt;
    if (_interstitial == null || loadedAt == null) return;
    if (DateTime.now().difference(loadedAt) < _cacheLifetime) return;
    _interstitial?.dispose();
    _interstitial = null;
    _interstitialLoadedAt = null;
  }

  void _expireRewardedIfNeeded() {
    final loadedAt = _rewardedLoadedAt;
    if (_rewarded == null || loadedAt == null) return;
    if (DateTime.now().difference(loadedAt) < _cacheLifetime) return;
    _rewarded?.dispose();
    _rewarded = null;
    _rewardedLoadedAt = null;
  }

  static bool _isCoolingDown(DateTime? retryAfter) =>
      retryAfter != null && DateTime.now().isBefore(retryAfter);

  static Duration _backoffFor(int failures) =>
      _loadBackoff[(failures - 1).clamp(0, _loadBackoff.length - 1)];

  static void _log(String message) {
    if (kDebugMode) debugPrint('[Ads] $message');
  }
}
