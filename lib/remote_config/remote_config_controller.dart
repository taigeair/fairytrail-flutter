import 'package:fairytrail/api/init.dart';
import 'package:fairytrail/config/billing_config.dart';
import 'package:fairytrail/config/daily_limit_copy_config.dart';
import 'package:fairytrail/config/free_trial_text_config.dart';
import 'package:flutter/material.dart';

/// Global remote config from `GET /api/v1/init` — same pattern as [ThemeController].
class RemoteConfigController extends ChangeNotifier {
  RemoteConfigController();

  InitResponse? _init;
  bool _refreshing = false;
  Future<void>? _refreshFuture;

  InitResponse? get init => _init;
  bool get isReady => _init != null;
  bool get isRefreshing => _refreshing;

  String? get acceptableBuild => _init?.acceptableBuild;
  bool get isMaintenance => _init?.isMaintenance ?? false;
  bool get showRateKindnessBanner => _init?.showRateKindnessBanner ?? false;
  bool get showRateUsOnboarding => _init?.showRateUsOnboarding ?? true;
  bool get showCustomRatingPopup => _init?.showCustomRatingPopup ?? true;
  bool get showGiftSubscription => _init?.showGiftSubscription ?? false;
  bool get isStripeEnabled => _init?.isStripeEnabled ?? false;
  bool get showFreeTrial => _init?.showFreeTrial ?? true;
  bool get showFreeTrialX => _init?.showFreeTrialX ?? true;
  String get silverWeeklyPackageId =>
      _init?.silverWeeklyPackageId ?? r'$rc_weekly';
  FreeTrialTextConfig get freeTrialText =>
      _init?.freeTrialText ?? FreeTrialTextConfig.defaults;
  DailyLimitCopyConfig get dailyLimitCopy =>
      _init?.dailyLimitCopy ?? DailyLimitCopyConfig.defaults;

  /// Second free-trial timeline icon: `explore` | `bell` (default).
  String get freeTrial2ndIcon => _init?.freeTrial2ndIcon ?? 'bell';
  String get reviewTitleText => _init?.reviewTitleText ?? 'A quick favor!';
  String get reviewBodyText =>
      _init?.reviewBodyText ??
      'A short review helps more people discover and trust our app. '
          'Tell us what you love.';
  int get adsFrequency => _init?.adsFrequency ?? 3;
  int get firstConnectAdGraceActions => _init?.firstConnectAdGraceActions ?? 60;

  /// When true, activity search runs only on submit; false debounces on type.
  bool get activitySearchOnSubmit => _init?.activitySearchOnSubmit ?? false;
  int? get rewardsAdsFrequency => _init?.rewardsAdsFrequency;
  String? get nativeAdsBannerImage => _init?.nativeAdsBannerImage;
  String? get nativeAdsOfferUrl => _init?.nativeAdsOfferUrl;
  String get verificationOfferingId =>
      _init?.verificationFeeGroup ?? BillingConfig.verificationOfferingId;

  /// Remote CTA label when present; otherwise null (use RevenueCat price).
  String? get verificationButtonText => _init?.verificationButtonText;

  bool get meetupEnabled => _init?.meetupEnabled ?? false;
  Set<String> get meetupDisabledCountries =>
      _init?.meetupDisabledCountries ?? const {};
  int get meetupTermsVersion => _init?.meetupTermsVersion ?? 1;

  bool meetupEnabledForCountry(String? countryCode) =>
      _init?.meetupEnabledForCountry(countryCode) ?? false;

  /// Profile country ISO-2, else device locale country (OS region).
  static String? effectiveMeetupCountryCode(String? profileCountryCode) {
    final profile = profileCountryCode?.trim();
    if (profile != null && profile.isNotEmpty) {
      return profile.toUpperCase();
    }
    final os = WidgetsBinding.instance.platformDispatcher.locale.countryCode
        ?.trim();
    if (os == null || os.isEmpty) return null;
    return os.toUpperCase();
  }

  /// Meetups visible for this user (global flag + disabled countries).
  bool meetupsVisibleForProfile(String? profileCountryCode) =>
      meetupEnabledForCountry(effectiveMeetupCountryCode(profileCountryCode));

  bool get showAdminPopup => _init?.showAdminPopup ?? false;
  int get showAdminPopupVersion => _init?.showAdminPopupVersion ?? 0;
  String? get showAdminPopupUrl => _init?.showAdminPopupUrl;

  Future<void> refresh({bool requiresAuth = true}) {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;

    final future = _performRefresh(requiresAuth: requiresAuth);
    _refreshFuture = future;
    return future;
  }

  Future<void> _performRefresh({required bool requiresAuth}) async {
    _refreshing = true;
    try {
      _init = await fetchInit(requiresAuth: requiresAuth);
      notifyListeners();
    } finally {
      _refreshing = false;
      _refreshFuture = null;
    }
  }
}

/// Provides [RemoteConfigController] down the tree.
class RemoteConfigScope extends InheritedNotifier<RemoteConfigController> {
  const RemoteConfigScope({
    super.key,
    required RemoteConfigController controller,
    required super.child,
  }) : super(notifier: controller);

  static RemoteConfigController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<RemoteConfigScope>();
    assert(scope != null, 'RemoteConfigScope not found in widget tree');
    return scope!.notifier!;
  }

  static RemoteConfigController? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<RemoteConfigScope>();
    return scope?.notifier;
  }
}
