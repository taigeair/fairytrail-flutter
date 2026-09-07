import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Compact bucket-list card (photo + title + chevron).
class BucketListRow extends StatelessWidget {
  const BucketListRow({
    super.key,
    required this.activity,
    this.onTap,
    this.isDragging = false,
    this.isDropTarget = false,
    this.completed = false,
  });

  final ActivityDto activity;
  final VoidCallback? onTap;
  final bool isDragging;
  final bool isDropTarget;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accent = AppColors.primary;
    // Elevated surface so cards separate from the dark wash (was #252525).
    final surface = isDark ? const Color(0xFF2A2A32) : AppColors.white;
    final country = activity.country?.country;
    final showCountry = country != null && country.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDragging || isDropTarget
              ? accent.withValues(alpha: isDropTarget ? 0.9 : 0.5)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : AppColors.primary.withValues(alpha: 0.06)),
          width: isDragging || isDropTarget ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: isDark ? 0.28 : 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : (isDark
                  ? const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x0F1A1A2E),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Color(0x061A1A2E),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ]),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: accent.withValues(alpha: 0.08),
          highlightColor: accent.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isDark
                        ? null
                        : const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: AppCachedImage(
                    url: activity.photo.displayUrl.isNotEmpty
                        ? activity.photo.displayUrl
                        : activity.photo.url,
                    width: 56,
                    height: 56,
                    borderRadius: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        activity.name.isNotEmpty
                            ? activity.name
                            : activity.displayTitle,
                        variant: AppTextVariant.bodySmall,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        maxLines: showCountry ? 2 : 2,
                        color: completed
                            ? AppColors.textSecondaryOf(context)
                            : AppColors.textPrimaryOf(context),
                      ),
                      if (showCountry) ...[
                        const SizedBox(height: 2),
                        AppText(
                          country,
                          variant: AppTextVariant.caption,
                          color: AppColors.textSecondaryOf(context),
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : AppColors.primary.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: completed
                        ? AppColors.textSecondaryOf(context)
                        : accent.withValues(alpha: isDark ? 0.9 : 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft placeholder shown while dragging toward another section.
class BucketListDropPlaceholder extends StatelessWidget {
  const BucketListDropPlaceholder({
    super.key,
    required this.active,
    this.pointingUp = false,
  });

  final bool active;
  final bool pointingUp;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accent = AppColors.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? accent.withValues(alpha: isDark ? 0.18 : 0.10)
            : (isDark
                  ? const Color(0xFF2A2A32)
                  : AppColors.white.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? accent
              : (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : accent.withValues(alpha: 0.28)),
          width: active ? 2 : 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            pointingUp
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 18,
            color: active
                ? accent
                : AppColors.textSecondaryOf(context),
          ),
          const SizedBox(width: 8),
          AppText(
            'Drop here',
            variant: AppTextVariant.label,
            fontWeight: FontWeight.w600,
            color: active
                ? accent
                : AppColors.textSecondaryOf(context),
          ),
        ],
      ),
    );
  }
}
