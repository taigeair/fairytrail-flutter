import 'dart:async';

import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/api/models/chat_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/activities/report_activity_sheet.dart';
import 'package:fairytrail/components/messages/activity_chat_info_notice.dart';
import 'package:fairytrail/components/messages/chat_bubble.dart';
import 'package:fairytrail/components/messages/chat_composer.dart';
import 'package:fairytrail/components/messages/chat_options_sheet.dart';
import 'package:fairytrail/components/messages/conversation_tile.dart';
import 'package:fairytrail/constants/profile_status.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/review/review_prompt.dart';
import 'package:fairytrail/screens/messages/activity_chat_info_screen.dart';
import 'package:fairytrail/screens/messages/chat_profile_screen.dart';
import 'package:fairytrail/screens/profile/notifications_settings_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Activity group chat.
///
/// Pass [chat] when opening from inbox, or [activityId] (+ optional
/// [previewActivity]) when joining from Explore — the screen opens immediately
/// and loads recent messages in the background.
class ActivityChatScreen extends StatefulWidget {
  const ActivityChatScreen({
    super.key,
    required this.controller,
    this.chat,
    this.activityId,
    this.previewActivity,
  }) : assert(chat != null || activityId != null, 'Provide chat or activityId');

  final MessagesController controller;
  final ActivityChatDto? chat;
  final int? activityId;
  final ActivityDto? previewActivity;

  @override
  State<ActivityChatScreen> createState() => _ActivityChatScreenState();
}

class _ActivityChatScreenState extends State<ActivityChatScreen> {
  final _scroll = ScrollController();
  ActivityChatDto? _chat;
  bool _joining = false;
  String? _joinError;
  bool _showInfoNotice = false;

  int? get _activityId =>
      widget.activityId ??
      _chat?.activity.id ??
      widget.controller.currentActivity?.activity.id;

  @override
  void initState() {
    super.initState();
    _chat = widget.chat;
    widget.controller.addListener(_onUpdate);
    _scroll.addListener(_onScroll);
    unawaited(_loadInfoNoticeState());
    unawaited(_bootstrap());
  }

  Future<void> _loadInfoNoticeState() async {
    final id = _activityId;
    if (id == null) return;
    final dismissed =
        await LocalStorage.instance.isActivityChatInfoNoticeDismissed(id);
    if (!mounted) return;
    setState(() => _showInfoNotice = !dismissed);
  }

  Future<void> _closeInfoNotice() async {
    final id = _activityId;
    setState(() => _showInfoNotice = false);
    if (id != null) {
      await LocalStorage.instance.setActivityChatInfoNoticeDismissed(id);
    }
  }

  Future<void> _bootstrap() async {
    try {
      var chat = _chat;
      if (chat == null) {
        setState(() {
          _joining = true;
          _joinError = null;
        });
        chat = await widget.controller.joinActivity(widget.activityId!);
        if (!mounted) return;
        setState(() {
          _chat = chat;
          _joining = false;
        });
        unawaited(_loadInfoNoticeState());
      }
      // Load recent messages without blocking first paint of the shell.
      await widget.controller.openActivity(chat);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _joinError = serverErrorText(e);
      });
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    _scroll.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (_scroll.position.pixels < 80) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // reverse list: maxScrollExtent is older messages
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 120) {
      widget.controller.loadMoreActivityMessages();
    }
  }

  Future<void> _onUserOptions(ActivityChatMessageUserDto? user) async {
    if (user == null || user.isRestricted || user.profileId <= 0) return;

    final action = await showActivityUserOptionsSheet(context);
    if (!mounted || action == null) return;

    switch (action) {
      case 'profile':
        await ChatProfileScreen.open(
          context,
          profileId: user.profileId,
          messages: widget.controller,
        );
        break;
      case 'report':
        final reported = await blockAndReportFromChat(
          context,
          profileId: user.profileId,
        );
        if (!reported || !mounted) return;
        break;
      case 'block':
        final blocked = await blockOnlyFromChat(
          context,
          profileId: user.profileId,
        );
        if (!blocked || !mounted) return;
        break;
    }
  }

  Future<void> _openActivityInfo() async {
    final chat = widget.controller.currentActivity ?? _chat;
    if (chat == null) return;
    final left = await ActivityChatInfoScreen.open(
      context,
      chat: chat,
      controller: widget.controller,
    );
    if (left == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onMenu() async {
    final action = await showActivityChatOptionsSheet(context);
    if (!mounted || action == null) return;
    final chat = widget.controller.currentActivity ?? _chat;
    if (chat == null) return;

    switch (action) {
      case 'info':
        await _openActivityInfo();
        break;
      case 'leave':
        final ok = await AppDialog.confirm(
          context,
          title: 'Leave chat',
          message: 'You’ll leave this activity group chat.',
          confirmLabel: 'Leave',
        );
        if (!ok || !mounted) return;
        try {
          await widget.controller.leaveActivity(chat.activity.id);
          if (mounted) Navigator.of(context).pop();
        } catch (e) {
          if (mounted) {
            AppToast.show(context, message: serverErrorText(e));
          }
        }
        break;
      case 'report':
        await showReportActivitySheet(context, activityId: chat.activity.id);
        break;
    }
  }

  String get _title {
    final chat = widget.controller.currentActivity ?? _chat;
    return chat?.activity.displayTitle ??
        widget.previewActivity?.displayTitle ??
        'Activity chat';
  }

  String? get _avatarUrl {
    final chat = widget.controller.currentActivity ?? _chat;
    return chat?.activity.photo.displayUrl ??
        widget.previewActivity?.photo.displayUrl;
  }

  int get _memberCount {
    final chat = widget.controller.currentActivity ?? _chat;
    return chat?.memberCount ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final me = auth.user?.id ?? '';
    final myStatus = auth.profileMeta?.status;
    // RN: hide fraud senders unless the viewer is also fraud.
    final messages = widget.controller.openActivityMessages.where((msg) {
      final user = msg.user;
      if (user?.status == ProfileStatus.fraud &&
          myStatus != ProfileStatus.fraud) {
        return false;
      }
      return true;
    }).toList();
    final hasChat = _chat != null || widget.controller.currentActivity != null;
    final loading =
        (_joining || widget.controller.threadLoading) && _joinError == null;

    final isDark = AppColors.isDark(context);
    final chatBg = isDark ? AppColors.darkBackground : Colors.white;
    final headerBg = Theme.of(context).scaffoldBackgroundColor;
    final memberLabel = _memberCount > 0
        ? '${NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(_memberCount)} members'
        : 'Group chat';
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
            elevation: 0,
            shadowColor: Colors.transparent,
            titleSpacing: 0,
            bottom: bannerH > 0
                ? ConnectivityAppBarBottom(height: bannerH)
                : null,
            title: InkWell(
              onTap: hasChat ? _openActivityInfo : null,
              child: Row(
                children: [
                  ChatAvatar(url: _avatarUrl, size: 36, isGroup: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          _title,
                          variant: AppTextVariant.label,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          maxLines: 1,
                        ),
                        AppText(
                          _joining ? 'Joining…' : memberLabel,
                          variant: AppTextVariant.caption,
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (hasChat)
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: _onMenu,
                ),
            ],
          ),
          body: Column(
            children: [
              const ActivityChatHeaderShadow(),
              if (_showInfoNotice)
                ColoredBox(
                  color: headerBg,
                  child: ActivityChatInfoNotice(
                    inAppBar: true,
                    onClose: () => unawaited(_closeInfoNotice()),
                  ),
                ),
              if (loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.primary,
                ),
              Expanded(
                child: _joinError != null && messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppText(
                                _joinError!,
                                variant: AppTextVariant.body,
                                color: AppColors.textSecondaryOf(context),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  setState(() => _joinError = null);
                                  unawaited(_bootstrap());
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: AppText(
                            'Start the conversation about this activity',
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
                          final restricted = user?.isRestricted ?? false;
                          final showName =
                              !isMine &&
                              (prev == null || prev.userId != msg.userId);
                          // Avatar/tail on last bubble of a consecutive group.
                          final showAvatar =
                              !isMine &&
                              (next == null || next.userId != msg.userId);
                          final showTail =
                              next == null || next.userId != msg.userId;
                          final fallbackPhoto =
                              widget.previewActivity?.photo.displayUrl ??
                              (widget.controller.currentActivity ?? _chat)
                                  ?.activity
                                  .photo
                                  .displayUrl;
                          // Never fall back to the activity image for restricted
                          // users — that was leaking pending/disabled photos.
                          final avatarUrl = isMine
                              ? null
                              : (restricted
                                    ? null
                                    : (user?.displayPhotoUrl ?? fallbackPhoto));

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
                                      ? (user?.displayName)
                                      : null,
                                  avatarUrl: avatarUrl,
                                  avatarAssetPath: !isMine && restricted
                                      ? 'assets/profile/profile_placeholder.png'
                                      : null,
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
              ChatComposer(
                draftKey: 'activity_${widget.activityId ?? _chat?.activity.id}',
                onSend: hasChat && !_joining
                    ? (text) {
                        final wasEmpty =
                            widget.controller.openActivityMessages.isEmpty;
                        widget.controller.sendActivityMessage(text);
                        EnableNotificationsScreen.openIfNeeded(
                          context,
                          from: 'first_message',
                        );
                        if (wasEmpty) {
                          ReviewPrompt.maybeScheduleAfterFirstMessage(context);
                        }
                      }
                    : (_) async {},
                enabled: hasChat && !_joining && _joinError == null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}
