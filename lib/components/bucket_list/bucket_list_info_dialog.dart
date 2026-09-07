import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

Future<void> showBucketListInfoDialog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final muted = AppColors.textSecondaryOf(ctx);
      return AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ),
              const AppText(
                "What's bucket list about?",
                variant: AppTextVariant.title,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              AppText(
                'Bucket list helps people understand what you want to do and '
                "what you've already done. Create activities for your bucket "
                "list or save activities from other people's lists on Explore.",
                variant: AppTextVariant.body,
                color: muted,
              ),
              const SizedBox(height: 20),
              const AppText(
                'How do I find bucket list activities?',
                variant: AppTextVariant.title,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              AppText(
                'Explore → Activities. Tap bookmark to save an '
                'activity to your bucket list.',
                variant: AppTextVariant.body,
                color: muted,
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Got it',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    },
  );
}
