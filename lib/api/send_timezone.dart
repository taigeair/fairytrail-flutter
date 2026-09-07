import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

const _tzOverride = {
  'America/Buenos_Aires': 'America/Argentina/Buenos_Aires',
  'Asia/Calcutta': 'Asia/Kolkata',
};

/// Mirrors RN `sendTimezone` — sets user timezone (Timezone2) and records IP (IP1).
Future<void> sendTimezone({String? pushToken}) async {
  try {
    var timezone = (await FlutterTimezone.getLocalTimezone()).identifier;
    timezone = _tzOverride[timezone] ?? timezone;

    await HttpClient.instance.request(
      path: EndPoints.timezone,
      method: HttpMethod.post,
      requiresAuth: true,
      body: {
        'timezone': timezone,
        'pushToken': pushToken,
      },
    );
  } catch (e) {
    debugPrint('[sendTimezone] failed: $e');
  }
}
