import 'package:fairytrail/activities/activity_share.dart';
import 'package:fairytrail/api/activities.dart';
import 'package:fairytrail/moderation/local_moderation.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Report reasons for an Explore activity (RN ReportActivityBottomSheet).
///
/// Returns `true` when the report was submitted successfully.
Future<bool> showReportActivitySheet(
  BuildContext context, {
  required int activityId,
}) async {
  const reasons = <(String, String)>[
    ('distasteful', 'Distasteful'),
    ('fake', 'Fake or scam'),
    ('other', 'Other'),
  ];

  final reason = await showModalBottomSheet<String>(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      ctx,
                    ).colorScheme.outline.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: AppText(
                  "What's wrong?",
                  variant: AppTextVariant.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final r in reasons)
                ListTile(
                  title: AppText(
                    r.$2,
                    variant: AppTextVariant.label,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                  onTap: () => Navigator.pop(ctx, r.$1),
                ),
              ListTile(
                title: AppText(
                  'Cancel',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: AppColors.textSecondaryOf(ctx),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (reason == null || !context.mounted) return false;

  try {
    await reportActivity(activityId: activityId, reason: reason);
    await LocalModeration.instance.reportActivity(activityId);
    if (context.mounted) {
      AppToast.show(
        context,
        message: "Thanks — we'll investigate this activity",
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      AppToast.show(context, message: serverErrorText(e));
    }
    return false;
  }
}

/// Returns `true` when the activity was reported (caller should dismiss it).
Future<bool> showActivityOptionsSheet(
  BuildContext context, {
  required int activityId,
  String? title,
}) async {
  final action = await showModalBottomSheet<String>(
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
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  Icons.ios_share_rounded,
                  color: AppColors.primary,
                ),
                title: const AppText(
                  'Share this activity',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.primary,
                ),
                title: const AppText(
                  'Report this activity',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
              ListTile(
                title: AppText(
                  'Cancel',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: AppColors.textSecondaryOf(ctx),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (!context.mounted) return false;

  if (action == 'share') {
    await ActivityShare.share(
      context,
      activityId: activityId,
      title: title,
    );
    return false;
  }

  if (action != 'report') return false;
  return showReportActivitySheet(context, activityId: activityId);
}
