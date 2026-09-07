import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared link to the explorers who saved an activity.
class SavedByExplorersCard extends StatelessWidget {
  const SavedByExplorersCard({
    super.key,
    required this.explorerCount,
    required this.onTap,
  });

  final int explorerCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondaryOf(context);
    final formattedCount = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(explorerCount);
    final title = explorerCount == 1
        ? 'Saved by 1 explorer'
        : 'Saved by $formattedCount explorers';
    final isDark = AppColors.isDark(context);

    return DecoratedBox(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bookmark_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
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
                        'Who wants to go? Tap to see',
                        variant: AppTextVariant.caption,
                        color: secondary,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 28,
                  color: secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
