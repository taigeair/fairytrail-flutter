import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppSlidingTab {
  const AppSlidingTab({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Shared two-or-more option sliding tab control.
class AppSlidingTabs extends StatelessWidget {
  const AppSlidingTabs({
    required this.controller,
    required this.tabs,
    super.key,
  });

  final TabController controller;
  final List<AppSlidingTab> tabs;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final inactive = AppColors.textPrimaryOf(context);
    final track = AppColors.isDark(context)
        ? AppColors.darkSurface
        : const Color(0xFFF0F0F3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TabBar(
          controller: controller,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorAnimation: TabIndicatorAnimation.elastic,
          indicator: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(8),
          ),
          indicatorPadding: EdgeInsets.zero,
          dividerHeight: 0,
          labelPadding: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          labelColor: onPrimary,
          unselectedLabelColor: inactive,
          onTap: (_) => HapticsService.selection(),
          tabs: [
            for (final tab in tabs)
              Tab(
                height: 38,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tab.icon, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      tab.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
