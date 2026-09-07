import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Quick access to the filters available on the Messages tab.
class MessagesFilterChipsBar extends StatelessWidget {
  const MessagesFilterChipsBar({
    super.key,
    required this.countryName,
    required this.isLocked,
    required this.onOpenFilters,
  });

  final String? countryName;
  final bool isLocked;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final border = AppColors.borderOf(context);
    final background = AppColors.surfaceOf(context);
    final foreground = AppColors.textPrimaryOf(context);
    final tagBackground = AppColors.textPrimaryOf(
      context,
    ).withValues(alpha: 0.08);
    final tagForeground = AppColors.textSecondaryOf(context);

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterIconButton(
            onTap: onOpenFilters,
            border: border,
            background: background,
            foreground: foreground,
          ),
          const SizedBox(width: 8),
          _LocationFilterPill(
            countryName: countryName,
            isLocked: isLocked,
            onTap: onOpenFilters,
            border: border,
            background: background,
            foreground: foreground,
            tagBackground: tagBackground,
            tagForeground: tagForeground,
          ),
        ],
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({
    required this.onTap,
    required this.border,
    required this.background,
    required this.foreground,
  });

  final VoidCallback onTap;
  final Color border;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: 34,
          height: 30,
          child: Icon(Icons.tune_rounded, size: 18, color: foreground),
        ),
      ),
    );
  }
}

class _LocationFilterPill extends StatelessWidget {
  const _LocationFilterPill({
    required this.countryName,
    required this.isLocked,
    required this.onTap,
    required this.border,
    required this.background,
    required this.foreground,
    required this.tagBackground,
    required this.tagForeground,
  });

  final String? countryName;
  final bool isLocked;
  final VoidCallback onTap;
  final Color border;
  final Color background;
  final Color foreground;
  final Color tagBackground;
  final Color tagForeground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                'Location',
                variant: AppTextVariant.label,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: tagBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppText(
                  countryName ?? 'All',
                  variant: AppTextVariant.label,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tagForeground,
                ),
              ),
              const SizedBox(width: 2),
              if (isLocked)
                Icon(Icons.lock_outline_rounded, size: 14, color: foreground)
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: foreground,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
