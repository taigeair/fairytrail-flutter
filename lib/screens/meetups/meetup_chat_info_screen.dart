import 'package:fairytrail/api/meetups.dart';
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/components/meetups/meetup_member_avatar_stack.dart';
import 'package:fairytrail/meetups/meetup_chat_close.dart';
import 'package:fairytrail/meetups/meetup_icons.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/meetups/meetup_members_screen.dart';
import 'package:fairytrail/screens/meetups/report_meetup_sheet.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Meetup group-chat info — header + leave/report (members) or delete (owner).
///
/// Pops with [MeetupChatClose.deleted], [MeetupChatClose.left], or
/// [MeetupChatClose.reported] when the meetup should leave the map/inbox.
class MeetupChatInfoScreen extends StatefulWidget {
  const MeetupChatInfoScreen({super.key, required this.meetup});

  final MeetupDto meetup;

  static Future<MeetupChatCloseResult?> open(
    BuildContext context, {
    required MeetupDto meetup,
  }) {
    return Navigator.of(context).push<MeetupChatCloseResult>(
      MaterialPageRoute(builder: (_) => MeetupChatInfoScreen(meetup: meetup)),
    );
  }

  @override
  State<MeetupChatInfoScreen> createState() => _MeetupChatInfoScreenState();
}

class _MeetupChatInfoScreenState extends State<MeetupChatInfoScreen> {
  late MeetupDto _meetup;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _meetup = widget.meetup;
  }

  void _openMembers() {
    MeetupMembersScreen.open(
      context,
      meetupId: _meetup.id,
      title: _meetup.name,
    );
  }

  Future<void> _leave() async {
    if (_busy || _meetup.isCreator) return;
    final ok = await AppDialog.confirm(
      context,
      title: 'Leave meetup?',
      message: 'You’ll leave this meetup group chat.',
      confirmLabel: 'Leave',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await leaveMeetup(_meetup.id);
      MessagesScope.maybeOf(context)?.removeMeetupChat(_meetup.id);
      if (mounted) Navigator.of(context).pop(MeetupChatClose.left);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _delete() async {
    if (_busy || !_meetup.isCreator) return;
    final ok = await AppDialog.confirm(
      context,
      title: 'Delete meetup?',
      message: 'This removes it from the map for everyone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await deleteMeetup(_meetup.id);
      MessagesScope.maybeOf(context)?.removeMeetupChat(_meetup.id);
      if (mounted) Navigator.of(context).pop(MeetupChatClose.deleted);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _report() async {
    if (_busy || _meetup.isCreator) return;
    final reported = await showReportMeetupSheet(context, meetupId: _meetup.id);
    if (!reported || !mounted) return;
    final messages = MessagesScope.maybeOf(context);
    await messages?.leaveMeetupChat(_meetup.id);
    if (mounted) Navigator.of(context).pop(MeetupChatClose.reported);
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = AppColors.backgroundOf(context);
    final secondary = AppColors.textSecondaryOf(context);
    final when = DateFormat.MMMd().add_jm().format(_meetup.startsAt.toLocal());
    final memberCount = _meetup.memberCount;
    final membersLabel = memberCount == 1
        ? '1 chat member'
        : '$memberCount chat members';
    final avatars = meetupAvatarUrls(fromMeetup: _meetup.avatars);
    final isOwner = _meetup.isCreator;
    final canDelete = isOwner && _meetup.status != 'deleted';

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Meetup info'),
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
                  Text(
                    meetupCategoryEmoji(_meetup.category),
                    style: const TextStyle(fontSize: 72, height: 1),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    _meetup.name,
                    variant: AppTextVariant.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    '${_meetup.category.label} · $when',
                    variant: AppTextVariant.body,
                    color: secondary,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MembersCard(
            avatars: avatars,
            title: membersLabel,
            onTap: _openMembers,
          ),
          if (!isOwner || canDelete) ...[
            const SizedBox(height: 12),
            _InfoCard(
              child: Column(
                children: [
                  if (!isOwner)
                    _ActionTile(
                      icon: Icons.logout,
                      label: _busy ? 'Leaving…' : 'Leave meetup',
                      onTap: _busy ? null : _leave,
                    ),
                  if (!isOwner) ...[
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
                  if (canDelete)
                    _ActionTile(
                      icon: Icons.delete_outline_rounded,
                      label: _busy ? 'Deleting…' : 'Delete meetup',
                      destructive: true,
                      onTap: _busy ? null : _delete,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({
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
                  placeholderSize: 48,
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
                        'Chat members',
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
