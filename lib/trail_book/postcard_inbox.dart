import 'package:fairytrail/api/models/trail_book_models.dart';
import 'package:fairytrail/api/trail_book.dart';
import 'package:fairytrail/push/notification_router.dart';
import 'package:fairytrail/screens/trail_book/postcard_received_screen.dart';
import 'package:flutter/material.dart';

/// RN AppContext postcard inbox: WS `new_postcard` + unread poll on open/resume.
abstract final class PostcardInbox {
  static bool _presenting = false;
  static DateTime? _lastPresentedAt;
  static int? _lastPresentedId;

  /// Debounce window matching RN (2s).
  static const _debounce = Duration(seconds: 2);

  static Future<void> presentItem(
    TrailBookItemDto item, {
    int unreadCount = 0,
  }) async {
    if (item.id <= 0 || !item.isPostcard) return;

    final now = DateTime.now();
    if (_presenting) return;
    if (_lastPresentedId == item.id &&
        _lastPresentedAt != null &&
        now.difference(_lastPresentedAt!) < _debounce) {
      return;
    }

    final nav = NotificationRouter.navigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        presentItem(item, unreadCount: unreadCount);
      });
      return;
    }

    _presenting = true;
    _lastPresentedAt = now;
    _lastPresentedId = item.id;
    try {
      await PostcardReceivedScreen.open(
        nav.context,
        item: item,
        unreadCount: unreadCount,
      );
    } finally {
      _presenting = false;
    }
  }

  /// WS payload: `{ postcardId: int }`.
  static Future<void> presentFromWs(dynamic data) async {
    final id = _postcardIdFrom(data);
    if (id == null) return;
    try {
      final item = await fetchTrailBookItem(id);
      await presentItem(item);
    } catch (e) {
      debugPrint('[PostcardInbox] fetch item $id failed: $e');
    }
  }

  /// RN `loadUnreadTrailBook` — catch postcards missed while disconnected.
  static Future<void> checkUnread() async {
    try {
      final unread = await fetchTrailBookUnread();
      debugPrint(
        '[PostcardInbox] unread postcards: ${unread.totalUnread}'
        '${unread.postcard != null ? ' (latest id=${unread.postcard!.id})' : ''}',
      );
      final item = unread.postcard;
      if (item == null || unread.totalUnread <= 0) return;
      await presentItem(item, unreadCount: unread.totalUnread);
    } catch (e) {
      debugPrint('[PostcardInbox] unread check failed: $e');
    }
  }

  static int? _postcardIdFrom(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final raw = map['postcardId'] ?? map['id'] ?? map['trailBookId'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }
}
