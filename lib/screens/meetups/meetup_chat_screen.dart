import 'dart:async';

import 'package:fairytrail/api/meetups.dart';
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/messages/chat_bubble.dart';
import 'package:fairytrail/components/messages/chat_composer.dart';
import 'package:fairytrail/components/messages/chat_options_sheet.dart';
import 'package:fairytrail/components/messages/conversation_tile.dart';
import 'package:fairytrail/constants/profile_status.dart';
import 'package:fairytrail/meetups/meetup_chat_close.dart';
import 'package:fairytrail/meetups/meetup_icons.dart';
import 'package:fairytrail/meetups/meetup_time.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/meetups/meetup_chat_info_screen.dart';
import 'package:fairytrail/screens/meetups/report_meetup_sheet.dart';
import 'package:fairytrail/screens/messages/chat_profile_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/uuid.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Meetup group chat — same shell as activity chat.
class MeetupChatScreen extends StatefulWidget {
  const MeetupChatScreen({super.key, required this.meetup});

  final MeetupDto meetup;

  static Future<MeetupChatCloseResult?> open(
    BuildContext context, {
    required MeetupDto meetup,
  }) {
    return Navigator.of(context).push<MeetupChatCloseResult>(
      MaterialPageRoute(builder: (_) => MeetupChatScreen(meetup: meetup)),
    );
  }

  @override
  State<MeetupChatScreen> createState() => _MeetupChatScreenState();
}

class _MeetupChatScreenState extends State<MeetupChatScreen> {
  final _scroll = ScrollController();
  final _messages = <MeetupMessageDto>[];
  bool _loading = true;
  bool _sending = false;
  bool _hasMore = false;
  bool _loadingMore = false;
  String? _cursor;
  late MeetupDto _meetup;

  @override
  void initState() {
    super.initState();
    _meetup = widget.meetup;
    _scroll.addListener(_onScroll);
    unawaited(_load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      if (_loadingMore || !_hasMore) return;
      _loadingMore = true;
    }
    try {
      final page = await fetchMeetupMessages(
        _meetup.id,
        cursor: more ? _cursor : null,
      );
      if (!mounted) return;
      setState(() {
        if (more) {
          _messages.insertAll(0, page.messages);
        } else {
          _messages
            ..clear()
            ..addAll(page.messages);
        }
        _hasMore = page.hasMore;
        _cursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
      unawaited(markMeetupSeen(_meetup.id));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
        AppToast.show(context, message: serverErrorText(e));
      }
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients || !_hasMore || _loadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 120) {
      unawaited(_load(more: true));
    }
  }

  Future<void> _send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await sendMeetupMessage(
        meetupId: _meetup.id,
        id: uuidV4(),
        message: body,
      );
      if (!mounted) return;
      setState(() => _messages.add(msg));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openInfo() async {
    final result = await MeetupChatInfoScreen.open(context, meetup: _meetup);
    if (!mounted || result == null) return;
    if (result == MeetupChatClose.deleted ||
        result == MeetupChatClose.left ||
        result == MeetupChatClose.reported) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _leave() async {
    if (_meetup.isCreator) {
      AppToast.show(context, message: 'Creators can’t leave their meetup.');
      return;
    }
    final ok = await AppDialog.confirm(
      context,
      title: 'Leave meetup?',
      message: 'You’ll leave this meetup group chat.',
      confirmLabel: 'Leave',
    );
    if (!ok || !mounted) return;
    try {
      await leaveMeetup(_meetup.id);
      MessagesScope.maybeOf(context)?.removeMeetupChat(_meetup.id);
      if (mounted) Navigator.pop(context, MeetupChatClose.left);
    } catch (e) {
      if (mounted) AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _leaveMeetupChat({
    MeetupChatCloseResult result = MeetupChatClose.left,
  }) async {
    final messages = MessagesScope.maybeOf(context);
    await messages?.leaveMeetupChat(_meetup.id);
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _delete() async {
    if (!_meetup.isCreator) return;
    final ok = await AppDialog.confirm(
      context,
      title: 'Delete meetup?',
      message: 'This removes it from the map for everyone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await deleteMeetup(_meetup.id);
      MessagesScope.maybeOf(context)?.removeMeetupChat(_meetup.id);
      if (mounted) Navigator.pop(context, MeetupChatClose.deleted);
    } catch (e) {
      if (mounted) AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _onMenu() async {
    final action = await showMeetupChatOptionsSheet(
      context,
      isCreator: _meetup.isCreator,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'info':
        await _openInfo();
      case 'report':
        final reported = await showReportMeetupSheet(
          context,
          meetupId: _meetup.id,
        );
        if (!reported || !mounted) return;
        await _leaveMeetupChat(result: MeetupChatClose.reported);
      case 'leave':
        await _leave();
      case 'delete':
        await _delete();
    }
  }

  Future<void> _onUserOptions(MeetupMessageUserDto user) async {
    if (user.isRestricted || user.profileId <= 0) return;
    final action = await showActivityUserOptionsSheet(context);
    if (!mounted || action == null) return;
    switch (action) {
      case 'profile':
        await ChatProfileScreen.open(context, profileId: user.profileId);
      case 'report':
        final reported = await blockAndReportFromChat(
          context,
          profileId: user.profileId,
        );
        if (!reported || !mounted) return;
        await _leaveMeetupChat();
      case 'block':
        final blocked = await blockOnlyFromChat(
          context,
          profileId: user.profileId,
        );
        if (!blocked || !mounted) return;
        await _leaveMeetupChat();
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final me = auth.user?.id ?? '';
    final myStatus = auth.profileMeta?.status;
    final messages = _messages.where((msg) {
      if (msg.user.status == ProfileStatus.fraud &&
          myStatus != ProfileStatus.fraud) {
        return false;
      }
      return true;
    }).toList();

    final isDark = AppColors.isDark(context);
    final chatBg = isDark ? AppColors.darkBackground : Colors.white;
    final headerBg = Theme.of(context).scaffoldBackgroundColor;
    final count = _meetup.memberCount;
    final memberLabel = count > 0
        ? '${NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(count)} '
              '${count == 1 ? 'member' : 'members'}'
        : 'Group chat';
    final whenLabel = meetupStartsRelativeLabel(_meetup.startsAt);
    final subtitle = '$memberLabel · $whenLabel';
    final bannerH = ConnectivityScope.maybeOf(context)?.extent ?? 0;

    return ColoredBox(
      color: headerBg,
      child: AppSafeArea(
        bottom: false,
        child: Scaffold(
          backgroundColor: chatBg,
          appBar: AppBar(
            toolbarHeight: 64,
            backgroundColor: headerBg,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 0,
            bottom: ConnectivityAppBarBottom(height: bannerH),
            title: InkWell(
              onTap: _openInfo,
              child: Row(
                children: [
                  ChatAvatar(
                    size: 36,
                    isGroup: true,
                    leadingEmoji: meetupCategoryEmoji(_meetup.category),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          _meetup.name,
                          variant: AppTextVariant.label,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          maxLines: 1,
                        ),
                        AppText(
                          subtitle,
                          variant: AppTextVariant.caption,
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: _onMenu,
              ),
            ],
          ),
          body: Column(
            children: [
              if (_loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.primary,
                ),
              Expanded(
                child: _loading && messages.isEmpty
                    ? const SizedBox.shrink()
                    : messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: AppText(
                            'Start the conversation about this meetup',
                            variant: AppTextVariant.body,
                            color: AppColors.textSecondaryOf(context),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final i = messages.length - 1 - index;
                          final msg = messages[i];
                          final prev = i > 0 ? messages[i - 1] : null;
                          final next = i < messages.length - 1
                              ? messages[i + 1]
                              : null;
                          final showDate =
                              prev == null ||
                              !_sameDay(prev.createdAt, msg.createdAt);
                          final isMine = msg.userId == me;
                          final user = msg.user;
                          final restricted = user.isRestricted;
                          final showName =
                              !isMine &&
                              (prev == null || prev.userId != msg.userId);
                          final showAvatar =
                              !isMine &&
                              (next == null || next.userId != msg.userId);
                          final showTail =
                              next == null || next.userId != msg.userId;

                          return Padding(
                            padding: EdgeInsets.only(
                              top: (prev != null && prev.userId == msg.userId)
                                  ? 1
                                  : 6,
                            ),
                            child: Column(
                              children: [
                                if (showDate)
                                  ChatDateChip(
                                    label: formatDateSeparator(msg.createdAt),
                                  ),
                                ChatBubble(
                                  text: msg.message,
                                  isMine: isMine,
                                  createdAt: msg.createdAt,
                                  senderName: showName
                                      ? user.displayName
                                      : null,
                                  avatarUrl: isMine
                                      ? null
                                      : user.displayPhotoUrl,
                                  showAvatar: showAvatar,
                                  showTail: showTail,
                                  onAvatarTap: restricted
                                      ? null
                                      : () => _onUserOptions(user),
                                  onSenderTap: restricted
                                      ? null
                                      : () => _onUserOptions(user),
                                  pending: msg.pending,
                                  failed: msg.failed,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              ChatComposer(draftKey: 'meetup_${_meetup.id}', onSend: _send),
            ],
          ),
        ),
      ),
    );
  }
}
