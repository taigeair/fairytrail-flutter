import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/theme/app_shadows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fairytrail/widgets/widgets.dart';

enum AppTab { explore, bucketList, meetups, messages, profile }

extension AppTabX on AppTab {
  String get label => switch (this) {
    AppTab.explore => 'Explore',
    AppTab.bucketList => 'List',
    AppTab.meetups => 'Nearby',
    AppTab.messages => 'Messages',
    AppTab.profile => 'Profile',
  };

  String get _assetKey => switch (this) {
    AppTab.explore => 'explore',
    AppTab.bucketList => 'bucketList',
    AppTab.meetups => 'meetups',
    AppTab.messages => 'messages',
    AppTab.profile => 'profile',
  };

  String get iconAsset => 'assets/navbar/$_assetKey.svg';

  String get activeIconAsset => 'assets/navbar/${_assetKey}_active.svg';
}

/// Pure-Flutter floating bottom tab bar used consistently on every platform.
class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({
    super.key,
    required this.current,
    required this.onChanged,
    this.messagesBadge = 0,
    this.showMeetups = true,
  });

  final AppTab current;
  final ValueChanged<AppTab> onChanged;
  final int messagesBadge;
  final bool showMeetups;

  @override
  Widget build(BuildContext context) => _FloatingMaterialNavBar(
    current: current,
    onChanged: onChanged,
    messagesBadge: messagesBadge,
    showMeetups: showMeetups,
  );
}

/// Floating Material-style nav.
///
/// Custom tabs (not Material [NavigationBar]) so the selected pill wraps
/// icon + label together.
class _FloatingMaterialNavBar extends StatelessWidget {
  const _FloatingMaterialNavBar({
    required this.current,
    required this.onChanged,
    this.messagesBadge = 0,
    this.showMeetups = true,
  });

  final AppTab current;
  final ValueChanged<AppTab> onChanged;
  final int messagesBadge;
  final bool showMeetups;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = [
      for (final tab in AppTab.values)
        if (tab != AppTab.meetups || showMeetups) tab,
    ];

    return AppSafeArea(
      top: false,
      child: Padding(
        // Extra top gap so content above doesn't sit flush on the bar (Android).
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: isDark ? AppShadows.softDark : AppShadows.soft,
          ),
          child: Material(
            elevation: 0,
            shadowColor: Colors.transparent,
            color: isDark
                ? const Color(0xFF1E1E1E)
                : scheme.surfaceContainerHigh,
            surfaceTintColor: Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  for (final tab in tabs)
                    Expanded(
                      child: _FloatingNavTab(
                        tab: tab,
                        selected: tab == current,
                        badgeCount: tab == AppTab.messages ? messagesBadge : 0,
                        onTap: () {
                          if (tab != current) HapticsService.selection();
                          onChanged(tab);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavTab extends StatelessWidget {
  const _FloatingNavTab({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected
        ? AppColors.primary
        : (isDark ? scheme.onSurfaceVariant : scheme.onSurface);
    final pill = selected
        ? (isDark
              ? AppColors.primary.withValues(alpha: 0.18)
              : const Color(0xFFE8E8ED))
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: pill,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          splashColor: AppColors.primary.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BadgedNavIcon(
                  asset: selected ? tab.activeIconAsset : tab.iconAsset,
                  badgeCount: badgeCount,
                  color: selected ? AppColors.primary : null,
                ),
                const SizedBox(height: 4),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                    height: 1.1,
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

/// Icon with unread count pinned to the top-right corner.
class _BadgedNavIcon extends StatelessWidget {
  const _BadgedNavIcon({required this.asset, this.badgeCount = 0, this.color});

  final String asset;
  final int badgeCount;
  final Color? color;

  static const _iconSize = 22.0;

  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset(
      asset,
      width: _iconSize,
      height: _iconSize,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
    if (badgeCount <= 0) return icon;

    return SizedBox(
      width: _iconSize + 10,
      height: _iconSize + 6,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          icon,
          Positioned(top: -2, right: -2, child: _UnreadDot(count: badgeCount)),
        ],
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
