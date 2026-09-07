import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Meta (Facebook) App Events — mirrors React Native `react-native-fbsdk-next`.
class MetaEventsService {
  MetaEventsService._();

  static final MetaEventsService instance = MetaEventsService._();

  final FacebookAppEvents _fb = FacebookAppEvents();
  bool _initialized = false;

  /// Called from [TrackingDependentServices] after ATT is resolved.
  Future<void> initialize({required bool trackingAllowed}) async {
    if (_initialized || kIsWeb) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;

    try {
      // Match RN: auto-log + advertiser ID collection on; ATT gates IDFA usage.
      await _fb.setAutoLogAppEventsEnabled(true);
      await _fb.setAdvertiserIdCollectionEnabled(true);
      // ignore: deprecated_member_use
      await _fb.setAdvertiserTracking(enabled: trackingAllowed);
      await _fb.activateApp();
      if (kDebugMode) {
        await _fb.setDebugLoggingEnabled(true);
      }
      _initialized = true;
      await _fb.flush();
      if (kDebugMode) {
        final appId = await _fb.getApplicationId();
        final anonId = await _fb.getAnonymousId();
        debugPrint(
          '[MetaEvents] initialized; trackingAllowed=$trackingAllowed '
          'appId=$appId anonId=$anonId',
        );
      }
    } catch (e, st) {
      debugPrint('[MetaEvents] initialize failed: $e\n$st');
    }
  }

  /// Logs on iOS/Android (including debug) so Events Manager Test Events work
  /// during development. RN skipped `__DEV__`; we keep debug logging enabled
  /// via [FacebookAppEvents.setDebugLoggingEnabled] instead.
  bool get _shouldLogCustomEvents =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> logRegistrationCompleted({
    required String registrationMethod,
    required String profileType,
    required String userId,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_shouldLogCustomEvents) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;

    final platform = Platform.isIOS ? 'ios' : 'android';
    final params = <String, dynamic>{
      'registration_method': registrationMethod,
      'registration_source': 'app',
      'registration_platform': platform,
      'registration_platform_version': Platform.operatingSystemVersion,
      'profile_type': profileType,
      'user_id': userId,
      if (additionalData != null) 'additional_data': jsonEncode(additionalData),
    };

    final sanitized = _sanitize(params);
    _printFire('fb_mobile_complete_registration', sanitized);
    _printFire('fb_registration_completed', sanitized);

    unawaited(
      _safe(() async {
        await _fb.logCompletedRegistration(
          registrationMethod: registrationMethod,
          parameters: sanitized,
        );
        await _fb.logEvent(
          name: 'fb_registration_completed',
          parameters: sanitized,
        );
        await _fb.flush();
        _printFlushed('fb_registration_completed');
      }),
    );
  }

  /// Logs Meta standard purchase + RN-parity custom subscription events.
  Future<void> logSubscriptionPurchase({
    required String eventName,
    required String tier,
    required String previousTier,
    required double price,
    required String currency,
    required String priceString,
    required int duration,
    required String durationType,
    required String productId,
    String? productTitle,
    String? subscriptionPeriod,
    String? transactionId,
    String? purchaseDate,
    String? from,
    String? reason,
    String? userId,
  }) {
    return _logPurchase(
      customEventName: eventName,
      contentType: 'subscription',
      amount: price,
      currency: currency,
      priceString: priceString,
      productId: productId,
      productTitle: productTitle,
      subscriptionPeriod: subscriptionPeriod,
      transactionId: transactionId,
      purchaseDate: purchaseDate,
      from: from,
      reason: reason,
      userId: userId,
      extra: {
        'tier': tier,
        'previous_tier': previousTier,
        'duration': duration,
        'duration_type': durationType,
      },
      alsoLogSubscribe: true,
    );
  }

  /// Logs Meta standard StartTrial + custom `started_free_trial`.
  Future<void> logStartedFreeTrial({
    required String tier,
    required double price,
    required String currency,
    required String priceString,
    required int duration,
    required String durationType,
    required String productId,
    int? trialDays,
    String? productTitle,
    String? subscriptionPeriod,
    String? transactionId,
    String? purchaseDate,
    String? from,
    String? userId,
  }) async {
    if (!_shouldLogCustomEvents) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;

    final now = DateTime.now().toUtc();
    final locale = PlatformDispatcher.instance.locale;
    final platform = Platform.isIOS ? 'ios' : 'android';
    final orderId = (transactionId != null && transactionId.isNotEmpty)
        ? transactionId
        : 'trial_${now.millisecondsSinceEpoch}';

    final params = <String, dynamic>{
      'price': price,
      'currency': currency,
      'price_string': priceString,
      'country': locale.countryCode ?? '',
      'locale': locale.toLanguageTag(),
      'purchase_time': now.toIso8601String(),
      'purchase_timestamp_ms': now.millisecondsSinceEpoch,
      if (purchaseDate != null && purchaseDate.isNotEmpty)
        'store_purchase_date': purchaseDate,
      'product_id': productId,
      if (productTitle != null && productTitle.isNotEmpty)
        'product_title': productTitle,
      if (subscriptionPeriod != null && subscriptionPeriod.isNotEmpty)
        'subscription_period': subscriptionPeriod,
      'content_type': 'subscription',
      FacebookAppEvents.paramNameContentType: 'subscription',
      FacebookAppEvents.paramNameContentId: productId,
      FacebookAppEvents.paramNameCurrency: currency,
      'transaction_id': orderId,
      FacebookAppEvents.paramNameOrderId: orderId,
      'platform': platform,
      'platform_version': Platform.operatingSystemVersion,
      'payment_method': Platform.isIOS ? 'apple_pay' : 'google_pay',
      'tier': tier,
      'duration': duration,
      'duration_type': durationType,
      if (trialDays != null) 'trial_days': trialDays,
      if (from != null && from.isNotEmpty) 'from': from,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
    };

    final sanitized = _sanitize(params);
    _printFire(FacebookAppEvents.eventNameStartTrial, sanitized);
    _printFire('started_free_trial', sanitized);

    unawaited(
      _safe(() async {
        await _fb.logStartTrial(
          price: price,
          currency: currency,
          orderId: orderId,
          parameters: sanitized,
        );
        await _fb.logEvent(
          name: 'started_free_trial',
          valueToSum: price,
          parameters: sanitized,
        );
        await _fb.flush();
        _printFlushed('started_free_trial');
      }),
    );
  }

  Future<void> logOneTimePurchase({
    required String customEventName,
    required String contentType,
    required double price,
    required String currency,
    required String priceString,
    required String productId,
    String? productTitle,
    String? transactionId,
    String? purchaseDate,
    String? from,
    String? userId,
    Map<String, dynamic>? extra,
  }) {
    return _logPurchase(
      customEventName: customEventName,
      contentType: contentType,
      amount: price,
      currency: currency,
      priceString: priceString,
      productId: productId,
      productTitle: productTitle,
      transactionId: transactionId,
      purchaseDate: purchaseDate,
      from: from,
      userId: userId,
      extra: extra,
      alsoLogSubscribe: false,
    );
  }

  Future<void> logPurchaseFromStoreProduct({
    required String customEventName,
    required String contentType,
    required StoreProduct product,
    required StoreTransaction transaction,
    String? from,
    String? userId,
    Map<String, dynamic>? extra,
  }) {
    return _logPurchase(
      customEventName: customEventName,
      contentType: contentType,
      amount: product.price,
      currency: product.currencyCode,
      priceString: product.priceString,
      productId: product.identifier,
      productTitle: product.title,
      subscriptionPeriod: product.subscriptionPeriod,
      transactionId: transaction.transactionIdentifier,
      purchaseDate: transaction.purchaseDate,
      from: from,
      userId: userId,
      extra: extra,
      alsoLogSubscribe: contentType == 'subscription',
    );
  }

  Future<void> _logPurchase({
    required String customEventName,
    required String contentType,
    required double amount,
    required String currency,
    required String priceString,
    required String productId,
    String? productTitle,
    String? subscriptionPeriod,
    String? transactionId,
    String? purchaseDate,
    String? from,
    String? reason,
    String? userId,
    Map<String, dynamic>? extra,
    required bool alsoLogSubscribe,
  }) async {
    if (!_shouldLogCustomEvents) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;

    final now = DateTime.now().toUtc();
    final locale = PlatformDispatcher.instance.locale;
    final platform = Platform.isIOS ? 'ios' : 'android';
    final paymentMethod = Platform.isIOS ? 'apple_pay' : 'google_pay';

    final params = <String, dynamic>{
      'price': amount,
      'currency': currency,
      'price_string': priceString,
      'country': locale.countryCode ?? '',
      'locale': locale.toLanguageTag(),
      'purchase_time': now.toIso8601String(),
      'purchase_timestamp_ms': now.millisecondsSinceEpoch,
      if (purchaseDate != null && purchaseDate.isNotEmpty)
        'store_purchase_date': purchaseDate,
      'product_id': productId,
      if (productTitle != null && productTitle.isNotEmpty)
        'product_title': productTitle,
      if (subscriptionPeriod != null && subscriptionPeriod.isNotEmpty)
        'subscription_period': subscriptionPeriod,
      'content_type': contentType,
      FacebookAppEvents.paramNameContentType: contentType,
      FacebookAppEvents.paramNameContentId: productId,
      FacebookAppEvents.paramNameCurrency: currency,
      if (transactionId != null && transactionId.isNotEmpty) ...{
        'transaction_id': transactionId,
        FacebookAppEvents.paramNameOrderId: transactionId,
      },
      'platform': platform,
      'platform_version': Platform.operatingSystemVersion,
      'payment_method': paymentMethod,
      if (from != null && from.isNotEmpty) 'from': from,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      ...?extra,
    };

    final sanitized = _sanitize(params);
    _printFire('fb_mobile_purchase', sanitized);
    if (alsoLogSubscribe) {
      _printFire(FacebookAppEvents.eventNameSubscribe, sanitized);
    }
    _printFire(customEventName, sanitized);

    unawaited(
      _safe(() async {
        await _fb.logPurchase(
          amount: amount,
          currency: currency,
          parameters: sanitized,
        );
        if (alsoLogSubscribe) {
          await _fb.logEvent(
            name: FacebookAppEvents.eventNameSubscribe,
            valueToSum: amount,
            parameters: sanitized,
          );
        }
        await _fb.logEvent(
          name: customEventName,
          valueToSum: amount,
          parameters: sanitized,
        );
        await _fb.flush();
        _printFlushed(customEventName);
      }),
    );
  }

  /// Generic custom event (e.g. sample / debug events).
  Future<void> logCustomEvent(
    String name, {
    Map<String, dynamic>? parameters,
  }) async {
    if (!_shouldLogCustomEvents) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;

    final sanitized = parameters == null ? null : _sanitize(parameters);
    _printFire(name, sanitized);

    unawaited(
      _safe(() async {
        await _fb.logEvent(name: name, parameters: sanitized);
        // Default flush behavior batches events; send now so Test Events
        // reflects the interaction immediately.
        await _fb.flush();
        _printFlushed(name);
      }),
    );
  }

  void _printFire(String name, Map<String, dynamic>? parameters) {
    debugPrint('[MetaEvents] FIRE event="$name" params=$parameters');
  }

  void _printFlushed(String name) {
    debugPrint('[MetaEvents] FLUSHED event="$name"');
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('[MetaEvents] log failed: $e\n$st');
    }
  }

  /// Meta only accepts String / num / bool parameter values.
  Map<String, dynamic> _sanitize(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((key, value) {
      if (value == null) return;
      if (value is String || value is num || value is bool) {
        out[key] = value;
      } else {
        out[key] = value.toString();
      }
    });
    return out;
  }
}
