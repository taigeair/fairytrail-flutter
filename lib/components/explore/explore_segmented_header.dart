import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';

enum ExploreTopTab { people, activities }

extension ExploreTopTabX on ExploreTopTab {
  String get label => switch (this) {
    ExploreTopTab.people => 'People',
    ExploreTopTab.activities => 'Activities',
  };
}

/// Explore top pills: People | Activities.
class ExploreSegmentedHeader extends StatelessWidget {
  const ExploreSegmentedHeader({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ExploreTopTab selected;
  final ValueChanged<ExploreTopTab> onChanged;

  static const height = 48.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = isDark
        ? AppColors.darkBorder
        : const Color(0xFFD8D8D8);

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final tab in ExploreTopTab.values) ...[
              if (tab != ExploreTopTab.values.first) const SizedBox(width: 12),
              _Pill(
                label: tab.label,
                selected: selected == tab,
                unselectedBg: unselectedBg,
                onTap: () {
                  if (selected == tab) return;
                  HapticsService.selection();
                  onChanged(tab);
                },
              ),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Image.asset(
                  'assets/home/logo.png',
                  height: 30,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.unselectedBg,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color unselectedBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : unselectedBg,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: AppText(
            label,
            variant: AppTextVariant.label,
            color: AppColors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
