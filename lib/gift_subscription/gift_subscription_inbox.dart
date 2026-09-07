import 'package:fairytrail/api/gift_subscription.dart';
import 'package:fairytrail/push/notification_router.dart';
import 'package:fairytrail/screens/profile/gift_subscription_received_screen.dart';
import 'package:flutter/material.dart';

/// Presents pending / deep-linked gifted subscriptions like [PostcardInbox].
abstract final class GiftSubscriptionInbox {
  static bool _presenting = false;
  static DateTime? _lastPresentedAt;
  static String? _lastPresentedId;

  static const _debounce = Duration(seconds: 2);

  static bool _canPresent(GiftSubscriptionDto gift) {
    return gift.id.isNotEmpty &&
        (gift.status == 'paid' ||
            gift.status == 'accepted' ||
            gift.status == 'declined');
  }

  static Future<void> presentGift(GiftSubscriptionDto gift) async {
    debugPrint(
      '[GiftSubscriptionInbox] presentGift id=${gift.id} status=${gift.status} '
      'sender=${gift.senderProfileId}',
    );
    if (!_canPresent(gift)) {
      debugPrint(
        '[GiftSubscriptionInbox] skip present — unsupported status=${gift.status}',
      );
      return;
    }

    final now = DateTime.now();
    if (_presenting) {
      debugPrint('[GiftSubscriptionInbox] skip present — already presenting');
      return;
    }
    if (_lastPresentedId == gift.id &&
        _lastPresentedAt != null &&
        now.difference(_lastPresentedAt!) < _debounce) {
      debugPrint('[GiftSubscriptionInbox] skip present — debounce');
      return;
    }

    final nav = NotificationRouter.navigatorKey.currentState;
    if (nav == null) {
      debugPrint(
        '[GiftSubscriptionInbox] navigator not ready — retry next frame',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        presentGift(gift);
      });
      return;
    }

    _presenting = true;
    _lastPresentedAt = now;
    _lastPresentedId = gift.id;
    try {
      debugPrint('[GiftSubscriptionInbox] opening received screen');
      await GiftSubscriptionReceivedScreen.open(nav.context, gift: gift);
      debugPrint('[GiftSubscriptionInbox] received screen closed');
    } finally {
      _presenting = false;
    }
  }

  static Future<void> presentByIdOrToken(String idOrToken) async {
    debugPrint('[GiftSubscriptionInbox] presentByIdOrToken=$idOrToken');
    if (idOrToken.isEmpty) {
      debugPrint('[GiftSubscriptionInbox] empty id/token');
      return;
    }
    try {
      final gift = await fetchGiftSubscription(idOrToken);
      debugPrint(
        '[GiftSubscriptionInbox] fetched gift id=${gift.id} status=${gift.status}',
      );
      await presentGift(gift);
    } catch (e, st) {
      debugPrint('[GiftSubscriptionInbox] fetch $idOrToken failed: $e\n$st');
    }
  }

  static Future<void> checkPending() async {
    debugPrint('[GiftSubscriptionInbox] checkPending start');
    try {
      final pending = await fetchPendingGiftSubscriptions();
      debugPrint('[GiftSubscriptionInbox] pending count=${pending.length}');
      if (pending.isEmpty) return;
      await presentGift(pending.first);
    } catch (e, st) {
      debugPrint('[GiftSubscriptionInbox] pending check failed: $e\n$st');
    }
  }
}
