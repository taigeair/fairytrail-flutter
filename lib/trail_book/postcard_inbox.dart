import 'dart:async';

import 'package:fairytrail/api/models/trail_book_models.dart';
import 'package:fairytrail/api/trail_book.dart';
import 'package:fairytrail/push/notification_router.dart';
import 'package:fairytrail/screens/trail_book/postcard_received_screen.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// RN AppContext postcard inbox: WS `new_postcard` + unread poll on open/resume.
abstract final class PostcardInbox {
  static bool _presenting = false;
  static DateTime? _lastPresentedAt;
  static int? _lastPresentedId;

  /// Deep-link / push ids waiting while another postcard is on screen.
  static final List<int> _queuedIds = <int>[];

  /// Debounce window matching RN (2s) for duplicate WS/unread events.
  static const _debounce = Duration(seconds: 2);

  static Future<void> presentItem(
    TrailBookItemDto item, {
    int unreadCount = 0,
    bool fromDeepLink = false,
  }) async {
    if (item.id <= 0 || !item.isPostcard) {
      debugPrint(
        '[PostcardInbox] skip present — invalid item id=${item.id} type=${item.type}',
      );
      return;
    }

    final now = DateTime.now();
    if (_presenting) {
      debugPrint(
        '[PostcardInbox] busy — queue id=${item.id} fromDeepLink=$fromDeepLink',
      );
      _enqueue(item.id);
      return;
    }
    // Deep links must reopen even if the same postcard was just shown (e.g.
    // unread blocker on login, then user taps the email again).
    if (!fromDeepLink &&
        _lastPresentedId == item.id &&
        _lastPresentedAt != null &&
        now.difference(_lastPresentedAt!) < _debounce) {
      debugPrint('[PostcardInbox] skip present — debounce id=${item.id}');
      return;
    }

    final nav = NotificationRouter.navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[PostcardInbox] navigator not ready — retry next frame');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          presentItem(
            item,
            unreadCount: unreadCount,
            fromDeepLink: fromDeepLink,
          ),
        );
      });
      return;
    }

    _presenting = true;
    _lastPresentedAt = now;
    _lastPresentedId = item.id;
    try {
      debugPrint(
        '[PostcardInbox] opening received screen id=${item.id} '
        'fromDeepLink=$fromDeepLink',
      );
      await PostcardReceivedScreen.open(
        nav.context,
        item: item,
        unreadCount: unreadCount,
      );
      debugPrint('[PostcardInbox] received screen closed id=${item.id}');
    } finally {
      _presenting = false;
      _drainQueue();
    }
  }

  /// WS / push / deep link payload: `{ postcardId: int }`.
  static Future<void> presentFromWs(
    dynamic data, {
    bool fromDeepLink = false,
  }) async {
    final id = _postcardIdFrom(data);
    debugPrint(
      '[PostcardInbox] presentFromWs id=$id fromDeepLink=$fromDeepLink raw=$data',
    );
    if (id == null) return;
    await presentById(id, fromDeepLink: fromDeepLink);
  }

  /// Fetch + show a postcard by id (mail deep link / push).
  static Future<void> presentById(
    int id, {
    bool fromDeepLink = false,
  }) async {
    if (id <= 0) return;
    try {
      final item = await fetchTrailBookItem(id);
      debugPrint(
        '[PostcardInbox] fetched id=${item.id} type=${item.type} '
        'fromDeepLink=$fromDeepLink',
      );
      await presentItem(item, fromDeepLink: fromDeepLink);
    } catch (e, st) {
      debugPrint('[PostcardInbox] fetch item $id failed: $e\n$st');
      final nav = NotificationRouter.navigatorKey.currentState;
      if (nav != null && fromDeepLink) {
        AppToast.show(
          nav.context,
          message: 'Could not open this postcard. Try Trail Book.',
        );
      }
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

  static void _enqueue(int id) {
    if (_queuedIds.contains(id)) return;
    _queuedIds.add(id);
  }

  static void _drainQueue() {
    if (_queuedIds.isEmpty || _presenting) return;
    final next = _queuedIds.removeAt(0);
    debugPrint('[PostcardInbox] draining queued id=$next');
    // Deep-link / follow-up opens should not be debounced away.
    unawaited(presentById(next, fromDeepLink: true));
  }

  static int? _postcardIdFrom(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final raw = map['postcardId'] ?? map['id'] ?? map['trailBookId'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }
}
