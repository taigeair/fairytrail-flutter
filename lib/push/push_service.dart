import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:fairytrail/api/push_tokens.dart' as push_api;
import 'package:fairytrail/config/firebase_options.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Pretty-print the full FCM [RemoteMessage] for debugging.
void dumpPushNotification(RemoteMessage message, {String source = 'unknown'}) {
  final n = message.notification;
  final dump = <String, dynamic>{
    'source': source,
    'messageId': message.messageId,
    'from': message.from,
    'sentTime': message.sentTime?.toIso8601String(),
    'ttl': message.ttl,
    'collapseKey': message.collapseKey,
    'category': message.category,
    'contentAvailable': message.contentAvailable,
    'mutableContent': message.mutableContent,
    'messageType': message.messageType,
    'threadId': message.threadId,
    'notification': n == null
        ? null
        : {
            'title': n.title,
            'body': n.body,
            'titleLocKey': n.titleLocKey,
            'bodyLocKey': n.bodyLocKey,
            'titleLocArgs': n.titleLocArgs,
            'bodyLocArgs': n.bodyLocArgs,
            'android': n.android == null
                ? null
                : {
                    'channelId': n.android!.channelId,
                    'clickAction': n.android!.clickAction,
                    'count': n.android!.count,
                    'imageUrl': n.android!.imageUrl,
                    'link': n.android!.link?.toString(),
                    'priority': n.android!.priority.name,
                    'smallIcon': n.android!.smallIcon,
                    'sound': n.android!.sound,
                    'ticker': n.android!.ticker,
                    'tag': n.android!.tag,
                    'visibility': n.android!.visibility.name,
                  },
            'apple': n.apple == null
                ? null
                : {
                    'subtitle': n.apple!.subtitle,
                    'badge': n.apple!.badge,
                    'sound': n.apple!.sound?.name,
                    'imageUrl': n.apple!.imageUrl,
                  },
          },
    'data': message.data,
  };
  debugPrint(
    '[Push] FULL notification ($source):\n${const JsonEncoder.withIndent('  ').convert(dump)}',
  );
}

/// Top-level background handler (must be a global function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in the background isolate.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  dumpPushNotification(message, source: 'background');
}

typedef PushOpenHandler = void Function(Map<String, dynamic> data);

/// Push permissions, FCM token sync, local display, and deep-link opens.
///
/// Mirrors RN `src/push.ts` + `setupNotificationHandler`, but uses FCM because
/// native Flutter cannot obtain Expo `ExponentPushToken`s. Backend still accepts
/// any token via `POST /api/v1/push-tokens`.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _signupReminders = <(int, Duration)>[
    (5001, Duration(minutes: 10)),
    (5002, Duration(hours: 1)),
    (5003, Duration(hours: 24)),
    (5004, Duration(hours: 48)),
    (5005, Duration(hours: 72)),
  ];
  static const _signupReminderTitle = 'Finish setting up';
  static const _signupReminderBody =
      'Find friends who love adventure! Sign up takes 1 minute.';

  /// Fixed IDs so reschedules replace rather than stack.
  static const _exploreAvailableNotificationId = 5101;
  static const _inactiveReminderNotificationId = 5102;

  static const _exploreAvailableTitle = 'Ready to explore?';
  static const _exploreAvailableBody = 'Tap to check out new profiles.';

  static const _defaultInactiveDurationMinutes = 4320; // 3 days
  static const _defaultInactiveTitle =
      '5,000+ people joined since your last visit!';
  static const _defaultInactiveBody = 'Tap to check out new profiles.';

  /// Set only after [Firebase.initializeApp] succeeds — never in the constructor.
  FirebaseMessaging? _messaging;
  final _local = FlutterLocalNotificationsPlugin();
  final _appLinks = AppLinks();

  bool _ready = false;
  bool _localReady = false;
  bool _schedulingInactiveReminder = false;
  String? _token;
  PushOpenHandler? _onNotificationOpen;
  Map<String, dynamic>? _pendingOpen;
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<String>? _tokenRefreshSub;

  String? get token => _token;
  bool get isReady => _ready;

  PushOpenHandler? get onNotificationOpen => _onNotificationOpen;

  set onNotificationOpen(PushOpenHandler? handler) {
    _onNotificationOpen = handler;
    final pending = _pendingOpen;
    if (handler != null && pending != null) {
      _pendingOpen = null;
      handler(pending);
    }
  }

  Future<void> initialize({PushOpenHandler? onOpen}) async {
    if (_ready) {
      if (onOpen != null) onNotificationOpen = onOpen;
      return;
    }
    if (onOpen != null) onNotificationOpen = onOpen;

    var firebaseOk = false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _messaging = FirebaseMessaging.instance;
      firebaseOk = true;
    } catch (e) {
      debugPrint('[Push] Firebase.initializeApp failed: $e');
      // Continue — deep links still work without Firebase.
    }

    // Local scheduling works without FCM (explore-limit + inactive reminders).
    await _ensureLocalNotifications();

    if (firebaseOk) {
      final messaging = _messaging!;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

      // Do not request OS permission here — soft prompt is deferred to first
      // Connect / first message (EnableNotificationsScreen.openIfNeeded).

      // Cold start from notification tap
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        dumpPushNotification(initial, source: 'cold_start');
        _dispatchOpen(initial.data);
      }
    }

    // Cold start from a scheduled local notification tap.
    try {
      final launch = await _local.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null) {
        final raw = response.payload;
        if (raw != null && raw.isNotEmpty) {
          try {
            final data = jsonDecode(raw);
            if (data is Map) {
              _dispatchOpen(Map<String, dynamic>.from(data));
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[Push] local launch details error: $e');
    }

    await _listenDeepLinks();
    _ready = true;
  }

  Future<void> _ensureLocalNotifications() async {
    if (_localReady) return;
    await _initLocalNotifications();
    _localReady = true;
  }

  Future<void> _initLocalNotifications() async {
    await _configureLocalTimezone();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
      defaultPresentSound: true,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final raw = response.payload;
        if (raw == null || raw.isEmpty) return;
        try {
          final data = jsonDecode(raw);
          if (data is Map) {
            _dispatchOpen(Map<String, dynamic>.from(data));
          }
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'fairytrail_default',
              'Fairytrail',
              description: 'Messages and connections',
              importance: Importance.high,
            ),
          );
    }
  }

  /// Android 13+ notification permission on the welcome screen only.
  /// iOS signup reminders use provisional authorization (no system dialog).
  Future<void> requestWelcomeNotificationPermission() async {
    if (!Platform.isAndroid) return;

    final storage = LocalStorage.instance;
    if (await storage.getHasRequestedSignupNotificationPermission()) return;

    await _ensureLocalNotifications();
    try {
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission() ?? false;
      await storage.setHasRequestedSignupNotificationPermission();
      if (!granted) {
        debugPrint('[Push] Android welcome notification permission denied');
        return;
      }
    } catch (e) {
      debugPrint('[Push] Android welcome notification permission failed: $e');
    }
  }

  Future<void> _configureLocalTimezone() async {
    tz.initializeTimeZones();
    try {
      var name = (await FlutterTimezone.getLocalTimezone()).identifier;
      name = switch (name) {
        'America/Buenos_Aires' => 'America/Argentina/Buenos_Aires',
        'Asia/Calcutta' => 'Asia/Kolkata',
        _ => name,
      };
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('[Push] timezone setup failed: $e');
    }
  }

  /// OS permission for visible local banners.
  Future<bool> _requestLocalNotificationPermission({
    bool provisional = false,
  }) async {
    if (Platform.isAndroid) {
      final granted = await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? true;
    }
    if (Platform.isIOS) {
      final granted = await _local
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(
            alert: true,
            badge: !provisional,
            sound: !provisional,
            provisional: provisional,
          );
      return granted ?? false;
    }
    return true;
  }

  NotificationDetails get _defaultNotificationDetails =>
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fairytrail_default',
          'Fairytrail',
          channelDescription: 'Messages and connections',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      );

  NotificationDetails get _quietSignupNotificationDetails =>
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fairytrail_default',
          'Fairytrail',
          channelDescription: 'Messages and connections',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
          presentBanner: false,
          presentList: true,
          interruptionLevel: InterruptionLevel.passive,
        ),
      );

  Future<void> _scheduleLocal({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    required String payload,
    NotificationDetails? details,
  }) async {
    if (delay.inSeconds < 60) return;

    await _local.cancel(id: id);
    await _local.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: details ?? _defaultNotificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// RN `reachedLimitSchedulePushNotification` — next calendar day at 08:00.
  Future<void> scheduleExploreAvailableNotification() async {
    await _ensureLocalNotifications();

    final storage = LocalStorage.instance;
    if (await storage.hasExploreAvailableNotification()) return;

    try {
      // Quiet provisional access is not a full user grant. Ask for full
      // permission here only when it has not already been granted.
      final permitted = await hasExplicitPermission() ||
          await _requestLocalNotificationPermission();
      if (!permitted) {
        debugPrint('[Push] explore-available skipped — permission denied');
        return;
      }

      final now = DateTime.now();
      final delay = DateTime(
        now.year,
        now.month,
        now.day + 1,
        8,
      ).difference(now);

      await _scheduleLocal(
        id: _exploreAvailableNotificationId,
        title: _exploreAvailableTitle,
        body: _exploreAvailableBody,
        delay: delay,
        payload: '{"type":"explore_available"}',
      );

      await storage.setExploreAvailableNotification(
        '$_exploreAvailableNotificationId',
      );
      debugPrint(
        '[Push] explore-available reminder scheduled for tomorrow 08:00',
      );
    } catch (e) {
      debugPrint('[Push] failed to schedule explore-available reminder: $e');
    }
  }

  /// RN `scheduleLocalPushNotification` — inactive-user re-engagement.
  ///
  /// [durationMinutes] matches remote config (`4320` = 3 days).
  Future<void> scheduleInactiveReminder({
    int durationMinutes = _defaultInactiveDurationMinutes,
    String title = _defaultInactiveTitle,
    String body = _defaultInactiveBody,
  }) async {
    if (_schedulingInactiveReminder) return;
    _schedulingInactiveReminder = true;

    try {
      await _ensureLocalNotifications();
      final storage = LocalStorage.instance;
      if (await storage.hasLocalPushNotification()) return;

      final delay = Duration(minutes: durationMinutes);

      await _scheduleLocal(
        id: _inactiveReminderNotificationId,
        title: title,
        body: body,
        delay: delay,
        payload: jsonEncode({
          'type': 'local_reminder',
          'isTesting': kDebugMode,
          'delayInMinutes': durationMinutes,
        }),
      );

      await storage.setLocalPushNotification(
        '$_inactiveReminderNotificationId',
      );
      debugPrint(
        '[Push] inactive reminder scheduled in $durationMinutes min',
      );
    } catch (e) {
      debugPrint('[Push] failed to schedule inactive reminder: $e');
    } finally {
      _schedulingInactiveReminder = false;
    }
  }

  /// RN `clearScheduledNotifications` — cancels the inactive-user reminder only.
  Future<void> clearInactiveReminder() async {
    try {
      _schedulingInactiveReminder = false;
      await LocalStorage.instance.clearLocalPushNotification();
      await _ensureLocalNotifications();
      await _local.cancel(id: _inactiveReminderNotificationId);
      debugPrint('[Push] inactive reminder cleared');
    } catch (e) {
      debugPrint('[Push] failed to clear inactive reminder: $e');
    }
  }

  /// Schedule the legacy RN reminder while signup is unfinished.
  ///
  /// Fixed IDs make repeated app opens replace the existing sequence rather
  /// than stacking duplicate notifications.
  Future<void> scheduleSignupReminder() async {
    await _ensureLocalNotifications();

    final step = await LocalStorage.instance.getSignupStep();
    if (step == null || step < 1) {
      await cancelSignupReminder();
      debugPrint('[Push] signup reminder skipped — signup not started');
      return;
    }

    try {
      if (Platform.isIOS) {
        final permitted = await _requestLocalNotificationPermission(
          provisional: true,
        );
        if (!permitted) {
          debugPrint('[Push] signup reminder authorization unavailable');
          return;
        }
      }

      for (final (id, delay) in _signupReminders) {
        await _scheduleLocal(
          id: id,
          title: _signupReminderTitle,
          body: _signupReminderBody,
          delay: delay,
          payload: '{"type":"local_reminder"}',
          details: _quietSignupNotificationDetails,
        );
      }
      debugPrint(
        '[Push] signup reminders scheduled for 10m, 1h, 24h, 48h, and 72h',
      );
    } catch (e) {
      debugPrint('[Push] failed to schedule signup reminder: $e');
    }
  }

  Future<void> cancelSignupReminder() async {
    try {
      for (final (id, _) in _signupReminders) {
        await _local.cancel(id: id);
      }
      debugPrint('[Push] signup reminders cancelled');
    } catch (e) {
      debugPrint('[Push] failed to cancel signup reminder: $e');
    }
  }

  Future<void> _listenDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
    } catch (e) {
      debugPrint('[Push] initial deep link error: $e');
    }
    _linkSub?.cancel();
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (e) => debugPrint('[Push] deep link stream error: $e'),
    );
  }

  /// Request OS permission and register FCM token with the API (RN enable flow).
  ///
  /// If fully authorized, skips the system dialog and just uploads the token.
  /// Provisional access still requires an explicit permission request.
  Future<String?> enableAndRegister({String from = 'profile'}) async {
    final messaging = _messaging;
    if (messaging == null) {
      debugPrint('[Push] enable skipped — Firebase not ready');
      return null;
    }

    var settings = await messaging.getNotificationSettings();
    var granted =
        settings.authorizationStatus == AuthorizationStatus.authorized;

    if (!granted) {
      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      granted =
          settings.authorizationStatus == AuthorizationStatus.authorized;
    } else {
      debugPrint(
        '[Push] enableAndRegister — permission already ${settings.authorizationStatus.name}',
      );
    }

    if (!granted) {
      debugPrint('[Push] permission denied: ${settings.authorizationStatus}');
      return null;
    }

    if (Platform.isIOS) {
      // APNs token must be available before FCM token on iOS.
      await messaging.getAPNSToken();
    }

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[Push] no FCM token');
      return null;
    }

    await _persistAndUpload(token, from: from);
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = messaging.onTokenRefresh.listen((t) {
      _persistAndUpload(t, from: 'notifications');
    });
    return token;
  }

  /// Soft refresh — only if permission already granted (RN getRefresh…).
  Future<String?> refreshIfPermitted() async {
    final messaging = _messaging;
    if (messaging == null) return null;

    final settings = await messaging.getNotificationSettings();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return null;

    if (Platform.isIOS) {
      await messaging.getAPNSToken();
    }
    final token = await messaging.getToken();
    if (token == null) return null;
    await _persistAndUpload(token, from: 'notifications');
    return token;
  }

  /// User-facing permission checks require full authorization.
  Future<bool> hasPermission() => hasExplicitPermission();

  /// Explicit user grant only — provisional (quiet signup reminders) does not count.
  Future<bool> hasExplicitPermission() async {
    final messaging = _messaging;
    if (messaging == null) return false;
    final settings = await messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<void> _persistAndUpload(String token, {required String from}) async {
    _token = token;
    await LocalStorage.instance.setPushToken(token);
    debugPrint('[Push] FULL FCM token (copy for curl):\n$token');
    try {
      await push_api.registerPushToken(token: token, from: from);
      debugPrint(
        '[Push] token registered with API (from=$from, len=${token.length})',
      );
    } catch (e) {
      debugPrint('[Push] register token failed: $e');
    }
  }

  /// Call on logout (RN deletes server token then local).
  Future<void> unregister() async {
    final token = _token ?? await LocalStorage.instance.getPushToken();
    if (token != null && token.isNotEmpty) {
      try {
        await push_api.deletePushToken(token: token);
      } catch (e) {
        debugPrint('[Push] delete token failed: $e');
      }
    }
    try {
      await _messaging?.deleteToken();
    } catch (_) {}
    await LocalStorage.instance.deletePushToken();
    _token = null;
  }

  Future<void> setBadge(int count) async {
    final n = count.clamp(0, 99);
    try {
      await _local
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(badge: true);
    } catch (_) {}
    // flutter_local_notifications badge via iOS plugin / Android launcher
    try {
      await _messaging?.setAutoInitEnabled(true);
    } catch (_) {}
    // Best-effort: iOS badge via local notification plugin channel
    debugPrint('[Push] badge -> $n');
  }

  void _onForegroundMessage(RemoteMessage message) {
    dumpPushNotification(message, source: 'foreground');

    // iOS already presents the system banner when a `notification` payload is
    // present (see setForegroundNotificationPresentationOptions). Showing a
    // local notification too causes a duplicate banner.
    if (Platform.isIOS && message.notification != null) {
      return;
    }

    final title =
        message.notification?.title ??
        (message.data['title'] as String?) ??
        'Fairytrail';
    final body =
        message.notification?.body ?? (message.data['body'] as String?) ?? '';
    _local.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: _defaultNotificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    dumpPushNotification(message, source: 'opened');
    _dispatchOpen(message.data);
  }

  void _handleUri(Uri uri) {
    debugPrint('[Push] deep link: $uri');
    debugPrint(
      '[Push] deep link parts scheme=${uri.scheme} host=${uri.host} '
      'path=${uri.path} query=${uri.query}',
    );
    final data = <String, dynamic>{'deepLink': uri.toString()};

    // fairytrail://messages  |  fairytrail://main/messages
    // fairytrail://messages?profileId=123
    // https://spring.fairytrail.app/main/messages ...
    // https://spring.fairytrail.app/dl/password-reset/{token}
    // fairytrail://dl/gift-subscription/{token}
    final path = uri.path.isEmpty
        ? (uri.host.isEmpty ? '' : '/${uri.host}${uri.path}')
        : (uri.host.isNotEmpty && uri.scheme != 'http' && uri.scheme != 'https'
              ? '/${uri.host}${uri.path}'
              : uri.path);
    final normalized = path.toLowerCase();
    debugPrint('[Push] deep link normalized path=$path');

    final resetMatch = RegExp(
      r'/dl/password-reset/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (resetMatch != null) {
      data['type'] = 'password_reset';
      data['token'] = Uri.decodeComponent(resetMatch.group(1)!);
      debugPrint('[Push] deep link → password_reset');
      _dispatchOpen(data);
      return;
    }

    final giftMatch = RegExp(
      r'(?:/dl)?/gift-subscription/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (giftMatch != null) {
      data['type'] = 'gift_subscription';
      data['giftId'] = Uri.decodeComponent(giftMatch.group(1)!);
      debugPrint('[Push] deep link → gift_subscription giftId=${data['giftId']}');
      _dispatchOpen(data);
      return;
    }

    final impersonateMatch = RegExp(
      r'/dl/impersonate/([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(path);
    if (impersonateMatch != null) {
      data['type'] = 'impersonate';
      data['apiToken'] = Uri.decodeComponent(impersonateMatch.group(1)!);
      debugPrint('[Push] deep link → impersonate');
      _dispatchOpen(data);
      return;
    }

    // fairytrail://activity/{id}
    // https://www.fairytrail.app/bucketlist/?id={id} (if ever associated)
    // https://spring.fairytrail.app/dl/activity/{id}
    final activityPathMatch = RegExp(
      r'(?:/dl)?/activity(?:/([^/?#]+))?/?$',
      caseSensitive: false,
    ).firstMatch(path);
    final activityQueryId =
        uri.queryParameters['id'] ?? uri.queryParameters['activityId'];
    final activityIdRaw = activityPathMatch?.group(1) ??
        (normalized.contains('bucketlist') ? activityQueryId : null) ??
        (uri.host.toLowerCase() == 'activity' && uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : null);
    if (activityIdRaw != null && activityIdRaw.isNotEmpty) {
      data['type'] = 'activity';
      data['activityId'] = Uri.decodeComponent(activityIdRaw);
      debugPrint('[Push] deep link → activity activityId=${data['activityId']}');
      _dispatchOpen(data);
      return;
    }

    if (normalized.contains('message') || uri.host == 'messages') {
      data['type'] = 'chat_message';
    } else if (normalized.contains('connect')) {
      data['type'] = 'connect';
    } else if (normalized.contains('match')) {
      data['type'] = 'match';
    }

    final profileId =
        uri.queryParameters['profileId'] ?? uri.queryParameters['match'];
    if (profileId != null) data['profileId'] = profileId;

    debugPrint('[Push] deep link → generic type=${data['type']}');
    _dispatchOpen(data);
  }

  void _dispatchOpen(Map<String, dynamic> data) {
    debugPrint('[Push] open -> $data');
    // RN clears the inactive reminder when any notification is tapped.
    unawaited(clearInactiveReminder());
    final handler = _onNotificationOpen;
    if (handler != null) {
      handler(data);
    } else {
      _pendingOpen = data;
    }
  }

  /// Re-queue an open for the next handler (e.g. FairytrailApp defers chat
  /// opens until MainShell is ready with MessagesController).
  void deferOpen(Map<String, dynamic> data) {
    _pendingOpen = data;
  }

  void dispose() {
    _linkSub?.cancel();
    _tokenRefreshSub?.cancel();
  }
}
