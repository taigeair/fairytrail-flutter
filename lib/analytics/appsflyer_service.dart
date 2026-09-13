import 'dart:async';
import 'dart:io' show Platform;

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// AppsFlyer attribution + in-app events.
///
/// Registration, subscriptions, and `af_purchase` (with product details).
/// Initialized after ATT so the first Launch can include the IDFA.
class AppsFlyerService {
  AppsFlyerService._();

  static final AppsFlyerService instance = AppsFlyerService._();

  /// AppsFlyer dashboard Dev Key (shared by iOS and Android).
  static const devKey = 'MrYwZS2MN2MsQ6w7je9Yh6';

  /// Apple App Store ID (iOS only; not sent to the Android SDK).
  static const iosAppId = '1442011999';

  final AppsFlyerSdk _sdk = AppsFlyerSdk.instance;

  bool _initialized = false;
  String? _pendingCustomerUserId;

  bool get isInitialized => _initialized;

  /// Called from [TrackingDependentServices] after ATT is resolved.
  Future<void> initialize({required bool trackingAllowed}) async {
    if (_initialized || kIsWeb) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;

    try {
      if (kDebugMode) {
        await _sdk.enableDebug(true);
      }

      await _sdk.init(devKey: devKey, appId: Platform.isIOS ? iosAppId : null);

      await _sdk.setDisableAdvertisingIdentifiers(!trackingAllowed);

      final customerUserId = _pendingCustomerUserId;
      if (customerUserId != null && customerUserId.isNotEmpty) {
        await _sdk.setCustomerUserId(customerUserId);
      }

      await _sdk.registerSessionReadyListener(() {
        unawaited(_startSession());
      });

      _initialized = true;
      debugPrint('[AppsFlyer] initialized; trackingAllowed=$trackingAllowed');
    } catch (e, st) {
      debugPrint('[AppsFlyer] initialize failed: $e\n$st');
    }
  }

  Future<void> _startSession() async {
    try {
      await _sdk.start();
      debugPrint('[AppsFlyer] session started');
    } on AppsFlyerException catch (e) {
      debugPrint('[AppsFlyer] start failed: $e');
    }
  }

  /// Identify after login / session restore. Safe before [initialize]:
  /// the ID is applied to the first Launch when the SDK starts.
  Future<void> identify(String userId) async {
    if (userId.isEmpty) return;
    _pendingCustomerUserId = userId;
    if (!_initialized) return;
    try {
      await _sdk.setCustomerUserId(userId);
    } catch (e) {
      debugPrint('[AppsFlyer] setCustomerUserId failed: $e');
    }
  }

  bool get _shouldLog =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid) && _initialized;

  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    if (!_shouldLog || name.isEmpty) return;
    final values = parameters == null ? null : sanitize(parameters);
    debugPrint('[AppsFlyer] FIRE event="$name" params=$values');
    unawaited(
      _safe(() async {
        await _sdk.logEvent(name, eventValues: values);
      }),
    );
  }

  Future<void> logRegistrationCompleted({
    required String registrationMethod,
    required String profileType,
    required String userId,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_shouldLog) return;

    final platform = Platform.isIOS ? 'ios' : 'android';
    final params = sanitize({
      'af_registration_method': registrationMethod,
      'registration_method': registrationMethod,
      'registration_source': 'app',
      'registration_platform': platform,
      'profile_type': profileType,
      'user_id': userId,
      if (additionalData != null) 'additional_data': additionalData.toString(),
    });

    debugPrint(
      '[AppsFlyer] FIRE event="af_complete_registration" params=$params',
    );
    unawaited(
      _safe(() async {
        await _sdk.logEvent('af_complete_registration', eventValues: params);
      }),
    );
  }

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
    if (!_shouldLog) return;

    final now = DateTime.now().toUtc();
    final locale = PlatformDispatcher.instance.locale;
    final platform = Platform.isIOS ? 'ios' : 'android';
    final orderId = (transactionId != null && transactionId.isNotEmpty)
        ? transactionId
        : 'trial_${now.millisecondsSinceEpoch}';

    final params = sanitize({
      'af_revenue': price,
      'af_currency': currency,
      'af_content_id': productId,
      'af_content_type': 'subscription',
      'af_order_id': orderId,
      'price': price,
      'currency': currency,
      'price_string': priceString,
      'country': locale.countryCode ?? '',
      'product_id': productId,
      if (productTitle != null && productTitle.isNotEmpty)
        'product_title': productTitle,
      if (subscriptionPeriod != null && subscriptionPeriod.isNotEmpty)
        'subscription_period': subscriptionPeriod,
      'transaction_id': orderId,
      'platform': platform,
      'tier': tier,
      'duration': duration,
      'duration_type': durationType,
      'trial_days': ?trialDays,
      if (from != null && from.isNotEmpty) 'from': from,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'event_name': 'started_free_trial',
    });

    debugPrint('[AppsFlyer] FIRE event="af_start_trial" params=$params');
    unawaited(
      _safe(() async {
        await _sdk.logEvent('af_start_trial', eventValues: params);
        await _sdk.logEvent('started_free_trial', eventValues: params);
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
    if (!_shouldLog) return;

    final locale = PlatformDispatcher.instance.locale;
    final platform = Platform.isIOS ? 'ios' : 'android';

    final params = sanitize({
      'af_revenue': amount,
      'af_currency': currency,
      'af_content_id': productId,
      'af_content_type': contentType,
      if (transactionId != null && transactionId.isNotEmpty)
        'af_order_id': transactionId,
      'price': amount,
      'currency': currency,
      'price_string': priceString,
      'country': locale.countryCode ?? '',
      'product_id': productId,
      if (productTitle != null && productTitle.isNotEmpty)
        'product_title': productTitle,
      if (subscriptionPeriod != null && subscriptionPeriod.isNotEmpty)
        'subscription_period': subscriptionPeriod,
      'content_type': contentType,
      if (transactionId != null && transactionId.isNotEmpty)
        'transaction_id': transactionId,
      if (purchaseDate != null && purchaseDate.isNotEmpty)
        'store_purchase_date': purchaseDate,
      'platform': platform,
      'payment_method': Platform.isIOS ? 'apple_pay' : 'google_pay',
      if (from != null && from.isNotEmpty) 'from': from,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'event_name': customEventName,
      ...?extra,
    });

    debugPrint('[AppsFlyer] FIRE event="af_purchase" params=$params');
    unawaited(
      _safe(() async {
        await _sdk.logEvent('af_purchase', eventValues: params);
        if (alsoLogSubscribe &&
            customEventName != 'purchased_new_subscription') {
          await _sdk.logEvent(customEventName, eventValues: params);
        }
      }),
    );
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('[AppsFlyer] log failed: $e\n$st');
    }
  }

  /// AppsFlyer accepts String / num / bool parameter values.
  @visibleForTesting
  static Map<String, dynamic> sanitize(Map<String, dynamic> raw) {
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
