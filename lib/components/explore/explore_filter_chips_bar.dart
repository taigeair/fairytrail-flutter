import 'package:fairytrail/config/explore_options.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/config/signup_options.dart';
import 'package:fairytrail/explore/explore_controller.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Filter icon + quick-access People filter chips.
class ExploreFilterChipsBar extends StatelessWidget {
  const ExploreFilterChipsBar({
    super.key,
    required this.controller,
    required this.onOpenMore,
    required this.onOpenNearMe,
    required this.onOpenLocation,
    required this.onOpenIdentity,
    required this.onOpenNextDestination,
    required this.onOpenRecentlyActive,
  });

  final ExploreController controller;
  final VoidCallback onOpenMore;
  final VoidCallback onOpenNearMe;
  final VoidCallback onOpenLocation;
  final VoidCallback onOpenIdentity;
  final VoidCallback onOpenNextDestination;
  final VoidCallback onOpenRecentlyActive;

  @override
  Widget build(BuildContext context) {
    final prefs = controller.prefs;
    final usingRadius = prefs.radiusMiles != null && prefs.radiusMiles! > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0);
    final bg = isDark ? AppColors.darkSurface : AppColors.white;
    final fg = Theme.of(context).colorScheme.onSurface;
    final tagBg = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFF0F0F0);
    final tagFg = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterIconButton(
            onTap: onOpenMore,
            border: border,
            bg: bg,
            fg: fg,
            showBadge: false,
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: 'Location',
            tag: usingRadius
                ? 'Off'
                : _countOrAll(prefs.currentCountries.length),
            onTap: onOpenLocation,
            border: border,
            bg: bg,
            fg: fg,
            tagBg: tagBg,
            tagFg: tagFg,
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: 'Destination',
            tag: usingRadius
                ? 'Off'
                : _countOrAll(prefs.upcomingCountries.length),
            onTap: onOpenNextDestination,
            border: border,
            bg: bg,
            fg: fg,
            tagBg: tagBg,
            tagFg: tagFg,
          ),
          const SizedBox(width: 8),
          _FilterPill(
            label: 'Near me',
            tag: labelForRadiusMiles(prefs.radiusMiles),
            onTap: onOpenNearMe,
            border: border,
            bg: bg,
            fg: fg,
            tagBg: tagBg,
            tagFg: tagFg,
            locked: !AuthScope.of(context).isGold,
          ),
          const SizedBox(width: 8),
          // _FilterPill(
          //   label: 'Lifestyle',
          //   tag: _identityTag(prefs.travelStyles),
          //   onTap: onOpenIdentity,
          //   border: border,
          //   bg: bg,
          //   fg: fg,
          //   tagBg: tagBg,
          //   tagFg: tagFg,
          //   locked: !AuthScope.of(context).isGold,
          // ),
          // const SizedBox(width: 8),
          _FilterPill(
            label: 'Recently active',
            tag: labelForRecentlyActiveWeeks(prefs.recentlyActiveWeeks),
            onTap: onOpenRecentlyActive,
            border: border,
            bg: bg,
            fg: fg,
            tagBg: tagBg,
            tagFg: tagFg,
            locked: !AuthScope.of(context).isGold,
          ),
        ],
      ),
    );
  }

  String _countOrAll(int count) => count == 0 ? 'All' : '$count';

  String _identityTag(List<String> styles) {
    if (styles.isEmpty || styles.length >= exploreTravelStyleOptions.length) {
      return 'All';
    }
    return '${styles.length}';
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({
    required this.onTap,
    required this.border,
    required this.bg,
    required this.fg,
    required this.showBadge,
  });

  final VoidCallback onTap;
  final Color border;
  final Color bg;
  final Color fg;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.tune_rounded, size: 18, color: fg),
              if (showBadge)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.tag,
    required this.onTap,
    required this.border,
    required this.bg,
    required this.fg,
    required this.tagBg,
    required this.tagFg,
    this.locked = false,
  });

  final String label;
  final String tag;
  final VoidCallback onTap;
  final Color border;
  final Color bg;
  final Color fg;
  final Color tagBg;
  final Color tagFg;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
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
                label,
                variant: AppTextVariant.label,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppText(
                  tag,
                  variant: AppTextVariant.label,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tagFg,
                ),
              ),
              const SizedBox(width: 2),
              if (locked)
                Icon(Icons.lock_outline_rounded, size: 14, color: fg)
              else
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
