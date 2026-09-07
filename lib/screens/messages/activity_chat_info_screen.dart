import 'package:fairytrail/activities/activity_share.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/api/models/chat_models.dart';
import 'package:fairytrail/components/activities/report_activity_sheet.dart';
import 'package:fairytrail/components/activities/saved_by_explorers_card.dart';
import 'package:fairytrail/components/activities/saved_explorers_sheet.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/profile/profile_view_screen.dart';
import 'package:fairytrail/screens/messages/activity_chat_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// WhatsApp-style activity / group-chat info.
///
/// Pops with `true` when the user leaves the chat so the chat screen can close.
class ActivityChatInfoScreen extends StatefulWidget {
  const ActivityChatInfoScreen({
    super.key,
    required this.chat,
    required this.controller,
  }) : activity = null,
       onJoinChat = null,
       onSave = null,
       heroTag = null;

  const ActivityChatInfoScreen.forActivity({
    super.key,
    required this.activity,
    this.controller,
    this.onJoinChat,
    this.onSave,
    this.heroTag,
  }) : chat = null,
       assert(activity != null);

  final ActivityChatDto? chat;
  final MessagesController? controller;
  final ActivityDto? activity;
  final Future<void> Function()? onJoinChat;

  /// Saves the activity to the user's bucket list (when not already saved).
  final Future<void> Function()? onSave;

  /// Shared with the source card for the image Hero flight.
  final Object? heroTag;

  /// Returns `true` if the user left the chat.
  static Future<bool?> open(
    BuildContext context, {
    required ActivityChatDto chat,
    required MessagesController controller,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ActivityChatInfoScreen(chat: chat, controller: controller),
      ),
    );
  }

  /// Opens the same Activity Info UI outside an existing group chat.
  static Future<void> openActivity(
    BuildContext context, {
    required ActivityDto activity,
    MessagesController? controller,
    Future<void> Function()? onJoinChat,
    Future<void> Function()? onSave,
    Object? heroTag,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ActivityChatInfoScreen.forActivity(
          activity: activity,
          controller: controller,
          onJoinChat: onJoinChat,
          onSave: onSave,
          heroTag: heroTag ?? 'activity-image-${activity.id}',
        ),
      ),
    );
  }

  @override
  State<ActivityChatInfoScreen> createState() => _ActivityChatInfoScreenState();
}

class _ActivityChatInfoScreenState extends State<ActivityChatInfoScreen> {
  late ActivityDto _activity;
  late int _memberCount;
  ActivityChatDto? _resolvedChat;
  bool _leaving = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Prefer the activity already on the previous screen (card / chat).
    // Never fetch here — inbox may already be in memory for Leave vs Join.
    _activity = widget.chat?.activity ?? widget.activity!;
    _memberCount = widget.chat?.memberCount ?? _activity.memberCount;
    _resolvedChat =
        widget.chat ?? widget.controller?.activityChatFor(_activity.id);
    final joined = _resolvedChat;
    if (joined != null && widget.chat == null) {
      // Keep card activity fields; only membership comes from in-memory chat.
      _memberCount = joined.memberCount;
    }
  }

  Future<void> _openSavedExplorers() async {
    final profileId = await showSavedExplorersSheet(
      context,
      activity: _activity,
    );
    if (!mounted || profileId == null) return;
    await ProfileViewScreen.open(
      context,
      profileId: profileId,
      from: 'trailbook',
      messages: widget.controller,
    );
  }

  Future<void> _report() async {
    await showReportActivitySheet(context, activityId: _activity.id);
  }

  Future<void> _share() async {
    await ActivityShare.shareActivity(context, _activity);
  }

  Future<void> _join() async {
    final onJoinChat = widget.onJoinChat;
    final messages = widget.controller;
    if (onJoinChat == null && messages == null) return;

    final activity = _activity;
    final navigator = Navigator.of(context);
    navigator.pop();

    // Prefer the caller callback (switches to Messages tab, then opens chat).
    if (onJoinChat != null) {
      await onJoinChat();
      return;
    }

    // Fallback when only a captured [MessagesController] is available
    // (route sits above [MessagesScope]).
    final controller = messages;
    if (controller == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityChatScreen(
          controller: controller,
          activityId: activity.id,
          previewActivity: activity,
        ),
      ),
    );
    controller.closeThread();
  }

  Future<void> _save() async {
    final onSave = widget.onSave;
    if (onSave == null || _activity.isSaved || _saving) return;
    setState(() => _saving = true);
    try {
      await onSave();
      if (!mounted) return;
      setState(() {
        _activity = _activity.copyWith(
          isSaved: true,
          explorerCount: _activity.explorerCount + 1,
        );
        _saving = false;
      });
      AppToast.show(context, message: 'Saved to your bucket list');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    final ok = await AppDialog.confirm(
      context,
      title: 'Leave chat?',
      message:
          'The adventure will stay on your bucket list until you remove it.',
      confirmLabel: 'Leave',
    );
    if (!ok || !mounted) return;

    setState(() => _leaving = true);
    try {
      await widget.controller!.leaveActivity(_activity.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _leaving = false);
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final imageDimension = screenSize.shortestSide >= 600
        ? screenSize.width * 0.66
        : 280.0;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = NumberFormat.decimalPattern(locale);
    final membersLabel = _resolvedChat == null
        ? 'Join chat to view chat members'
        : _memberCount > 0
        ? '${fmt.format(_memberCount)} '
              '${_memberCount == 1 ? 'chat member' : 'chat members'}'
        : '';
    final country = _activity.country?.country;
    final titleLine = (country != null && country.isNotEmpty)
        ? '${_activity.name} · $country'
        : _activity.name;
    final secondary = AppColors.textSecondaryOf(context);
    final pageBg = AppColors.backgroundOf(context);
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Fairytrail Bucket List Activity'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _InfoCard(
            backgroundColor: pageBg,
            showShadow: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: [
                  Hero(
                    tag: widget.heroTag ?? 'activity-image-${_activity.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox.square(
                          dimension: imageDimension,
                          child: AppCachedImage(url: _activity.photo.url),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    titleLine,
                    variant: AppTextVariant.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    membersLabel,
                    variant: AppTextVariant.body,
                    color: secondary,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SavedByExplorersCard(
            explorerCount: _activity.explorerCount,
            onTap: _openSavedExplorers,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            child: Column(
              children: [
                ..._actionTiles(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actionTiles(BuildContext context) {
    final tiles = <Widget>[];

    void add(Widget tile) {
      if (tiles.isNotEmpty) {
        tiles.add(
          Divider(
            height: 1,
            indent: 56,
            color: AppColors.borderOf(context),
          ),
        );
      }
      tiles.add(tile);
    }

    if (_activity.isSaved) {
      add(
        const _ActionTile(
          icon: Icons.bookmark_rounded,
          label: 'Already in bucket list',
          onTap: null,
        ),
      );
    } else if (widget.onSave != null) {
      add(
        _ActionTile(
          icon: Icons.bookmark_border_rounded,
          label: _saving ? 'Saving…' : 'Save to bucket list',
          onTap: _saving ? null : _save,
        ),
      );
    }

    if (_resolvedChat != null) {
      add(
        _ActionTile(
          icon: Icons.logout,
          label: 'Leave chat',
          onTap: _leaving ? null : _leave,
        ),
      );
    } else if (widget.onJoinChat != null || widget.controller != null) {
      add(
        _ActionTile(
          icon: Icons.chat_bubble_outline,
          label: 'Join group chat',
          onTap: _join,
        ),
      );
    }

    add(
      _ActionTile(
        icon: Icons.ios_share_rounded,
        label: 'Share activity',
        onTap: _share,
      ),
    );

    add(
      _ActionTile(
        icon: Icons.flag_outlined,
        label: 'Report activity',
        destructive: true,
        onTap: _report,
      ),
    );

    return tiles;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.child,
    this.backgroundColor,
    this.showShadow = true,
  });

  final Widget child;
  final Color? backgroundColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = destructive
        ? Colors.redAccent
        : AppColors.textPrimaryOf(context);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: effectiveColor, size: 24),
      title: AppText(
        label,
        variant: AppTextVariant.label,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: effectiveColor,
      ),
    );
  }
}
