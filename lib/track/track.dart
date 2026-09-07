import 'package:fairytrail/config/app_version.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/utils/uuid.dart';
import 'package:flutter/foundation.dart';

bool _darkMode = false;
bool _findTrailTreasures = true;

/// Keeps the current appearance available to Mixpanel event/profile updates.
void setTrackedDarkMode(bool enabled) => _darkMode = enabled;

/// Keeps the local trail-treasure preference available to Mixpanel updates.
void setTrackedFindTrailTreasures(bool enabled) =>
    _findTrailTreasures = enabled;

/// Client-side Mixpanel tracking via `POST /api/v1/track` (same as RN `track()`).
///
/// The PHP API identifies the user and forwards events to Mixpanel — there is
/// no Mixpanel SDK in the mobile clients.
Future<void> track(
  String event, [
  Map<String, dynamic> attributes = const {},
]) async {
  try {
    final userAliasId = await getOrCreateUserAliasId();
    final isImpersonating = await LocalStorage.instance.isImpersonating();

    final attrs = <String, dynamic>{
      ...attributes,
      'userAliasId': userAliasId,
      'app_version': AppVersionInfo.version,
      'app_build': AppVersionInfo.build,
      'app_locale': PlatformDispatcher.instance.locale.toLanguageTag(),
      'client_source': 'flutter',
      'dark_mode': _darkMode,
      'find_trail_treasures': _findTrailTreasures,
    };
    if (isImpersonating) {
      attrs['impersonating'] = true;
    }

    debugPrint('[Mixpanel] $event $attrs');

    await HttpClient.instance.request(
      path: EndPoints.track,
      method: HttpMethod.post,
      body: {'event': event, 'attributes': attrs, 'logs': <String>[]},
    );
  } catch (e, st) {
    debugPrint('[Mixpanel] $event failed: $e\n$st');
  }
}

Future<String> getOrCreateUserAliasId() async {
  final existing = await LocalStorage.instance.getUserAliasId();
  if (existing != null && existing.isNotEmpty) return existing;

  final id = uuidV4();
  await LocalStorage.instance.setUserAliasId(id);
  return id;
}

Future<void> resetUserAliasId() => LocalStorage.instance.deleteUserAliasId();
