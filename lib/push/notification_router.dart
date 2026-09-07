import 'dart:async';
import 'dart:convert';

import 'package:fairytrail/api/activities.dart' as activities_api;
import 'package:fairytrail/api/chat.dart' as chat_api;
import 'package:fairytrail/api/meetups.dart' as meetup_api;
import 'package:fairytrail/api/models/chat_models.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/explore/photo_issue_sheet.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/messages/incoming_connects_controller.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/auth/reset_password_screen.dart';
import 'package:fairytrail/screens/bucket_list/activity_details_screen.dart';
import 'package:fairytrail/screens/explore/connected_screen.dart';
import 'package:fairytrail/screens/meetups/meetup_chat_screen.dart';
import 'package:fairytrail/screens/meetups/meetup_detail_screen.dart';
import 'package:fairytrail/screens/messages/activity_chat_info_screen.dart';
import 'package:fairytrail/screens/messages/activity_chat_screen.dart';
import 'package:fairytrail/screens/messages/match_chat_screen.dart';
import 'package:fairytrail/screens/messages/reveal_premium_notice_screen.dart';
import 'package:fairytrail/screens/messages/reveal_screen.dart';
import 'package:fairytrail/screens/profile/profile_view_screen.dart';
import 'package:fairytrail/screens/shell/floating_bottom_nav.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/screens/trail_book/trail_book_nav.dart';
import 'package:fairytrail/screens/verification/verification_screen.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/trail_book/postcard_inbox.dart';
import 'package:fairytrail/gift_subscription/gift_subscription_inbox.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Routes notification / deep-link payloads into the app (RN parity).
///
/// Payload shapes from API:
/// - `{ type: 'chat_message'|'match'|'match_in_country'|'new_profile', profileId?: int }` → chat
/// - `{ type: 'connect', profileId?: int }` → Reveal notice (free) / profile (paid)
/// - `{ type: 'activity_saved', activityId: int }` → Bucket List → activity → Saved list
/// - `{ type: 'activity', activityId: int }` → Explore → activity info (share / web Join)
/// - `{ type: 'meetup_joined'|'meetup_nearby', meetupId: int }` → Meetups → detail/chat
/// - `{ type: 'password_reset', token: string }`
/// - `{ type: 'impersonate', apiToken: string }`
/// - `{ type: 'postcard'|'new_postcard', postcardId?: int }`
/// - deep links: `fairytrail://messages?profileId=…`, `fairytrail://activity/{id}`
class NotificationRouter {
  NotificationRouter._();

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Replace the root navigator key (call before remounting [MaterialApp]).
  static void remountNavigator() {
    navigatorKey = GlobalKey<NavigatorState>();
  }

  static void handle(
    BuildContext? context, {
    required Map<String, dynamic> data,
    MessagesController? messages,
    ShellChromeController? chrome,
    AuthController? auth,
    IncomingConnectsController? incoming,
  }) {
    final type = data['type']?.toString();

    if (type == 'password_reset') {
      final token = data['token']?.toString();
      if (token != null && token.isNotEmpty) {
        openPasswordReset(token);
      }
      return;
    }

    if (type == 'impersonate') {
      final token = data['apiToken']?.toString();
      if (token != null && token.isNotEmpty) {
        (auth ??
                (context != null && context.mounted
                    ? AuthScope.of(context)
                    : null))
            ?.prepareImpersonation(token);
      }
      return;
    }

    if (type == 'postcard' || type == 'new_postcard') {
      final raw = data['postcardId'] ?? data['trailBookId'] ?? data['id'];
      final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      if (id != null) {
        openPostcard(id);
      } else {
        final nav = navigatorKey.currentState;
        if (nav != null) openTrailBook(nav.context);
      }
      return;
    }

    if (type == 'gift_subscription') {
      final giftId = data['giftId']?.toString();
      debugPrint('[NotificationRouter] gift_subscription giftId=$giftId');
      if (giftId != null && giftId.isNotEmpty) {
        openGiftSubscription(giftId);
      } else {
        checkPendingGiftSubscriptions();
      }
      return;
    }

    final profileRaw = data['profileId'];
    final profileId = profileRaw is int
        ? profileRaw
        : int.tryParse(profileRaw?.toString() ?? '');

    // Connect requests are not matches — never open chat.
    // Free → Reveal upsell; paid → profile if in reveal list, else Reveal.
    if (type == 'connect') {
      openConnectNotification(
        context: context,
        profileId: profileId,
        auth: auth,
        chrome: chrome,
        incoming: incoming,
        messages: messages,
        notificationData: data,
      );
      return;
    }

    if (type == 'activity_saved') {
      final activityRaw = data['activityId'] ?? data['id'];
      final activityId = activityRaw is int
          ? activityRaw
          : int.tryParse(activityRaw?.toString() ?? '');
      openActivitySavedNotification(
        context: context,
        activityId: activityId,
        chrome: chrome,
      );
      return;
    }

    if (type == 'activity') {
      final activityRaw = data['activityId'] ?? data['id'];
      final activityId = activityRaw is int
          ? activityRaw
          : int.tryParse(activityRaw?.toString() ?? '');
      openActivityShareNotification(
        context: context,
        activityId: activityId,
        chrome: chrome,
        messages: messages,
      );
      return;
    }

    if (type == 'meetup_joined' || type == 'meetup_nearby' || type == 'meetup_message') {
      final meetupRaw = data['meetupId'] ?? data['id'];
      final meetupId = meetupRaw is int
          ? meetupRaw
          : int.tryParse(meetupRaw?.toString() ?? '');
      openMeetupNotification(
        context: context,
        meetupId: meetupId,
        chrome: chrome,
      );
      return;
    }

    // RN typeToRouteMap: chat_message | match | match_in_country | new_profile → messages.
    // Deep links may omit type; still open Messages.
    final goesToMessages =
        type == null ||
        type == 'chat_message' ||
        type == 'match' ||
        type == 'match_in_country' ||
        type == 'new_profile';

    if (!goesToMessages) return;

    chrome?.selectTab(AppTab.messages);

    if (profileId == null || messages == null) return;

    // Push payload uses `title` as the sender display name (FCM notification
    // title). Pass it so we open with a provisional match immediately instead
    // of blocking on inbox refresh.
    final profileName = data['title']?.toString();

    openMatchChat(
      context: context,
      profileId: profileId,
      messages: messages,
      chrome: chrome,
      profileName: (profileName != null && profileName.isNotEmpty)
          ? profileName
          : null,
    );
  }

  /// Handles `type: 'activity_saved'` — Bucket List tab → activity → Saved list.
  static void openActivitySavedNotification({
    BuildContext? context,
    int? activityId,
    ShellChromeController? chrome,
  }) {
    Future<void> open() async {
      final nav = navigatorKey.currentState;
      final ctx = (context != null && context.mounted) ? context : nav?.context;
      if (ctx == null || !ctx.mounted) return;

      final shellChrome = chrome ?? ShellChromeScope.maybeOf(ctx);
      shellChrome?.selectTab(AppTab.bucketList);

      if (activityId == null) return;

      try {
        final activity = await activities_api.getActivity(activityId);
        if (!ctx.mounted) return;
        await ActivityDetailsScreen.open(
          ctx,
          activity,
          openSavedList: true,
        );
      } catch (e) {
        if (!ctx.mounted) return;
        AppToast.show(ctx, message: serverErrorText(e));
      }
    }

    if (navigatorKey.currentState != null) {
      unawaited(open());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(open());
      });
    }
  }

  /// Handles `type: 'activity'` / `fairytrail://activity/{id}` from web Join.
  ///
  /// Opens Activity Info so the user can join the group chat (or save).
  static void openActivityShareNotification({
    BuildContext? context,
    int? activityId,
    ShellChromeController? chrome,
    MessagesController? messages,
  }) {
    Future<void> open() async {
      final nav = await _waitForNavigator();
      final ctx = (context != null && context.mounted) ? context : nav?.context;
      if (ctx == null || !ctx.mounted) return;

      final shellChrome = chrome ?? ShellChromeScope.maybeOf(ctx);
      shellChrome?.selectTab(AppTab.explore);

      if (activityId == null) return;

      final messagesCtrl = messages ?? MessagesScope.maybeOf(ctx);

      try {
        final activity = await activities_api.getActivity(activityId);
        if (!ctx.mounted) return;

        await ActivityChatInfoScreen.openActivity(
          ctx,
          activity: activity,
          controller: messagesCtrl,
          onJoinChat: messagesCtrl == null
              ? null
              : () async {
                  shellChrome?.selectTab(AppTab.messages);
                  final rootNav = navigatorKey.currentState;
                  if (rootNav == null) return;
                  await rootNav.push(
                    MaterialPageRoute<void>(
                      builder: (_) => ActivityChatScreen(
                        controller: messagesCtrl,
                        activityId: activity.id,
                        previewActivity: activity,
                      ),
                    ),
                  );
                  messagesCtrl.closeThread();
                },
          onSave: activity.isSaved
              ? null
              : () => activities_api.saveActivity(activity.id),
        );
      } catch (e) {
        if (!ctx.mounted) return;
        AppToast.show(ctx, message: serverErrorText(e));
      }
    }

    unawaited(open());
  }

  /// Handles `meetup_joined` / `meetup_nearby` / `meetup_message` — Meetups tab → detail or chat.
  static void openMeetupNotification({
    BuildContext? context,
    int? meetupId,
    ShellChromeController? chrome,
  }) {
    Future<void> open() async {
      final nav = await _waitForNavigator();
      final ctx = (context != null && context.mounted) ? context : nav?.context;
      if (ctx == null || !ctx.mounted) return;

      final shellChrome = chrome ?? ShellChromeScope.maybeOf(ctx);
      shellChrome?.selectTab(AppTab.meetups);

      if (meetupId == null) return;

      try {
        final meetup = await meetup_api.fetchMeetup(meetupId);
        if (!ctx.mounted) return;
        if (meetup.joinedByMe) {
          await MeetupChatScreen.open(ctx, meetup: meetup);
        } else {
          await MeetupDetailScreen.open(
            ctx,
            meetupId: meetup.id,
            initial: meetup,
          );
        }
      } catch (e) {
        if (!ctx.mounted) return;
        AppToast.show(ctx, message: serverErrorText(e));
      }
    }

    unawaited(open());
  }

  /// FCM `onMessageOpenedApp` can run before the navigator overlay is back
  /// after a background resume. [Route.install] then hits `overlay!`.
  static Future<NavigatorState?> _waitForNavigator() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      final nav = navigatorKey.currentState;
      if (nav != null && nav.mounted && nav.overlay != null) return nav;
      await WidgetsBinding.instance.endOfFrame;
    }
    final nav = navigatorKey.currentState;
    if (nav != null && nav.mounted && nav.overlay != null) return nav;
    return null;
  }

  /// Handles `type: 'connect'` push / deep link (incoming connect request).
  static void openConnectNotification({
    BuildContext? context,
    int? profileId,
    AuthController? auth,
    ShellChromeController? chrome,
    IncomingConnectsController? incoming,
    MessagesController? messages,
    Map<String, dynamic> notificationData = const {},
  }) {
    Future<void> open() async {
      try {
        var nav = await _waitForNavigator();
        if (nav == null) return;
        var ctx = (context != null && context.mounted) ? context : nav.context;
        if (!ctx.mounted) return;

        final authCtrl = auth ?? AuthScope.of(ctx);
        final isPaid = authCtrl.isPaid;
        final incomingCtrl = incoming ?? IncomingConnectsScope.maybeOf(ctx);
        final messagesCtrl = messages ?? MessagesScope.maybeOf(ctx);
        final shellChrome = chrome ?? ShellChromeScope.maybeOf(ctx);

        // Land on Messages first so closing the upsell / profile returns to chat list.
        shellChrome?.selectTab(AppTab.messages);

        // Refresh reveal list so we can verify the sender is still pending.
        if (incomingCtrl != null) {
          try {
            await incomingCtrl.loadRevealList(force: true);
          } catch (_) {}
        }

        nav = await _waitForNavigator();
        if (nav == null) return;
        ctx = (context != null && context.mounted) ? context : nav.context;
        if (!ctx.mounted) return;

        final revealProfiles =
            incomingCtrl?.profiles ?? const <FullProfileDto>[];
        FullProfileDto? revealProfile;
        if (profileId != null) {
          for (final p in revealProfiles) {
            if (p.id == profileId) {
              revealProfile = p;
              break;
            }
          }
        }
        final inRevealList = revealProfile != null;
        final needsMismatchEvent = profileId == null || !inRevealList;

        if (needsMismatchEvent) {
          unawaited(
            _trackConnectRevealMismatch(
              auth: authCtrl,
              profileId: profileId,
              revealProfiles: revealProfiles,
              revealTotal: incomingCtrl?.total,
              reason: profileId == null
                  ? 'missing_profile_id'
                  : 'not_in_reveal_list',
              notificationData: notificationData,
            ),
          );
        }

        if (!isPaid) {
          await RevealPremiumNoticeScreen.open(
            ctx,
            onKeepMatching: () => shellChrome?.selectTab(AppTab.explore),
          );
          return;
        }

        if (profileId != null && revealProfile != null && incomingCtrl != null) {
          final profile = revealProfile;
          await ProfileViewScreen.open(
            ctx,
            profileId: profileId,
            from: 'incoming',
            showConnect: false,
            onIgnore: (profileContext) => _ignoreIncomingFromProfile(
              profile: profile,
              profileContext: profileContext,
              incoming: incomingCtrl,
            ),
            onConnect: (profileContext) => _acceptIncomingFromProfile(
              profile: profile,
              profileContext: profileContext,
              incoming: incomingCtrl,
              messages: messagesCtrl,
              chrome: shellChrome,
            ),
          );
        } else if (incomingCtrl != null) {
          // Don't use openRevealFlow — navigator/shell context sits above
          // IncomingConnectsScope, so pass controllers explicitly.
          await Navigator.of(ctx).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => RevealScreen(
                incoming: incomingCtrl,
                messages: messagesCtrl,
                chrome: shellChrome,
              ),
            ),
          );
        }
      } catch (e, st) {
        debugPrint('[Push] connect open failed: $e\n$st');
      }
    }

    unawaited(open());
  }

  static Future<void> _ignoreIncomingFromProfile({
    required FullProfileDto profile,
    required BuildContext profileContext,
    required IncomingConnectsController incoming,
  }) async {
    if (incoming.isBusy(profile.id)) return;
    HapticsService.selection();
    try {
      await incoming.ignore(profile);
      if (profileContext.mounted) Navigator.of(profileContext).pop();
    } catch (e) {
      if (!profileContext.mounted) return;
      AppToast.show(profileContext, message: serverErrorText(e));
    }
  }

  static Future<void> _acceptIncomingFromProfile({
    required FullProfileDto profile,
    required BuildContext profileContext,
    required IncomingConnectsController incoming,
    MessagesController? messages,
    ShellChromeController? chrome,
  }) async {
    if (incoming.isBusy(profile.id)) return;
    HapticsService.selection();
    try {
      final result = await incoming.accept(profile);
      if (!profileContext.mounted || result == null) return;

      if (result.isMatch) {
        HapticsService.success();
        unawaited(LocalStorage.instance.markHasMatch());
        unawaited(messages?.loadInbox(silent: true));
        final photo = profile.photos.isNotEmpty ? profile.photos.first : null;
        await Navigator.of(profileContext).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (ctx) => ConnectedScreen(
              profileName: profile.name,
              onLater: () => Navigator.of(ctx).pop(),
              onSendMessage: () {
                Navigator.of(ctx).pop();
                Navigator.of(profileContext).pop();
                if (messages == null) {
                  chrome?.selectTab(AppTab.messages);
                  return;
                }
                openMatchChat(
                  profileId: profile.id,
                  profileName: profile.name,
                  previewUrl: photo?.displayUrl,
                  blurHash: photo?.blurHash,
                  messages: messages,
                  chrome: chrome,
                );
              },
            ),
          ),
        );
      } else {
        AppToast.show(
          profileContext,
          message: 'Connected with ${profile.name}',
        );
      }

      if (profileContext.mounted &&
          ModalRoute.of(profileContext)?.isCurrent == true) {
        Navigator.of(profileContext).pop();
      }
    } catch (e) {
      if (!profileContext.mounted) return;
      final code = serverErrorCode(e);
      if (code == 'photo_issue') {
        showPhotoIssueSheet(profileContext);
        return;
      }
      if (code == 'gated_limit') {
        VerificationScreen.open(profileContext, from: 'messages');
        return;
      }
      AppToast.show(profileContext, message: serverErrorText(e));
    }
  }

  /// Mixpanel: connect push had no profileId, or sender not in reveal list.
  static Future<void> _trackConnectRevealMismatch({
    required AuthController auth,
    required int? profileId,
    required List<FullProfileDto> revealProfiles,
    required int? revealTotal,
    required String reason,
    required Map<String, dynamic> notificationData,
  }) async {
    final openedAt = DateTime.now().toUtc();
    final user = auth.user;
    final meta = auth.profileMeta;

    final attrs = <String, dynamic>{
      'reason': reason,
      'openedAt': openedAt.toIso8601String(),
      'openedAtMs': openedAt.millisecondsSinceEpoch,
      // Opened user = receiver who tapped the notification.
      'openedUserId': user?.id,
      'openedUserEmail': user?.email,
      'openedUserName': user?.name,
      'openedUserShortId': user?.shortId,
      'openedProfileId': meta?.id,
      'openedTier': auth.tier,
      'openedIsPaid': auth.isPaid,
      'openedIsGold': auth.isGold,
      'openedTierValidUntil': meta?.tierValidUntil?.toUtc().toIso8601String(),
      'openedTierIsCancelled': meta?.tierIsCancelled,
      'openedProfileStatus': meta?.status,
      'openedProfileType': meta?.profileType,
      'openedMatchWithCount': meta?.matchWithCount,
      'openedAge': meta?.age,
      'openedTravelStyle': meta?.travelStyle,
      'openedMobility': meta?.mobility,
      // Original / connected user = connect sender from the push payload.
      'originalProfileId': profileId,
      'connectedProfileId': profileId,
      'senderProfileId': profileId,
      'revealListTotal': revealTotal ?? revealProfiles.length,
      'revealListCount': revealProfiles.length,
      'revealListProfileIds': revealProfiles.map((p) => p.id).toList(),
      'revealUsers': revealProfiles
          .map(_fullProfileTrackAttrs)
          .toList(growable: false),
      'notificationData': _stringifyNotificationData(notificationData),
      'notificationTitle': notificationData['title']?.toString(),
      'notificationBody': notificationData['body']?.toString(),
      'notificationType': notificationData['type']?.toString(),
    };

    // Enrich sender details from reveal list, or best-effort profile fetch.
    FullProfileDto? sender;
    if (profileId != null) {
      for (final p in revealProfiles) {
        if (p.id == profileId) {
          sender = p;
          break;
        }
      }
      if (sender == null) {
        try {
          sender = await chat_api.viewProfile(profileId: profileId);
        } catch (_) {}
      }
    }

    if (sender != null) {
      attrs.addAll(_prefixAttrs('original', _fullProfileTrackAttrs(sender)));
      attrs.addAll(_prefixAttrs('connected', _fullProfileTrackAttrs(sender)));
      attrs.addAll(_prefixAttrs('sender', _fullProfileTrackAttrs(sender)));
    }

    debugPrint(
      '[Push] Mixpanel connect_notification_not_in_reveal '
      'reason=$reason senderProfileId=$profileId '
      'openedUserId=${user?.id} openedProfileId=${meta?.id} '
      'openedTier=${auth.tier} revealCount=${revealProfiles.length} '
      'attrs=$attrs',
    );
    await track('connect_notification_not_in_reveal', attrs);
  }

  static Map<String, dynamic> _fullProfileTrackAttrs(FullProfileDto p) {
    return {
      'profileId': p.id,
      'name': p.name,
      'status': p.status,
      'profileType': p.profileType,
      'age': p.age,
      'country': p.country?.country,
      'countryId': p.country?.id,
      'travelStyle': p.travelStyle,
      'mobility': p.mobility,
      'isVerified': p.isVerified,
      'occupation': p.occupation,
    };
  }

  static Map<String, dynamic> _prefixAttrs(
    String prefix,
    Map<String, dynamic> attrs,
  ) {
    return {
      for (final e in attrs.entries) '$prefix${_capitalize(e.key)}': e.value,
    };
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _stringifyNotificationData(Map<String, dynamic> data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  /// Opens the 1:1 chat for [profileId].
  ///
  /// When [profileName] is provided (Connected / Message buttons), opens
  /// immediately with a provisional match — no inbox wait. Inbox sync runs
  /// in the background. Deep links without a name still resolve via inbox.
  static Future<void> openMatchChat({
    BuildContext? context,
    required int profileId,
    required MessagesController messages,
    ShellChromeController? chrome,
    String? profileName,
    String? previewUrl,
    String? blurHash,
  }) async {
    chrome?.selectTab(AppTab.messages);

    MatchDto? match = messages.findMatchByProfileId(profileId);
    if (match == null && profileName != null && profileName.isNotEmpty) {
      match = MatchDto.provisional(
        profileId: profileId,
        name: profileName,
        previewUrl: previewUrl,
        blurHash: blurHash,
      );
    }
    if (match == null) {
      match = await messages.ensureMatchByProfileId(profileId);
      if (match == null) return;
    }

    final opened = match;
    void push() {
      final nav =
          navigatorKey.currentState ??
          (context != null && context.mounted
              ? Navigator.of(context, rootNavigator: true)
              : null);
      if (nav == null) return;
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => MatchChatScreen(match: opened, controller: messages),
        ),
      );
    }

    // Navigator may not be ready yet on cold start from a deep link.
    if (navigatorKey.currentState != null) {
      push();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => push());
    }

    // Keep inbox / real matchId in sync without blocking open.
    unawaited(messages.syncMatchAfterOpen(profileId));
  }

  /// Opens the set-new-password screen from `/dl/password-reset/{token}`.
  static void openPasswordReset(String token) {
    void push() {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ResetPasswordScreen(token: token),
        ),
      );
    }

    // Navigator may not be ready yet on cold start from a deep link.
    final nav = navigatorKey.currentState;
    if (nav != null) {
      push();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => push());
    }
  }

  static Future<void> openPostcard(int postcardId) async {
    await PostcardInbox.presentFromWs({'postcardId': postcardId});
  }

  static Future<void> openGiftSubscription(String idOrToken) async {
    await GiftSubscriptionInbox.presentByIdOrToken(idOrToken);
  }

  static Future<void> checkPendingGiftSubscriptions() async {
    await GiftSubscriptionInbox.checkPending();
  }
}
