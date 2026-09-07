import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/bucket_list/bucket_list_controller.dart';
import 'package:fairytrail/components/bucket_list/bucket_list_info_dialog.dart';
import 'package:fairytrail/components/bucket_list/bucket_list_row.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/screens/bucket_list/activity_details_screen.dart';
import 'package:fairytrail/screens/bucket_list/add_edit_activity_screen.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class BucketListScreen extends StatefulWidget {
  const BucketListScreen({super.key, this.isActive = true});

  /// When hosted in [IndexedStack], set true only for the selected tab.
  final bool isActive;

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen> {
  BucketListController? _controller;
  bool _listening = false;
  bool _initialLoadStarted = false;

  /// Tag currently being dragged from (for cross-section drop hint).
  BucketListActivityTag? _draggingFrom;
  int? _hoverSectionIndex;
  BucketListActivityTag? _hoverSectionTag;

  @override
  void didUpdateWidget(covariant BucketListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _ensureLoaded();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profileId = AuthScope.of(context).profileMeta?.id ?? 0;
    if (_controller == null || _controller!.profileId != profileId) {
      _controller?.removeListener(_onChanged);
      _controller?.dispose();
      _controller = BucketListController(profileId: profileId)
        ..addListener(_onChanged);
      _listening = true;
      _initialLoadStarted = false;
      if (widget.isActive) {
        _ensureLoaded();
      }
    } else if (!_listening) {
      _controller!.addListener(_onChanged);
      _listening = true;
    }
  }

  void _ensureLoaded() {
    final c = _controller;
    if (c == null) return;
    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      c.load();
      return;
    }
    // Only refetch when Explore (etc.) marked the list stale — never on every
    // tab switch, and never with a full-screen spinner when we already have data.
    if (BucketListController.stale) {
      c.refresh();
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openDetails(ActivityDto activity) async {
    if (_draggingFrom != null) return;
    HapticsService.selection();
    final removed = await ActivityDetailsScreen.open(context, activity);
    if (!mounted) return;
    if (removed == true) {
      _controller?.removeActivity(activity.id);
    } else {
      await _controller?.refresh();
    }
  }

  Future<void> _onAdd() async {
    HapticsService.light();
    await AddEditActivityScreen.open(context);
    if (mounted) await _controller?.refresh();
  }

  void _onDragStarted(ActivityDto activity) {
    HapticsService.medium();
    setState(() {
      _draggingFrom = activity.tag;
      _hoverSectionIndex = null;
      _hoverSectionTag = null;
    });
  }

  void _onDragEnded() {
    if (!mounted) return;
    setState(() {
      _draggingFrom = null;
      _hoverSectionIndex = null;
      _hoverSectionTag = null;
    });
  }

  Future<void> _acceptDrop({
    required ActivityDto activity,
    required BucketListActivityTag targetTag,
    required int toIndex,
  }) async {
    final controller = _controller;
    if (controller == null) return;

    try {
      if (activity.tag == targetTag) {
        final section = targetTag == BucketListActivityTag.currentYear
            ? controller.currentYear
            : controller.upcoming;
        final fromIndex = section.indexWhere((a) => a.id == activity.id);
        if (fromIndex < 0) return;

        // Adjust index when moving down within the same list.
        var adjusted = toIndex;
        if (fromIndex < toIndex) adjusted = toIndex - 1;
        if (fromIndex == adjusted) {
          HapticsService.selection();
          return;
        }
        HapticsService.light();
        controller.reorderWithinTag(
          tag: targetTag,
          fromIndex: fromIndex,
          toIndex: adjusted.clamp(0, section.length - 1),
        );
      } else {
        HapticsService.medium();
        await controller.moveToTag(activity, targetTag, toIndex: toIndex);
      }
    } catch (e) {
      if (mounted) AppToast.show(context, message: serverErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final chrome = ShellChromeScope.maybeOf(context);
    final bottomPad = MediaQueryData.fromView(
      View.of(context),
    ).viewPadding.bottom;
    final navHeight =
        chrome?.bottomNavHeightOr(50 + bottomPad) ?? (50 + bottomPad);
    final scrollBottom = navHeight + 72;
    // Clear the floating nav pill with a visible gap above it.
    final fabBottom = (navHeight - bottomPad + 28).clamp(0.0, double.infinity);
    final isDark = AppColors.isDark(context);
    final isEmpty = controller?.isEmpty ?? true;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabBottom),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.35 : 0.32,
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: _onAdd,
            elevation: 0,
            highlightElevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ),
      body: AppSafeArea(
        bottom: false,
        child: Column(
          children: [
            _BucketListHeader(
              refreshing: controller?.refreshing ?? false,
              onRefresh: () {
                HapticsService.selection();
                _controller?.refresh();
              },
              onInfo: () {
                HapticsService.selection();
                showBucketListInfoDialog(context);
              },
            ),
            const ConnectivityBannerStrip(),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: isEmpty || !isDark
                        ? null
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: const [
                              Color(0xFF1A1528),
                              AppColors.darkBackground,
                              AppColors.darkBackground,
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                    color: isEmpty
                        ? Theme.of(context).scaffoldBackgroundColor
                        : isDark
                        ? null
                        : AppColors.lightHighlightSurface,
                  ),
                  child:
                      controller == null ||
                          (controller.loading && !controller.hasData)
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : controller.error != null && controller.isEmpty
                      ? AppEmptyView(
                          title: "Couldn't load bucket list",
                          subtitle: controller.error,
                          icon: Icons.wifi_off_outlined,
                          actionLabel: 'Retry',
                          onAction: controller.refresh,
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: controller.refresh,
                          child: ListView(
                            physics: _draggingFrom == null
                                ? const AlwaysScrollableScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              18,
                              22,
                              18,
                              scrollBottom,
                            ),
                            children: [
                              if (controller.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 48),
                                  child: AppEmptyView(
                                    title: 'Your bucket list is empty',
                                    subtitle:
                                        'Tap + to add an activity. Others can see your bucket list activities on your profile and in Explore.',
                                    icon: Icons.checklist_outlined,
                                  ),
                                )
                              else ...[
                                if (controller.currentYear.isNotEmpty ||
                                    controller.upcoming.isNotEmpty) ...[
                                  _DraggableSection(
                                    title: 'This year',
                                    tag: BucketListActivityTag.currentYear,
                                    activities: controller.currentYear,
                                    emptyHint: 'Long press item and drag here',
                                    draggingFrom: _draggingFrom,
                                    hoverIndex:
                                        _hoverSectionTag ==
                                            BucketListActivityTag.currentYear
                                        ? _hoverSectionIndex
                                        : null,
                                    onTap: _openDetails,
                                    onDragStarted: _onDragStarted,
                                    onDragEnded: _onDragEnded,
                                    onHover: (index) {
                                      setState(() {
                                        _hoverSectionTag =
                                            BucketListActivityTag.currentYear;
                                        _hoverSectionIndex = index;
                                      });
                                    },
                                    onLeave: () {
                                      if (_hoverSectionTag ==
                                          BucketListActivityTag.currentYear) {
                                        setState(() {
                                          _hoverSectionIndex = null;
                                          _hoverSectionTag = null;
                                        });
                                      }
                                    },
                                    onAccept: (activity, index) => _acceptDrop(
                                      activity: activity,
                                      targetTag:
                                          BucketListActivityTag.currentYear,
                                      toIndex: index,
                                    ),
                                  ),
                                  _DraggableSection(
                                    title: 'Upcoming',
                                    tag: BucketListActivityTag.upcoming,
                                    activities: controller.upcoming,
                                    emptyHint: 'Long press item and drag here',
                                    draggingFrom: _draggingFrom,
                                    hoverIndex:
                                        _hoverSectionTag ==
                                            BucketListActivityTag.upcoming
                                        ? _hoverSectionIndex
                                        : null,
                                    onTap: _openDetails,
                                    onDragStarted: _onDragStarted,
                                    onDragEnded: _onDragEnded,
                                    onHover: (index) {
                                      setState(() {
                                        _hoverSectionTag =
                                            BucketListActivityTag.upcoming;
                                        _hoverSectionIndex = index;
                                      });
                                    },
                                    onLeave: () {
                                      if (_hoverSectionTag ==
                                          BucketListActivityTag.upcoming) {
                                        setState(() {
                                          _hoverSectionIndex = null;
                                          _hoverSectionTag = null;
                                        });
                                      }
                                    },
                                    onAccept: (activity, index) => _acceptDrop(
                                      activity: activity,
                                      targetTag: BucketListActivityTag.upcoming,
                                      toIndex: index,
                                    ),
                                  ),
                                ],
                                if (controller.completed.isNotEmpty)
                                  _CompletedSection(
                                    activities: controller.completed,
                                    onTap: _openDetails,
                                  ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BucketListHeader extends StatelessWidget {
  const _BucketListHeader({
    required this.onInfo,
    required this.onRefresh,
    this.refreshing = false,
  });

  final VoidCallback onInfo;
  final VoidCallback onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final muted = AppColors.textSecondaryOf(context);
    final buttonStyle = IconButton.styleFrom(
      foregroundColor: isDark ? AppColors.darkTextPrimary : muted,
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : AppColors.primary.withValues(alpha: 0.07),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: refreshing ? null : onRefresh,
            tooltip: 'Refresh',
            style: buttonStyle,
            icon: refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 22),
          ),
          const Expanded(
            child: AppText(
              'Fairytrail Bucket List',
              variant: AppTextVariant.title,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: onInfo,
            tooltip: 'About bucket list',
            style: buttonStyle,
            icon: const Icon(Icons.info_outline_rounded, size: 22),
          ),
        ],
      ),
    );
  }
}

class _DraggableSection extends StatelessWidget {
  const _DraggableSection({
    required this.title,
    required this.tag,
    required this.activities,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onAccept,
    required this.onHover,
    required this.onLeave,
    this.draggingFrom,
    this.hoverIndex,
    this.emptyHint,
  });

  final String title;
  final BucketListActivityTag tag;
  final List<ActivityDto> activities;
  final ValueChanged<ActivityDto> onTap;
  final ValueChanged<ActivityDto> onDragStarted;
  final VoidCallback onDragEnded;
  final Future<void> Function(ActivityDto activity, int toIndex) onAccept;
  final ValueChanged<int> onHover;
  final VoidCallback onLeave;
  final BucketListActivityTag? draggingFrom;
  final int? hoverIndex;
  final String? emptyHint;

  bool get _showCrossDropHint => draggingFrom != null && draggingFrom != tag;

  @override
  Widget build(BuildContext context) {
    final pointingUp = tag == BucketListActivityTag.currentYear;

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(title: title, count: activities.length),
          const SizedBox(height: 14),
          if (activities.isEmpty)
            DragTarget<ActivityDto>(
              onWillAcceptWithDetails: (details) {
                if (details.data.tag == BucketListActivityTag.completed) {
                  return false;
                }
                onHover(0);
                return true;
              },
              onLeave: (_) => onLeave(),
              onAcceptWithDetails: (details) async {
                await onAccept(details.data, 0);
                onLeave();
              },
              builder: (context, candidate, rejected) {
                final active = candidate.isNotEmpty;
                if (_showCrossDropHint || emptyHint == null) {
                  return BucketListDropPlaceholder(
                    active: active,
                    pointingUp: pointingUp,
                  );
                }
                return _EmptySectionHint(text: emptyHint!);
              },
            )
          else
            Column(
              children: [
                if (_showCrossDropHint)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DragTarget<ActivityDto>(
                      onWillAcceptWithDetails: (details) {
                        // Prefer section endpoint: end of This year, start of Upcoming.
                        final preferIndex =
                            tag == BucketListActivityTag.currentYear
                            ? activities.length
                            : 0;
                        onHover(preferIndex);
                        return details.data.tag != tag;
                      },
                      onLeave: (_) => onLeave(),
                      onAcceptWithDetails: (details) async {
                        final preferIndex =
                            tag == BucketListActivityTag.currentYear
                            ? activities.length
                            : 0;
                        await onAccept(details.data, preferIndex);
                        onLeave();
                      },
                      builder: (context, candidate, rejected) {
                        return BucketListDropPlaceholder(
                          active: candidate.isNotEmpty,
                          pointingUp: pointingUp,
                        );
                      },
                    ),
                  ),
                for (var i = 0; i < activities.length; i++) ...[
                  _DraggableActivityTile(
                    activity: activities[i],
                    index: i,
                    sectionLength: activities.length,
                    isDropTarget:
                        hoverIndex == i &&
                        draggingFrom != null &&
                        // Same-section hover highlight only.
                        draggingFrom == tag,
                    onTap: () => onTap(activities[i]),
                    onDragStarted: onDragStarted,
                    onDragEnded: onDragEnded,
                    onHover: onHover,
                    onLeave: onLeave,
                    onAccept: onAccept,
                  ),
                  // Trailing drop slot after last item.
                  if (i == activities.length - 1)
                    DragTarget<ActivityDto>(
                      onWillAcceptWithDetails: (details) {
                        onHover(activities.length);
                        return details.data.tag !=
                            BucketListActivityTag.completed;
                      },
                      onLeave: (_) => onLeave(),
                      onAcceptWithDetails: (details) async {
                        await onAccept(details.data, activities.length);
                        onLeave();
                      },
                      builder: (context, candidate, rejected) {
                        if (candidate.isEmpty) {
                          return const SizedBox(height: 4);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: BucketListDropPlaceholder(
                            active: true,
                            pointingUp: pointingUp,
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Row(
      children: [
        AppText(
          title,
          variant: AppTextVariant.title,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.22)
                : AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: AppText(
            '$count',
            variant: AppTextVariant.caption,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _EmptySectionHint extends StatelessWidget {
  const _EmptySectionHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      height: 72,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A32)
            : AppColors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: AppText(
        text,
        variant: AppTextVariant.bodySmall,
        color: AppColors.textSecondaryOf(context),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DraggableActivityTile extends StatelessWidget {
  const _DraggableActivityTile({
    required this.activity,
    required this.index,
    required this.sectionLength,
    required this.isDropTarget,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onHover,
    required this.onLeave,
    required this.onAccept,
  });

  final ActivityDto activity;
  final int index;
  final int sectionLength;
  final bool isDropTarget;
  final VoidCallback onTap;
  final ValueChanged<ActivityDto> onDragStarted;
  final VoidCallback onDragEnded;
  final ValueChanged<int> onHover;
  final VoidCallback onLeave;
  final Future<void> Function(ActivityDto activity, int toIndex) onAccept;

  @override
  Widget build(BuildContext context) {
    final row = BucketListRow(
      activity: activity,
      onTap: onTap,
      isDropTarget: isDropTarget,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DragTarget<ActivityDto>(
        onWillAcceptWithDetails: (details) {
          if (details.data.id == activity.id) return false;
          if (details.data.tag == BucketListActivityTag.completed) return false;
          onHover(index);
          return true;
        },
        onLeave: (_) => onLeave(),
        onAcceptWithDetails: (details) async {
          await onAccept(details.data, index);
          onLeave();
        },
        builder: (context, candidate, rejected) {
          return LongPressDraggable<ActivityDto>(
            data: activity,
            delay: const Duration(milliseconds: 280),
            onDragStarted: () => onDragStarted(activity),
            onDragEnd: (_) => onDragEnded(),
            onDraggableCanceled: (_, _) => onDragEnded(),
            feedback: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 36,
                child: BucketListRow(activity: activity, isDragging: true),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.28, child: row),
            child: row,
          );
        },
      ),
    );
  }
}

class _CompletedSection extends StatelessWidget {
  const _CompletedSection({required this.activities, required this.onTap});

  final List<ActivityDto> activities;
  final ValueChanged<ActivityDto> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(title: 'Completed', count: activities.length),
          const SizedBox(height: 14),
          for (final activity in activities)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BucketListRow(
                activity: activity,
                completed: true,
                onTap: () => onTap(activity),
              ),
            ),
        ],
      ),
    );
  }
}
