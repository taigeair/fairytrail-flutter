import 'package:fairytrail/api/explore.dart';
import 'package:fairytrail/components/explore/explore_profile_actions.dart';
import 'package:fairytrail/moderation/local_moderation.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

Future<String?> showMatchChatOptionsSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              _SheetItem(
                icon: Icons.person_outline,
                label: 'View profile',
                onTap: () => Navigator.pop(ctx, 'profile'),
              ),
              _SheetItem(
                icon: Icons.mail_outline,
                label: 'Inspire',
                onTap: () => Navigator.pop(ctx, 'care'),
              ),
              _SheetItem(
                icon: Icons.cancel_outlined,
                label: 'Remove connection',
                onTap: () => Navigator.pop(ctx, 'unmatch'),
              ),
              _SheetItem(
                icon: Icons.flag_outlined,
                label: 'Block & report',
                destructive: true,
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
              _SheetItem(
                icon: Icons.block_outlined,
                label: 'Block only',
                destructive: true,
                onTap: () => Navigator.pop(ctx, 'block'),
              ),
              _SheetItem(
                label: 'Cancel',
                muted: true,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> showMeetupChatOptionsSheet(
  BuildContext context, {
  bool isCreator = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              _SheetItem(
                icon: Icons.info_outline,
                label: 'Meetup info',
                onTap: () => Navigator.pop(ctx, 'info'),
              ),
              if (isCreator)
                _SheetItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete meetup',
                  destructive: true,
                  onTap: () => Navigator.pop(ctx, 'delete'),
                )
              else ...[
                _SheetItem(
                  icon: Icons.flag_outlined,
                  label: 'Report meetup',
                  destructive: true,
                  onTap: () => Navigator.pop(ctx, 'report'),
                ),
                _SheetItem(
                  icon: Icons.logout,
                  label: 'Leave meetup',
                  onTap: () => Navigator.pop(ctx, 'leave'),
                ),
              ],
              _SheetItem(
                label: 'Cancel',
                muted: true,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> showActivityChatOptionsSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              _SheetItem(
                icon: Icons.info_outline,
                label: 'View activity',
                onTap: () => Navigator.pop(ctx, 'info'),
              ),
              _SheetItem(
                icon: Icons.flag_outlined,
                label: 'Report activity',
                destructive: true,
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
              _SheetItem(
                icon: Icons.logout,
                label: 'Leave chat',
                onTap: () => Navigator.pop(ctx, 'leave'),
              ),
              _SheetItem(
                label: 'Cancel',
                muted: true,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// RN `UserOptionsBottomSheet` — tap a group-chat sender.
Future<String?> showActivityUserOptionsSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              _SheetItem(
                icon: Icons.person_outline,
                label: 'View profile',
                onTap: () => Navigator.pop(ctx, 'profile'),
              ),
              _SheetItem(
                icon: Icons.flag_outlined,
                label: 'Block & report',
                destructive: true,
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
              _SheetItem(
                icon: Icons.block_outlined,
                label: 'Block only',
                destructive: true,
                onTap: () => Navigator.pop(ctx, 'block'),
              ),
              _SheetItem(
                label: 'Cancel',
                muted: true,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Re-export report flow used from chat menus.
Future<bool> reportProfileFromChat(
  BuildContext context, {
  required int profileId,
}) {
  return showReportProfileSheet(context, profileId: profileId);
}

/// RN activity-chat block flow: check status → report sheet.
///
/// Returns `true` if a new report was submitted, or the user was already blocked
/// (caller should hide their messages either way).
Future<bool> blockAndReportFromChat(
  BuildContext context, {
  required int profileId,
}) async {
  try {
    final status = await getProfileStatus(profileId);
    if (!context.mounted) return false;
    if (status == 'blocked') {
      await LocalModeration.instance.blockProfile(profileId);
      if (!context.mounted) return true;
      await AppDialog.show(
        context,
        title: 'Already Blocked',
        message: 'You have already blocked this user.',
      );
      return true;
    }
  } catch (_) {
    // Proceed with report if status check fails (same as RN).
  }

  if (!context.mounted) return false;
  return showReportProfileSheet(context, profileId: profileId);
}

Future<bool> blockOnlyFromChat(
  BuildContext context, {
  required int profileId,
}) async {
  try {
    final status = await getProfileStatus(profileId);
    if (!context.mounted) return false;
    if (status == 'blocked') {
      await LocalModeration.instance.blockProfile(profileId);
      if (!context.mounted) return true;
      await AppDialog.show(
        context,
        title: 'Already blocked',
        message: 'You have already blocked this user.',
      );
      return true;
    }
  } catch (_) {
    // Proceed with the block if the status check fails.
  }

  if (!context.mounted) return false;
  return blockProfileOnly(context, profileId: profileId);
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.destructive = false,
    this.muted = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool destructive;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Colors.redAccent
        : muted
        ? AppColors.textSecondaryOf(context)
        : AppColors.textPrimaryOf(context);

    return ListTile(
      leading: icon == null
          ? null
          : Icon(
              icon,
              color: destructive ? Colors.redAccent : AppColors.primary,
            ),
      title: AppText(
        label,
        variant: AppTextVariant.label,
        fontWeight: FontWeight.w600,
        fontSize: 17,
        color: color,
      ),
      onTap: onTap,
    );
  }
}
