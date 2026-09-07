import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

Future<void> registerPushToken({
  required String token,
  String? from,
}) async {
  await HttpClient.instance.request(
    path: EndPoints.pushTokens,
    method: HttpMethod.post,
    requiresAuth: true,
    body: {
      'token': token,
      'from': ?from,
    },
  );
}

Future<void> deletePushToken({required String token}) async {
  await HttpClient.instance.request(
    path: EndPoints.pushTokens,
    method: HttpMethod.delete,
    requiresAuth: true,
    body: {'token': token},
  );
}

class UserNotificationConfig {
  const UserNotificationConfig({
    this.notificationsEnabled = false,
    this.messageNotificationsEnabled = false,
    this.meetupNotificationsEnabled = false,
    this.matchInCountryNotificationsEnabled = true,
  });

  final bool notificationsEnabled;
  final bool messageNotificationsEnabled;
  final bool meetupNotificationsEnabled;
  final bool matchInCountryNotificationsEnabled;

  factory UserNotificationConfig.fromJson(Map<String, dynamic> json) {
    return UserNotificationConfig(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      messageNotificationsEnabled:
          json['messageNotificationsEnabled'] as bool? ?? false,
      meetupNotificationsEnabled:
          json['meetupNotificationsEnabled'] as bool? ?? false,
      matchInCountryNotificationsEnabled:
          json['matchInCountryNotificationsEnabled'] as bool? ?? true,
    );
  }

  /// Preset derived from the three stored flags.
  String get type {
    final general = notificationsEnabled;
    final messages = messageNotificationsEnabled;
    final meetups = meetupNotificationsEnabled;
    if (!general && !messages && !meetups) return 'none';
    if (general && messages && meetups) return 'all';
    if (!general && messages && !meetups) return 'messages';
    if (!general && messages && meetups) return 'messages_meetups';
    if (!general && !messages && meetups) return 'meetups';
    // Legacy connect+messages without meetups (general cleared by API normalize).
    if (general && messages && !meetups) return 'messages';
    return 'none';
  }

  static String labelForType(String type) {
    return switch (type) {
      'all' => 'All',
      'messages' => 'Messages',
      'messages_meetups' => 'Messages & meetups',
      'meetups' => 'Meetups',
      _ => 'Off',
    };
  }
}

Future<UserNotificationConfig> fetchNotificationConfig() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.meConfig,
    method: HttpMethod.get,
    requiresAuth: true,
  );
  final data = response.data;
  if (data is! Map) {
    return const UserNotificationConfig();
  }
  final config = data['config'];
  if (config is! Map) return const UserNotificationConfig();
  return UserNotificationConfig.fromJson(Map<String, dynamic>.from(config));
}

Future<void> updateNotificationConfigType(String type) async {
  await updateNotificationConfig(type: type);
}

Future<void> updateNotificationConfig({
  String? type,
  bool? matchInCountryNotificationsEnabled,
}) async {
  final body = <String, dynamic>{};
  if (type != null) body['type'] = type;
  if (matchInCountryNotificationsEnabled != null) {
    body['matchInCountryNotificationsEnabled'] =
        matchInCountryNotificationsEnabled;
  }
  if (body.isEmpty) return;

  await HttpClient.instance.request(
    path: EndPoints.meConfig,
    method: HttpMethod.put,
    requiresAuth: true,
    body: body,
  );
}
