import 'package:fairytrail/utils/api/end_points.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Client Firebase Analytics (RN `basicFirebaseAnalytics`).
///
/// Requires Firebase Core to already be initialized (done by [PushService]).
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  /// `local` | `staging` | `production` from [EndPoints.baseUrl].
  static String get appEnv {
    final url = EndPoints.baseUrl;
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      return 'local';
    }
    if (url.contains('staging')) return 'staging';
    return 'production';
  }

  Future<void> initialize() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
      debugPrint('[Analytics] initialized');
    } catch (e) {
      debugPrint('[Analytics] init failed: $e');
    }
  }

  Future<void> logEvent(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      debugPrint('[Analytics] event $name');
    } catch (e) {
      debugPrint('[Analytics] event failed ($name): $e');
    }
  }

  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('[Analytics] setUserId failed: $e');
    }
  }

  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('[Analytics] setUserProperty failed ($name): $e');
    }
  }

  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenName,
      );
    } catch (e) {
      debugPrint('[Analytics] logScreenView failed ($screenName): $e');
    }
  }

  /// Identify after login / session restore (RN main/index.tsx).
  Future<void> identify(String userId) async {
    if (userId.isEmpty) return;
    await setUserId(userId);
    await setUserProperty(name: 'app_env', value: appEnv);
  }
}
