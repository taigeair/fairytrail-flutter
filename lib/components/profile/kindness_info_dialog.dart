import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class KindnessInfoIcon extends StatelessWidget {
  const KindnessInfoIcon({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'What is kindness?',
      child: InkResponse(
        onTap: () => showKindnessInfoDialog(context),
        radius: 12,
        child: Icon(Icons.info_outline_rounded, size: 17, color: color),
      ),
    );
  }
}

Future<void> showKindnessInfoDialog(BuildContext context) {
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
                    color: Theme.of(
                      ctx,
                    ).colorScheme.outline.withValues(alpha: 0.35),
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
                'What is kindness?',
                variant: AppTextVariant.title,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              AppText(
                'Kindness points are awarded by fellow travelers or automatically by our system for positive community contributions',
                variant: AppTextVariant.body,
                color: muted,
              ),
              const SizedBox(height: 20),
              AppButton(label: 'Got it', onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      );
    },
  );
}
