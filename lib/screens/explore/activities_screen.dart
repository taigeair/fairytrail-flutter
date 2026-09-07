import 'package:fairytrail/activities/activities_controller.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/components/activities/activity_card.dart';
import 'package:fairytrail/components/activities/report_activity_sheet.dart';
import 'package:fairytrail/components/activities/saved_explorers_sheet.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/screens/explore/activity_search_screen.dart';
import 'package:fairytrail/screens/messages/activity_chat_screen.dart';
import 'package:fairytrail/screens/messages/activity_chat_info_screen.dart';
import 'package:fairytrail/screens/profile/profile_view_screen.dart';
import 'package:fairytrail/screens/shell/floating_bottom_nav.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Explore → Activities feed.
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({
    super.key,
    required this.controller,
    this.isActive = false,
    this.popularRequest = 0,
  });

  /// Shared feed controller — owned by [ExploreScreen] so home can warm-load.
  final ActivitiesController controller;

  /// When hosted in Explore's [TabBarView], true only for the Activities tab.
  final bool isActive;
  final int popularRequest;

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  double _lastScrollOffset = 0;
  double _hideStartOffset = 0;

  ActivitiesController get _controller => widget.controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ActivitiesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    if (widget.popularRequest != oldWidget.popularRequest &&
        _controller.sortBy != ActivitiesSortBy.trending) {
      _controller.setSortBy(ActivitiesSortBy.trending);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !widget.isActive) return;
    final offset = _scrollController.offset.clamp(0.0, double.infinity);
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;
    final chrome = ShellChromeScope.maybeOf(context);
    if (chrome == null) return;

    if (offset <= 0 || delta < 0) {
      _hideStartOffset = offset;
      chrome.setHideProgress(0);
      return;
    }

    if (delta == 0) return;
    const scrollForFullHide = 56.0;
    chrome.setHideProgress((offset - _hideStartOffset) / scrollForFullHide);
  }

  Future<void> _joinChat(ActivityDto activity) async {
    final messages = MessagesScope.maybeOf(context);
    if (messages == null) {
      AppToast.show(context, message: 'Messages unavailable');
      return;
    }
    ShellChromeScope.maybeOf(context)?.selectTab(AppTab.messages);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityChatScreen(
          controller: messages,
          activityId: activity.id,
          previewActivity: activity,
        ),
      ),
    );
    messages.closeThread();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onBookmark(int id) async {
    HapticsService.selection();
    try {
      await _controller.toggleSave(id);
    } catch (e) {
      if (mounted) AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _openSavedExplorers(ActivityDto activity) async {
    final profileId = await showSavedExplorersSheet(
      context,
      activity: activity,
    );
    if (!mounted || profileId == null) return;
    await ProfileViewScreen.open(
      context,
      profileId: profileId,
      from: 'trailbook',
    );
  }

  Future<void> _openActivityInfo(ActivityDto activity) async {
    HapticsService.selection();
    final heroTag = 'activity-image-${activity.id}';
    await ActivityChatInfoScreen.openActivity(
      context,
      activity: activity,
      controller: MessagesScope.maybeOf(context),
      onJoinChat: () => _joinChat(activity),
      onSave: activity.isSaved
          ? null
          : () => _controller.toggleSave(activity.id),
      heroTag: heroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final chrome = ShellChromeScope.maybeOf(context);
    final bottomPad = MediaQueryData.fromView(
      View.of(context),
    ).viewPadding.bottom;
    final navHeight =
        chrome?.bottomNavHeightOr(50 + bottomPad) ?? (50 + bottomPad);
    final listBottom = navHeight + 16;
    final background = Theme.of(context).scaffoldBackgroundColor;

    return ColoredBox(
      color: background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildFeed(listBottom),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ListenableBuilder(
              listenable: Listenable.merge([?chrome]),
              builder: (context, child) {
                final visibility = (1.0 - (chrome?.hideProgress ?? 0)).clamp(
                  0.0,
                  1.0,
                );
                return IgnorePointer(
                  ignoring: visibility < 0.1,
                  child: Opacity(
                    opacity: visibility,
                    child: Transform.translate(
                      offset: Offset(0, (1 - visibility) * -40),
                      child: child,
                    ),
                  ),
                );
              },
              child: Material(color: background, child: _buildChipsBar()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: SizedBox(
        height: 34,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _SortPill(
                label: 'Popular',
                selected: _controller.sortBy == ActivitiesSortBy.trending,
                onTap: () {
                  if (_controller.sortBy == ActivitiesSortBy.trending) return;
                  HapticsService.selection();
                  _controller.setSortBy(ActivitiesSortBy.trending);
                },
              ),
              const SizedBox(width: 8),
              _SortPill(
                label: 'New',
                selected: _controller.sortBy == ActivitiesSortBy.newest,
                onTap: () {
                  if (_controller.sortBy == ActivitiesSortBy.newest) return;
                  HapticsService.selection();
                  _controller.setSortBy(ActivitiesSortBy.newest);
                },
              ),
              const Spacer(),
              _SearchIconButton(
                onTap: () {
                  HapticsService.selection();
                  ActivitySearchScreen.open(context, controller: _controller);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeed(double listBottom) {
    if (_controller.loading && _controller.activities.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_controller.error != null && _controller.activities.isEmpty) {
      return AppEmptyView(
        title: "Couldn't load activities",
        subtitle: _controller.error,
        icon: Icons.wifi_off_outlined,
        actionLabel: 'Retry',
        onAction: _controller.refresh,
      );
    }
    if (_controller.isEmpty) {
      return const AppEmptyView(
        title: 'No activities yet',
        subtitle:
            'When explorers share bucket list activities, they’ll show up here.',
        icon: Icons.hiking_outlined,
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _controller.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240 &&
              _controller.hasMore &&
              !_controller.loadingMore) {
            _controller.loadMore();
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          // Chips header is 52px tall; the card adds its own 8px top margin.
          padding: EdgeInsets.only(top: 52, bottom: listBottom),
          itemCount:
              _controller.activities.length + (_controller.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _controller.activities.length) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }
            final activity = _controller.activities[index];
            return ActivityCard(
              title: activity.displayTitle,
              imageUrl: activity.photo.url,
              savedCount: activity.explorerCount,
              isSaved: activity.isSaved,
              avatars: activity.avatars,
              heroTag: 'activity-image-${activity.id}',
              onJoinChat: () => _joinChat(activity),
              onImageTap: () => _openActivityInfo(activity),
              onBookmark: () => _onBookmark(activity.id),
              onMoreOptions: () async {
                final reported = await showActivityOptionsSheet(
                  context,
                  activityId: activity.id,
                  title: activity.displayTitle,
                );
                if (reported) {
                  await _controller.dismissReported(activity.id);
                }
              },
              onSavedPress: () => _openSavedExplorers(activity),
            );
          },
        ),
      ),
    );
  }
}

class _SearchIconButton extends StatelessWidget {
  const _SearchIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkBorder : const Color(0xFFE0E0E0);
    final background = isDark ? AppColors.darkSurface : AppColors.white;
    final foreground = Theme.of(context).colorScheme.onSurface;

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
          width: 160,
          height: 30,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 18, color: foreground),
                const SizedBox(width: 6),
                AppText(
                  'Iceland, Safari, ...',
                  variant: AppTextVariant.label,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryOf(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = selected
        ? AppColors.primary
        : isDark
        ? AppColors.darkBorder
        : const Color(0xFFE0E0E0);
    final background = selected
        ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08)
        : isDark
        ? AppColors.darkSurface
        : AppColors.white;
    final foreground = selected
        ? AppColors.primary
        : Theme.of(context).colorScheme.onSurface;

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
          height: 30,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: AppText(
                label,
                variant: AppTextVariant.label,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
