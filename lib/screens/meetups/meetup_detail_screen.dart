import 'package:fairytrail/api/meetups.dart';
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/components/meetups/meetup_member_avatar_stack.dart';
import 'package:fairytrail/meetups/meetup_analytics.dart';
import 'package:fairytrail/meetups/meetup_icons.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/meetups/meetup_chat_screen.dart';
import 'package:fairytrail/screens/meetups/meetup_members_screen.dart';
import 'package:fairytrail/screens/meetups/report_meetup_sheet.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MeetupDetailScreen extends StatefulWidget {
  const MeetupDetailScreen({super.key, required this.meetupId, this.initial});

  final int meetupId;
  final MeetupDto? initial;

  static Future<MeetupDto?> open(
    BuildContext context, {
    required int meetupId,
    MeetupDto? initial,
  }) {
    return Navigator.of(context).push<MeetupDto>(
      MaterialPageRoute(
        builder: (_) =>
            MeetupDetailScreen(meetupId: meetupId, initial: initial),
      ),
    );
  }

  @override
  State<MeetupDetailScreen> createState() => _MeetupDetailScreenState();
}

class _MeetupDetailScreenState extends State<MeetupDetailScreen> {
  MeetupDto? _meetup;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _meetup = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final m = await fetchMeetup(widget.meetupId);
      if (mounted) setState(() => _meetup = m);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: serverErrorText(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final current = _meetup;
    if (current != null && current.isFull && !current.joinedByMe) {
      AppToast.show(context, message: 'This meetup is full (500 members max).');
      return;
    }
    setState(() => _busy = true);
    try {
      final wasJoined = current?.joinedByMe ?? false;
      final m = await joinMeetup(widget.meetupId);
      if (!wasJoined) trackJoinedMeetup(m);
      if (!mounted) return;
      setState(() => _meetup = m);
      await MeetupChatScreen.open(context, meetup: m);
      if (mounted) Navigator.pop(context, m);
    } catch (e) {
      if (mounted) AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Leave meetup?',
      message: 'You will leave the group chat for this meetup.',
      confirmLabel: 'Leave',
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await leaveMeetup(widget.meetupId);
      if (!mounted) return;
      MessagesScope.maybeOf(context)?.removeMeetupChat(widget.meetupId);
      final m = _meetup?.copyWith(joinedByMe: false);
      setState(() => _meetup = m);
      Navigator.pop(context, m);
    } catch (e) {
      if (mounted) AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Delete meetup?',
      message: 'This removes it from the map for everyone.',
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await deleteMeetup(widget.meetupId);
      if (mounted) {
        MessagesScope.maybeOf(context)?.removeMeetupChat(widget.meetupId);
        Navigator.pop(context, _meetup?.copyWith(status: 'deleted'));
      }
    } catch (e) {
      if (mounted) AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report() async {
    final m = _meetup;
    if (m == null) return;
    final reported = await showReportMeetupSheet(context, meetupId: m.id);
    if (!reported || !mounted) return;
    await MessagesScope.maybeOf(context)?.leaveMeetupChat(m.id);
    if (mounted) Navigator.pop(context, m);
  }

  @override
  Widget build(BuildContext context) {
    final m = _meetup;
    final pageBg = AppColors.backgroundOf(context);
    final secondary = AppColors.textSecondaryOf(context);

    if (_loading && m == null) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: pageBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text('Meetup'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (m == null) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: pageBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text('Meetup'),
        ),
        body: const AppEmptyView(title: 'Meetup not found'),
      );
    }

    final when = DateFormat.MMMd().add_jm().format(m.startsAt.toLocal());
    final memberCount = m.memberCount;
    final membersLabel = memberCount == 1
        ? '1 person going'
        : '$memberCount people going';
    final avatars = meetupAvatarUrls(fromMeetup: m.avatars);
    final extraGoing = memberCount > avatars.length
        ? memberCount - avatars.length
        : 0;
    final goingTitle = avatars.isEmpty
        ? membersLabel
        : extraGoing > 0
        ? '$memberCount going · +$extraGoing more'
        : membersLabel;
    final distanceLine = m.distanceKm != null
        ? '${m.distanceKm!.toStringAsFixed(1)} km away'
        : null;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Meetup'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (m.isExpired)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InfoCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppText(
                    'This meetup has ended. Chat history may still be available.',
                    variant: AppTextVariant.bodySmall,
                    color: secondary,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          _InfoCard(
            backgroundColor: pageBg,
            showShadow: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: [
                  Text(
                    meetupCategoryEmoji(m.category),
                    style: const TextStyle(fontSize: 72, height: 1),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    m.name,
                    variant: AppTextVariant.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    '${m.category.label} · $when',
                    variant: AppTextVariant.body,
                    color: secondary,
                    textAlign: TextAlign.center,
                  ),
                  if (distanceLine != null) ...[
                    const SizedBox(height: 4),
                    AppText(
                      distanceLine,
                      variant: AppTextVariant.caption,
                      color: secondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
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
          _GoingCard(
            avatars: avatars,
            title: goingTitle,
            onTap: () => MeetupMembersScreen.open(
              context,
              meetupId: m.id,
              title: m.name,
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            child: Column(
              children: [
                if (m.joinedByMe)
                  _ActionTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Open chat',
                    onTap: _busy
                        ? null
                        : () => MeetupChatScreen.open(context, meetup: m),
                  )
                else if (m.isActive)
                  _ActionTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: _busy
                        ? 'Joining…'
                        : m.isFull
                        ? 'Meetup full'
                        : 'Join chat',
                    onTap: _busy || m.isFull ? null : _join,
                  ),
                if (m.joinedByMe && !m.isCreator) ...[
                  Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.borderOf(context),
                  ),
                  _ActionTile(
                    icon: Icons.logout,
                    label: _busy ? 'Leaving…' : 'Leave meetup',
                    onTap: _busy ? null : _leave,
                  ),
                ],
                if (m.isCreator && m.status != 'deleted') ...[
                  Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.borderOf(context),
                  ),
                  _ActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete meetup',
                    destructive: true,
                    onTap: _busy ? null : _delete,
                  ),
                ],
                if (!m.isCreator) ...[
                  Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.borderOf(context),
                  ),
                  _ActionTile(
                    icon: Icons.flag_outlined,
                    label: 'Report meetup',
                    destructive: true,
                    onTap: _busy ? null : _report,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoingCard extends StatelessWidget {
  const _GoingCard({
    required this.avatars,
    required this.title,
    required this.onTap,
  });

  final List<String> avatars;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryOf(context);
    final isDark = AppColors.isDark(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                MeetupMemberAvatarStack(
                  avatars: avatars,
                  size: 32,
                  overlap: 20,
                  placeholderSize: 56,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        title,
                        variant: AppTextVariant.label,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      const SizedBox(height: 2),
                      AppText(
                        'Joined members',
                        variant: AppTextVariant.caption,
                        color: secondary,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: secondary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    final color = destructive
        ? Colors.redAccent
        : AppColors.textPrimaryOf(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: color, size: 24),
      title: AppText(
        label,
        variant: AppTextVariant.label,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: color,
      ),
    );
  }
}
