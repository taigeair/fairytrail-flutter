import 'dart:convert';

import 'package:fairytrail/billing/billing_plans.dart';
import 'package:fairytrail/config/daily_limit_copy_config.dart';
import 'package:fairytrail/config/free_trial_text_config.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:flutter/foundation.dart';

class InitResponse {
  const InitResponse({required this.kv});

  final Map<String, String> kv;

  factory InitResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['kv'];
    final kv = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k == null) return;
        kv[k.toString()] = v?.toString() ?? '';
      });
    }
    return InitResponse(kv: kv);
  }

  String? get acceptableBuild {
    final v = kv['acceptableBuild'];
    if (v == null || v.isEmpty) return null;
    return v;
  }

  bool get isMaintenance => kv['isMaintenence'] == 'true';

  /// RN `remoteConfig['showRateKindnessBanner']`
  bool get showRateKindnessBanner => kv['showRateKindnessBanner'] == 'true';

  /// When true (default), show the "Give us a rating!" step during signup.
  bool get showRateUsOnboarding {
    final v = kv['showRateUsOnboarding'];
    if (v == null || v.isEmpty) return true;
    return v == 'true';
  }

  /// When true (default), Continue on the signup rate step opens a custom
  /// star-rating dialog before advancing.
  bool get showCustomRatingPopup {
    final v = kv['showCustomRatingPopup'];
    if (v == null || v.isEmpty) return true;
    return v == 'true';
  }

  /// Gift a subscription button on other profiles.
  bool get showGiftSubscription => kv['showGiftSubscription'] == 'true';

  /// Whether Stripe-powered Trail Money top-ups are available.
  bool get isStripeEnabled => kv['isStripeEnabled'] == 'true';

  /// When true (default), signup ends on Silver free-trial screen.
  /// When false, signup skips the free-trial offer.
  /// Server resolves `show_free_trial_A` / `show_free_trial_B` by test group.
  bool get showFreeTrial {
    final v = kv['show_free_trial'];
    if (v == null || v.isEmpty) return true;
    return v == 'true';
  }

  /// When true (default), show the close (X) on the Silver free-trial screen.
  bool get showFreeTrialX {
    final v = kv['show_free_trial_x'];
    if (v == null || v.isEmpty) return true;
    return v == 'true';
  }

  /// RevenueCat package id for Silver weekly on the upgrade paywall.
  ///
  /// Reads the resolved `silver_weekly_package_id`, or the assigned
  /// `silver_weekly_package_id_A` / `_B` key when the server only sends the
  /// winning variant. Accepts `$rc_weekly` / `weekly_b` or `A` / `B`.
  /// Defaults to `$rc_weekly` (control).
  String get silverWeeklyPackageId {
    final resolved = _nonEmpty(kv['silver_weekly_package_id']);
    if (resolved != null) return normalizeSilverWeeklyPackageId(resolved);

    final a = _nonEmpty(kv['silver_weekly_package_id_A']);
    final b = _nonEmpty(kv['silver_weekly_package_id_B']);
    if (b != null && a == null) return normalizeSilverWeeklyPackageId(b);
    if (a != null && b == null) return normalizeSilverWeeklyPackageId(a);
    return r'$rc_weekly';
  }

  static String? _nonEmpty(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  /// Explore daily-limit copy + image (`daily_limit_copy_json`, A/B on server).
  DailyLimitCopyConfig get dailyLimitCopy {
    final raw = kv['daily_limit_copy_json'];
    if (raw == null || raw.isEmpty) return DailyLimitCopyConfig.defaults;
    try {
      final cleaned = raw.replaceAll('\\', '');
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map) return DailyLimitCopyConfig.defaults;
      return DailyLimitCopyConfig.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return DailyLimitCopyConfig.defaults;
    }
  }

  /// Copy for the Silver free-trial paywall (`free_trial_text_json`).
  FreeTrialTextConfig get freeTrialText {
    final raw = kv['free_trial_text_json'];
    if (raw == null || raw.isEmpty) return FreeTrialTextConfig.defaults;
    try {
      final cleaned = raw.replaceAll('\\', '');
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map) return FreeTrialTextConfig.defaults;
      return FreeTrialTextConfig.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return FreeTrialTextConfig.defaults;
    }
  }

  /// Second timeline icon on Silver free-trial: `explore` | `bell` (default).
  String get freeTrial2ndIcon {
    final v = kv['free_trial_2nd_icon']?.trim().toLowerCase();
    if (v == 'explore') return 'explore';
    return 'bell';
  }

  /// RN `remoteConfig['reviewTitleText']`
  String get reviewTitleText {
    final v = kv['reviewTitleText'];
    if (v == null || v.isEmpty) return 'A quick favor!';
    return v;
  }

  /// RN `remoteConfig['reviewBodyText']`
  String get reviewBodyText {
    final v = kv['reviewBodyText'];
    if (v == null || v.isEmpty) {
      return 'A short review helps more people discover and trust our app. '
          'Tell us what you love.';
    }
    return v;
  }

  int get adsFrequency {
    final value = int.tryParse(kv['ads_frequency'] ?? '');
    return value != null && value > 0 ? value : 3;
  }

  /// Successful profile actions kept ad-free after the first Connect.
  int get firstConnectAdGraceActions {
    final value = int.tryParse(kv['first_connect_ad_grace_actions'] ?? '');
    return value != null && value >= 0 ? value : 60;
  }

  /// When true, activity search runs only on Search/OK submit.
  /// When false (default), it debounces as the user types.
  bool get activitySearchOnSubmit => kv['activity_search_on_submit'] == 'true';

  int? get rewardsAdsFrequency {
    final value = int.tryParse(kv['rewards_ads_frequency'] ?? '');
    return value != null && value > 0 ? value : null;
  }

  String? get nativeAdsBannerImage {
    final value = kv['native_ads_banner_image']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get nativeAdsOfferUrl {
    final value = kv['native_ads_offer_url']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// RN `remoteConfig['verificationFeeGroup']` RevenueCat offering ID.
  String? get verificationFeeGroup {
    final value = kv['verificationFeeGroup']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// RN `remoteConfig['verificationButtonText']` — e.g. `Verify - $4.99`.
  /// When set, the verification CTA should prefer this over RevenueCat price.
  String? get verificationButtonText {
    final value = kv['verificationButtonText']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Fullscreen announcement webview for logged-in users.
  /// Meetups feature flag (default true when unset so local/dev works).
  bool get meetupEnabled {
    final v = kv['meetup_enabled'];
    if (v == null || v.isEmpty) return true;
    return v == 'true' || v == '1';
  }

  /// ISO-2 country codes where meetups are off, e.g. `US,AE,CN`.
  Set<String> get meetupDisabledCountries {
    final raw = kv['meetup_disabled_countries'] ?? '';
    if (raw.trim().isEmpty) return const {};
    return raw
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  /// True when meetups are on globally and [countryCode] is not disabled.
  bool meetupEnabledForCountry(String? countryCode) {
    if (!meetupEnabled) return false;
    final code = countryCode?.trim().toUpperCase();
    if (code == null || code.isEmpty) return true;
    return !meetupDisabledCountries.contains(code);
  }

  int get meetupTermsVersion {
    final value = int.tryParse(kv['meetup_terms_version'] ?? '');
    if (value == null || value <= 0) return 1;
    return value;
  }

  bool get showAdminPopup {
    final v = kv['show_admin_popup'];
    if (v == null || v.isEmpty) return false;
    return v == 'true';
  }

  /// Monotonic announcement id — bump to show the popup again.
  int get showAdminPopupVersion {
    final value = int.tryParse(kv['show_admin_popup_version'] ?? '');
    return value != null && value > 0 ? value : 0;
  }

  /// Public URL loaded in the admin popup webview (no auth).
  String? get showAdminPopupUrl {
    final value = kv['show_admin_popup_url']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// RN `remoteConfig['scheduledLocalNotificationParams']` for inactive-user reminders.
  ScheduledLocalNotificationParams? get scheduledLocalNotificationParams {
    final raw = kv['scheduledLocalNotificationParams'];
    if (raw == null || raw.isEmpty) return null;
    try {
      final cleaned = raw.replaceAll('\\', '');
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final duration = map['duration'];
      final durationMinutes = duration is int
          ? duration
          : int.tryParse(duration?.toString() ?? '');
      final title = map['title']?.toString();
      final body = map['body']?.toString();
      if (durationMinutes == null ||
          durationMinutes <= 0 ||
          title == null ||
          title.isEmpty ||
          body == null ||
          body.isEmpty) {
        return null;
      }
      return ScheduledLocalNotificationParams(
        durationMinutes: durationMinutes,
        title: title,
        body: body,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Params for the inactive-user local reminder (RN `scheduledLocalNotificationParams`).
class ScheduledLocalNotificationParams {
  const ScheduledLocalNotificationParams({
    required this.durationMinutes,
    required this.title,
    required this.body,
  });

  final int durationMinutes;
  final String title;
  final String body;
}

/// GET /api/v1/init — remote config (force-update / maintenance flags).
Future<InitResponse> fetchInit({bool requiresAuth = true}) async {
  final response = await HttpClient.instance.request(
    path: EndPoints.init,
    method: HttpMethod.get,
    requiresAuth: requiresAuth,
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected init response',
      payload: data,
    );
  }

  final init = InitResponse.fromJson(Map<String, dynamic>.from(data));
  _logWeeklyAb(init);
  return init;
}

void _logWeeklyAb(InitResponse init) {
  if (!kDebugMode) return;
  final weeklyKv = Map<String, String>.fromEntries(
    init.kv.entries.where((e) {
      final k = e.key.toLowerCase();
      return k.contains('week') ||
          k.contains('silver_weekly') ||
          k.contains('package_id') ||
          k.endsWith('_a') ||
          k.endsWith('_b');
    }),
  );
  debugPrint('[Init] silverWeeklyPackageId=${init.silverWeeklyPackageId}');
  debugPrint('[Init] weekly/AB kv ($weeklyKv)');
  debugPrint('[Init] all kv keys=${(init.kv.keys.toList()..sort())}');
}
