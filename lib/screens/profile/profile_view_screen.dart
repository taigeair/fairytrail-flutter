import 'dart:async';

import 'package:fairytrail/api/explore.dart';
import 'package:fairytrail/api/chat.dart' as chat_api;
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/components/explore/explore_profile_card.dart';
import 'package:fairytrail/components/explore/explore_profile_actions.dart';
import 'package:fairytrail/components/explore/photo_issue_sheet.dart';
import 'package:fairytrail/constants/profile_status.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/moderation/local_moderation.dart';
import 'package:fairytrail/push/notification_router.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/screens/explore/connected_screen.dart';
import 'package:fairytrail/screens/profile/notifications_settings_screen.dart';
import 'package:fairytrail/screens/shell/floating_bottom_nav.dart';
import 'package:fairytrail/screens/trail_book/trail_book_nav.dart';
import 'package:fairytrail/screens/verification/verification_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Full profile for another user (RN `profile/view/[profileId]`).
class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({
    super.key,
    required this.profileId,
    this.from = 'trailbook',
    this.showConnect = true,
    this.fromChat = false,
    this.messages,
    this.chrome,
    this.onIgnore,
    this.onConnect,
  });

  final int profileId;

  /// Connect analytics source — must be an [ActionSourceEnum] value
  /// (`explore` | `incoming` | `trailbook` | `nearby` | `campfire`).
  /// Unknown values fall back to `trailbook` (RN profile-view default).
  final String from;
  final bool showConnect;

  /// When true (opened from a 1:1 match chat), Message just pops back.
  /// Activity/meetup group chats leave this false so Message opens the DM.
  final bool fromChat;

  /// Captured from the caller — this route sits above [MessagesScope].
  final MessagesController? messages;
  final ShellChromeController? chrome;

  final Future<void> Function(BuildContext context)? onIgnore;
  final Future<void> Function(BuildContext context)? onConnect;

  static const _validConnectSources = {
    'explore',
    'incoming',
    'trailbook',
    'nearby',
    'campfire',
  };

  static Future<void> open(
    BuildContext context, {
    required int profileId,
    String from = 'trailbook',
    bool showConnect = true,
    bool fromChat = false,
    MessagesController? messages,
    ShellChromeController? chrome,
    Future<void> Function(BuildContext context)? onIgnore,
    Future<void> Function(BuildContext context)? onConnect,
  }) {
    // Capture before push — the profile route sits above [MessagesScope].
    final resolvedMessages = messages ?? MessagesScope.maybeOf(context);
    final resolvedChrome = chrome ?? ShellChromeScope.maybeOf(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileViewScreen(
          profileId: profileId,
          from: from,
          showConnect: showConnect,
          fromChat: fromChat,
          messages: resolvedMessages,
          chrome: resolvedChrome,
          onIgnore: onIgnore,
          onConnect: onConnect,
        ),
      ),
    );
  }

  /// Backend rejects any `source` outside ActionSourceEnum.
  String get connectSource {
    final s = from.toLowerCase();
    return _validConnectSources.contains(s) ? s : 'trailbook';
  }

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  final _scroll = ScrollController();
  FullProfileDto? _profile;
  String? _error;
  bool _loading = true;
  bool _statusLoading = false;
  bool _connecting = false;
  String? _customAction;

  /// `connect` | `sent` | `connected` | `blocked` | `blocked_by` | …
  String? _status;
  bool _locallyBlocked = false;

  bool get _isBlocked {
    final status = _status;
    if (status != null && status.contains('blocked')) return true;
    return _locallyBlocked;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        chat_api.viewProfile(profileId: widget.profileId),
        LocalModeration.instance.isProfileBlocked(widget.profileId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as FullProfileDto;
        _locallyBlocked = results[1] as bool;
        _loading = false;
      });
      // Always resolve status so blocked profiles hide actions (RN).
      unawaited(_loadStatus());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = serverErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadStatus() async {
    setState(() => _statusLoading = true);
    try {
      final status = await getProfileStatus(widget.profileId);
      if (!mounted) return;
      setState(() => _status = status.isEmpty ? 'connect' : status);
    } catch (_) {
      if (!mounted) return;
      // Keep null when offline so we don't flash Connect on a blocked user
      // we already know about from local moderation.
      if (_status == null && !_locallyBlocked) {
        setState(() => _status = 'connect');
      }
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  Future<void> _onConnect() async {
    if (_connecting || _profile == null) return;
    final status = _profile!.status;
    if (status == ProfileStatus.statusNew ||
        status == ProfileStatus.pending ||
        status == ProfileStatus.unapproved) {
      AppToast.show(
        context,
        message: 'Sorry, this user cannot be contacted at this time.',
      );
      return;
    }

    setState(() => _connecting = true);
    try {
      final result = await connectProfile(
        profileId: widget.profileId,
        source: widget.connectSource,
      );
      if (!mounted) return;
      EnableNotificationsScreen.openIfNeeded(context, from: 'first_connect');
      if (result.isMatch) {
        HapticsService.success();
        unawaited(LocalStorage.instance.markHasMatch());
        setState(() => _status = 'connected');
        final messages = widget.messages ?? MessagesScope.maybeOf(context);
        // Prefetch matches so Send message opens instantly.
        unawaited(messages?.loadInbox(silent: true));
        final chrome = widget.chrome ?? ShellChromeScope.maybeOf(context);
        final profile = _profile!;
        final photo = profile.photos.isNotEmpty ? profile.photos.first : null;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (ctx) => ConnectedScreen(
              profileName: profile.name,
              onLater: () => Navigator.of(ctx).pop(),
              onSendMessage: () {
                final profileId = widget.profileId;
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                if (messages == null) {
                  chrome?.selectTab(AppTab.messages);
                  return;
                }
                NotificationRouter.openMatchChat(
                  profileId: profileId,
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
        setState(() => _status = 'sent');
        AppToast.show(context, message: 'Connection request sent');
      }
    } catch (e) {
      if (!mounted) return;
      final code = serverErrorCode(e);
      if (code == 'photo_issue') {
        showPhotoIssueSheet(context);
        return;
      }
      if (code == 'gated_limit') {
        VerificationScreen.open(context, from: widget.from);
        return;
      }
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _onMessage() {
    // Opened from a 1:1 match chat — just return to it.
    if (widget.fromChat) {
      Navigator.of(context).pop();
      return;
    }

    final messages = widget.messages ?? MessagesScope.maybeOf(context);
    final chrome = widget.chrome ?? ShellChromeScope.maybeOf(context);
    final profileId = widget.profileId;
    final profile = _profile;
    final photo = profile != null && profile.photos.isNotEmpty
        ? profile.photos.first
        : null;

    if (messages == null) {
      AppToast.show(context, message: 'Messages unavailable');
      return;
    }

    Navigator.of(context).pop();
    NotificationRouter.openMatchChat(
      profileId: profileId,
      profileName: profile?.name,
      previewUrl: photo?.displayUrl,
      blurHash: photo?.blurHash,
      messages: messages,
      chrome: chrome,
    );
  }

  Widget? _buildAction() {
    // RN: no Connect / Gift / Message / Accept when blocked either way.
    if (_isBlocked) return null;

    if (widget.onIgnore != null && widget.onConnect != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _customAction != null
                  ? null
                  : () => _runCustomAction('ignore', widget.onIgnore!),
              child: const Text('Ignore'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton(
              label: 'Accept',
              onPressed: _customAction != null
                  ? null
                  : () => _runCustomAction('connect', widget.onConnect!),
              isLoading: _customAction == 'connect',
            ),
          ),
        ],
      );
    }
    if (!widget.showConnect) return null;
    if (_statusLoading && _status == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final status = _status ?? 'connect';

    if (status == 'connected') {
      return Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: AppButton(
              label: 'Inspire',
              variant: AppButtonVariant.secondary,
              onPressed: _onCare,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton(label: 'Message', onPressed: _onMessage),
          ),
        ],
      );
    }
    if (status == 'sent') {
      // Solid disabled (RN: gray fill) — not the outlined secondary look.
      return Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Inspire',
              variant: AppButtonVariant.secondary,
              onPressed: _onCare,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: AppColors.mediumGray,
                  disabledForegroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Pending'),
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Inspire',
            variant: AppButtonVariant.secondary,
            onPressed: _onCare,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            label: widget.connectSource == 'incoming' ? 'Accept' : 'Connect',
            onPressed: _onConnect,
            isLoading: _connecting,
          ),
        ),
      ],
    );
  }

  Future<void> _onCare() async {
    final profile = _profile;
    if (profile == null) return;
    final photo = profile.photos.isEmpty
        ? null
        : profile.photos.first.displayUrl;
    await openCareFlow(
      context,
      profileId: profile.id,
      name: profile.name,
      profilePhotoUrl: photo,
      path: 'viewProfile',
    );
  }

  Future<void> _onMore() async {
    if (_isBlocked) return;
    HapticsService.selection();
    final reported = await showExploreProfileActionsSheet(
      context,
      profileId: widget.profileId,
    );
    if (!reported || !mounted) return;
    setState(() {
      _locallyBlocked = true;
      _status = 'blocked';
    });
  }

  Future<void> _runCustomAction(
    String actionName,
    Future<void> Function(BuildContext context) action,
  ) async {
    if (_customAction != null) return;
    setState(() => _customAction = actionName);
    try {
      await action(context);
    } finally {
      if (mounted) setState(() => _customAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = _buildAction();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_profile?.name ?? 'Profile'),
        actions: [
          if (_profile != null && !_isBlocked)
            IconButton(
              onPressed: _onMore,
              tooltip: 'More',
              icon: const Icon(Icons.more_horiz),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: AppLoading())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(
                      _error!,
                      textAlign: TextAlign.center,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(height: 16),
                    AppButton(label: 'Retry', onPressed: _load),
                  ],
                ),
              ),
            )
          : _profile == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Expanded(
                  child: ExploreProfileCard(
                    profile: _profile!,
                    scrollController: _scroll,
                    bottomInset: action != null ? 24 : 24,
                    messages: widget.messages,
                    chrome: widget.chrome,
                  ),
                ),
                if (action != null)
                  AppSafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: action,
                    ),
                  ),
              ],
            ),
    );
  }
}
