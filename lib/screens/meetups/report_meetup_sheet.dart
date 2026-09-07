import 'package:fairytrail/api/meetups.dart';
import 'package:fairytrail/moderation/local_moderation.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

Future<bool> showReportMeetupSheet(
  BuildContext context, {
  required int meetupId,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: AppText(
                  "What's wrong with this meetup?",
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
    await reportMeetup(id: meetupId, reason: reason);
    await LocalModeration.instance.reportMeetup(meetupId);
    try {
      await leaveMeetup(meetupId);
    } catch (_) {
      // Creators can't leave their own meetup — inbox still hides via report.
    }
    if (context.mounted) {
      AppToast.show(context, message: 'Thanks — we received your report.');
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      AppToast.show(context, message: "Couldn't send report. Try again.");
    }
    return false;
  }
}
