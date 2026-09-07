import 'dart:async';

import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/foundation.dart';

/// In-memory cache of `is_notification_prompted_<userId>` for instant checks.
///
/// Load once at app/auth bootstrap; connect/message only read [wasPrompted].
abstract final class NotificationPromptStore {
  static bool _prompted = false;
  static String? _userId;
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  /// Instant — use on connect / send. False until [loadForUser] runs.
  static bool get wasPrompted => _prompted;

  /// Call when session user is known (bootstrap / login / registration).
  static Future<void> loadForUser(String? userId) async {
    if (userId == null || userId.isEmpty) {
      _userId = null;
      _prompted = false;
      _loaded = true;
      return;
    }
    _userId = userId;
    _prompted = await LocalStorage.instance.isNotificationPrompted(userId);
    _loaded = true;
    debugPrint(
      '[Notifications] cache loaded user=$userId prompted=$_prompted',
    );
  }

  /// Sync mark + async persist. Safe to call from connect path.
  static void markPrompted({String? userId}) {
    final id = userId ?? _userId;
    _prompted = true;
    _loaded = true;
    if (id == null || id.isEmpty) return;
    _userId = id;
    unawaited(LocalStorage.instance.setNotificationPrompted(id));
  }

  static void clear() {
    _userId = null;
    _prompted = false;
    _loaded = false;
  }
}
