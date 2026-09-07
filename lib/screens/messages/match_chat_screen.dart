import 'dart:async';

import 'package:fairytrail/api/chat.dart';
import 'package:fairytrail/api/kindness.dart';
import 'package:fairytrail/api/models/chat_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/messages/chat_bubble.dart';
import 'package:fairytrail/components/messages/chat_composer.dart';
import 'package:fairytrail/components/messages/chat_options_sheet.dart';
import 'package:fairytrail/components/messages/chat_top_banner.dart';
import 'package:fairytrail/components/messages/conversation_tile.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/review/review_prompt.dart';
import 'package:fairytrail/screens/messages/chat_profile_screen.dart';
import 'package:fairytrail/screens/messages/kindness_rated_screen.dart';
import 'package:fairytrail/screens/profile/notifications_settings_screen.dart';
import 'package:fairytrail/screens/trail_book/trail_book_nav.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class MatchChatScreen extends StatefulWidget {
  const MatchChatScreen({
    super.key,
    required this.match,
    required this.controller,
  });

  final MatchDto match;
  final MessagesController controller;

  @override
  State<MatchChatScreen> createState() => _MatchChatScreenState();
}

class _MatchChatScreenState extends State<MatchChatScreen> {
  final _scroll = ScrollController();
  bool _showKindnessBanner = false;
  bool _kindnessChecked = false;
  bool _ratingInFlight = false;

  @override
  void initState() {
    super.initState();
    widget.controller.openMatch(widget.match);
    widget.controller.addListener(_onUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureRemoteConfig());
    });
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
    unawaited(_maybeShowKindnessBanner());
    // Stick to bottom when new messages arrive near end.
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

  Future<void> _ensureRemoteConfig() async {
    final remote = RemoteConfigScope.of(context);
    if (!remote.isReady) {
      try {
        await remote.refresh();
      } catch (_) {
        // Offline / init failure — keep banner hidden.
      }
    }
    if (!mounted) return;
    await _maybeShowKindnessBanner();
  }

  Future<void> _maybeShowKindnessBanner() async {
    final enabled = RemoteConfigScope.of(context).showRateKindnessBanner;
    if (!enabled || _kindnessChecked || _showKindnessBanner) {
      return;
    }
    final matchId = (widget.controller.currentMatch ?? widget.match).id;
    if (matchId <= 0) return;
    final me = AuthScope.of(context).user?.id ?? '';
    if (me.isEmpty) return;

    final messages = widget.controller.openMatchMessages;
    var mine = 0;
    var theirs = 0;
    for (final m in messages) {
      if (m.userId == me) {
        mine++;
      } else {
        theirs++;
      }
    }
    if (mine < 2 || theirs < 2) return;

    _kindnessChecked = true;
    try {
      final hasRated = await checkKindnessRating(matchId);
      if (!mounted) return;
      setState(() => _showKindnessBanner = !hasRated);
    } catch (_) {
      // Keep hidden if check fails.
    }
  }

  Future<void> _rateKindness(String value) async {
    if (_ratingInFlight) return;
    _ratingInFlight = true;
    final match = widget.controller.currentMatch ?? widget.match;
    try {
      await rateUserKindness(
        matchId: match.id,
        ratedUserId: match.profile.id,
        ratedValue: value,
      );
      if (!mounted) return;
      setState(() => _showKindnessBanner = false);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: serverErrorText(e));
      }
    } finally {
      _ratingInFlight = false;
    }
  }

  Future<void> _onKindnessYes() async {
    final match = widget.controller.currentMatch ?? widget.match;
    final senderProfileType = AuthScope.of(context).profileMeta?.profileType;
    var receiverProfileType = match.profile.profileType;
    if (receiverProfileType == null || receiverProfileType.isEmpty) {
      try {
        final profile = await viewProfile(profileId: match.profile.id);
        receiverProfileType = profile.profileType;
      } catch (_) {
        // Fall through to else illustration.
      }
    }
    await _rateKindness('positive');
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KindnessRatedScreen(
          profileId: match.profile.id,
          name: match.profile.name,
          profilePhotoUrl: match.profile.previewUrl,
          senderProfileType: senderProfileType,
          receiverProfileType: receiverProfileType,
        ),
      ),
    );
  }

  Future<void> _onKindnessClose() => _rateKindness('neutral');

  Future<void> _onMenu() async {
    final action = await showMatchChatOptionsSheet(context);
    if (!mounted || action == null) return;
    final match = widget.controller.currentMatch ?? widget.match;

    switch (action) {
      case 'profile':
        await ChatProfileScreen.open(
          context,
          profileId: match.profile.id,
          messages: widget.controller,
          fromMatchChat: true,
        );
        break;
      case 'care':
        await openCareFlow(
          context,
          profileId: match.profile.id,
          name: match.profile.name,
          profilePhotoUrl: match.profile.previewUrl,
          path: 'messages',
        );
        break;
      case 'unmatch':
        final ok = await AppDialog.confirm(
          context,
          title: 'Remove connection',
          message:
              'This will delete all messages and you won’t see this person anymore',
          confirmLabel: 'Remove',
        );
        if (!ok || !mounted) return;
        try {
          await widget.controller.unmatch(match.profile.id);
          if (mounted) Navigator.of(context).pop();
        } catch (e) {
          if (mounted) {
            AppToast.show(context, message: serverErrorText(e));
          }
        }
        break;
      case 'report':
        final reported = await blockAndReportFromChat(
          context,
          profileId: match.profile.id,
        );
        if (reported && mounted) {
          await widget.controller.unmatch(match.profile.id);
          if (mounted) Navigator.of(context).pop();
        }
        break;
      case 'block':
        final blocked = await blockOnlyFromChat(
          context,
          profileId: match.profile.id,
        );
        if (blocked && mounted) {
          await widget.controller.unmatch(match.profile.id);
          if (mounted) Navigator.of(context).pop();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final me = auth.user?.id ?? '';
    final match = widget.controller.currentMatch ?? widget.match;
    final messages = widget.controller.openMatchMessages;
    final loading = widget.controller.threadLoading;
    final restricted = match.profile.isRestricted;
    final displayName = match.profile.displayName;

    final isDark = AppColors.isDark(context);
    final chatBg = isDark ? AppColors.darkBackground : Colors.white;
    final headerBg = Theme.of(context).scaffoldBackgroundColor;
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
              onTap: restricted
                  ? null
                  : () {
                      unawaited(
                        ChatProfileScreen.open(
                          context,
                          profileId: match.profile.id,
                          messages: widget.controller,
                          fromMatchChat: true,
                        ),
                      );
                    },
              child: Row(
                children: [
                  ChatAvatar(
                    url: match.profile.displayPhotoUrl,
                    blurHash: match.profile.displayBlurHash,
                    assetPath: restricted
                        ? 'assets/profile/profile_placeholder.png'
                        : null,
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      displayName,
                      variant: AppTextVariant.label,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      maxLines: 1,
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
              if (loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.primary,
                ),
              if (_showKindnessBanner)
                ChatTopBanner(onClose: _onKindnessClose, onYes: _onKindnessYes),
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: AppText(
                            'Say hi to $displayName!',
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
                          // reverse list: index 0 = newest
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
                                  avatarUrl: isMine
                                      ? null
                                      : match.profile.displayPhotoUrl,
                                  avatarBlurHash: isMine
                                      ? null
                                      : match.profile.displayBlurHash,
                                  avatarAssetPath: !isMine && restricted
                                      ? 'assets/profile/profile_placeholder.png'
                                      : null,
                                  showAvatar: showAvatar,
                                  showTail: showTail,
                                  onAvatarTap: isMine || restricted
                                      ? null
                                      : () {
                                          unawaited(
                                            ChatProfileScreen.open(
                                              context,
                                              profileId: match.profile.id,
                                              messages: widget.controller,
                                              fromMatchChat: true,
                                            ),
                                          );
                                        },
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
                draftKey: 'match_${widget.match.id}',
                onSend: (text) {
                  final wasEmpty = widget.controller.openMatchMessages.isEmpty;
                  widget.controller.sendMatchMessage(text);
                  EnableNotificationsScreen.openIfNeeded(
                    context,
                    from: 'first_message',
                  );
                  if (wasEmpty) {
                    ReviewPrompt.maybeScheduleAfterFirstMessage(context);
                  }
                },
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
