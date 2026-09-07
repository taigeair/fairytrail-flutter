import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/api/nearby_users.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/meetups/meetup_member_avatar_stack.dart';
import 'package:fairytrail/location/location_service.dart';
import 'package:fairytrail/meetups/meetup_icons.dart';
import 'package:fairytrail/meetups/meetups_controller.dart';
import 'package:fairytrail/meetups/nearby_users_preview.dart';
import 'package:fairytrail/moderation/local_moderation.dart';
import 'package:fairytrail/screens/profile/profile_view_screen.dart';
import 'package:fairytrail/screens/upgrade/upgrade_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Browse nearby meetups and travelers (RN Explore Nearby, embedded here).
class MeetupBrowseScreen extends StatefulWidget {
  const MeetupBrowseScreen({
    super.key,
    required this.meetups,
    this.meetupsController,
    this.initialTab = MeetupBrowseTab.meetups,
  });

  final List<MeetupDto> meetups;
  final MeetupsController? meetupsController;
  final MeetupBrowseTab initialTab;

  static Future<MeetupDto?> open(
    BuildContext context, {
    required List<MeetupDto> meetups,
    MeetupsController? meetupsController,
    MeetupBrowseTab initialTab = MeetupBrowseTab.meetups,
  }) {
    return Navigator.of(context).push<MeetupDto>(
      MaterialPageRoute(
        builder: (_) => MeetupBrowseScreen(
          meetups: meetups,
          meetupsController: meetupsController,
          initialTab: initialTab,
        ),
      ),
    );
  }

  @override
  State<MeetupBrowseScreen> createState() => _MeetupBrowseScreenState();
}

enum MeetupBrowseTab { meetups, nearby }

String _formatNearbyDistance(double km) {
  final miles = km * 0.621371;
  if (km < 1) return 'within 1 mile (1km)';
  final roundedMiles = miles.round();
  final milesDisplay = '$roundedMiles ${roundedMiles == 1 ? 'mile' : 'miles'}';
  final kmDisplay = '${km.round()}km';
  return '$milesDisplay ($kmDisplay) away';
}

class _MeetupBrowseScreenState extends State<MeetupBrowseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == MeetupBrowseTab.nearby ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Nearby',
      body: Column(
        children: [
          AppSlidingTabs(
            controller: _tabController,
            tabs: const [
              AppSlidingTab(icon: Icons.map_outlined, label: 'Meetups'),
              AppSlidingTab(icon: Icons.people_outline, label: 'People'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MeetupsTab(
                  meetups: widget.meetups,
                  meetupsController: widget.meetupsController,
                ),
                const _NearbyUsersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetupsTab extends StatefulWidget {
  const _MeetupsTab({
    required this.meetups,
    this.meetupsController,
  });

  final List<MeetupDto> meetups;
  final MeetupsController? meetupsController;

  @override
  State<_MeetupsTab> createState() => _MeetupsTabState();
}

class _MeetupsTabState extends State<_MeetupsTab> {
  Set<int> _reportedIds = {};

  @override
  void initState() {
    super.initState();
    widget.meetupsController?.addListener(_onMeetupsChanged);
    unawaited(_loadReportedIds());
  }

  @override
  void dispose() {
    widget.meetupsController?.removeListener(_onMeetupsChanged);
    super.dispose();
  }

  void _onMeetupsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadReportedIds() async {
    final ids = await LocalModeration.instance.reportedMeetupIds();
    if (!mounted) return;
    setState(() => _reportedIds = ids);
  }

  List<MeetupDto> get _visibleMeetups {
    final source = widget.meetupsController?.meetups ?? widget.meetups;
    return source.where((m) => !_reportedIds.contains(m.id)).toList();
  }

  void _selectMeetup(MeetupDto m) {
    Navigator.pop(context, m);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._visibleMeetups]
      ..sort((a, b) {
        final da = a.distanceKm ?? double.infinity;
        final db = b.distanceKm ?? double.infinity;
        final c = da.compareTo(db);
        if (c != 0) return c;
        return a.startsAt.compareTo(b.startsAt);
      });

    if (sorted.isEmpty) {
      return const AppEmptyView(
        title: 'No meetups nearby',
        subtitle: 'Create one and see who joins.',
        icon: Icons.map_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final m = sorted[index];
        final avatars = meetupAvatarUrls(fromMeetup: m.avatars);
        final extraGoing = m.memberCount > avatars.length
            ? m.memberCount - avatars.length
            : 0;
        final goingLabel = avatars.isEmpty
            ? '${m.memberCount} going'
            : extraGoing > 0
            ? '+$extraGoing'
            : '${m.memberCount} going';
        final distance = m.distanceKm != null
            ? _formatNearbyDistance(m.distanceKm!)
            : null;

        return AppCard(
          onTap: () => _selectMeetup(m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  meetupCategoryEmoji(m.category),
                  style: const TextStyle(fontSize: 28, height: 1),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      m.name,
                      variant: AppTextVariant.label,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      '${m.category.label} · ${_formatWhen(m.startsAt)}',
                      variant: AppTextVariant.caption,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    if (distance != null) ...[
                      const SizedBox(height: 4),
                      AppText(
                        distance,
                        variant: AppTextVariant.caption,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MeetupMemberAvatarStack(
                    avatars: avatars,
                    size: 28,
                    placeholderSize: 36,
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    goingLabel,
                    variant: AppTextVariant.caption,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryOf(context),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatWhen(DateTime when) {
    final now = DateTime.now();
    final time = DateFormat.jm().format(when);
    if (when.year == now.year &&
        when.month == now.month &&
        when.day == now.day) {
      return 'Today $time';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (when.year == tomorrow.year &&
        when.month == tomorrow.month &&
        when.day == tomorrow.day) {
      return 'Tomorrow $time';
    }
    return DateFormat('EEE $time').format(when);
  }

}

/// Free: reuse cached [initLoadSize] rows — first [previewSize] clear, rest blurred + upgrade.
/// Paid: reuse cached first page, append page 2+ on scroll.
class _NearbyUsersTab extends StatefulWidget {
  const _NearbyUsersTab();

  @override
  State<_NearbyUsersTab> createState() => _NearbyUsersTabState();
}

class _NearbyUsersTabState extends State<_NearbyUsersTab>
    with AutomaticKeepAliveClientMixin {
  static const _paidPageSize = NearbyUsersPreview.initLoadSize;
  static const _loadMoreThreshold = 240.0;

  final _scrollController = ScrollController();
  final _users = <NearbyUserDto>[];
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _locationRequired = false;
  bool _hasMore = true;
  /// Auto-fetch until the list fills the viewport — only on first open / refresh.
  bool _allowViewportFill = true;
  String? _error;
  int _page = 1;
  int _totalCount = 0;
  int _fillViewportRetries = 0;

  @override
  bool get wantKeepAlive => true;

  bool get _isFreeTier {
    try {
      return !AuthScope.of(context).isPaid;
    } catch (_) {
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      unawaited(_onLoadMore());
    }
  }

  /// iPad / large screens: first page often fits without scrolling, so the
  /// scroll listener never fires. Run once on open until the list overflows
  /// or there is nothing left — not again when switching tabs.
  void _scheduleFillViewport() {
    if (!_allowViewportFill) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_fillViewportIfNeeded());
    });
  }

  Future<void> _fillViewportIfNeeded() async {
    if (!mounted || !_allowViewportFill || _isFreeTier || _locationRequired) {
      return;
    }
    if (_loading || _refreshing || _loadingMore || !_hasMore) return;
    if (_users.isEmpty) return;

    if (!_scrollController.hasClients) {
      if (_fillViewportRetries < 12) {
        _fillViewportRetries++;
        _scheduleFillViewport();
      }
      return;
    }
    _fillViewportRetries = 0;

    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= _loadMoreThreshold) {
      await _onLoadMore();
      if (!_hasMore) _allowViewportFill = false;
    } else {
      _allowViewportFill = false;
    }
  }

  void _syncHasMore() {
    _hasMore = !_isFreeTier &&
        (_totalCount <= 0 || _users.length < _totalCount);
  }

  Future<void> _bootstrap() async {
    await NearbyUsersPreview.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _locationRequired = NearbyUsersPreview.error == 'location_required';
      _error = _locationRequired ? null : NearbyUsersPreview.error;
      _users
        ..clear()
        ..addAll(NearbyUsersPreview.users);
      _totalCount = NearbyUsersPreview.totalCount;
      _page = 1;
      _loading = false;
      _allowViewportFill = true;
      _syncHasMore();
    });
    _scheduleFillViewport();
  }

  void _applyPreviewCache() {
    _users
      ..clear()
      ..addAll(NearbyUsersPreview.users);
    _totalCount = NearbyUsersPreview.totalCount;
    _page = 1;
    _locationRequired = NearbyUsersPreview.error == 'location_required';
    _error = _locationRequired ? null : NearbyUsersPreview.error;
    _allowViewportFill = true;
    _syncHasMore();
  }

  Future<bool> _ensureLocation() async {
    final outcome = await LocationService.shareCurrentLocation();
    return outcome.latitude != null && outcome.longitude != null;
  }

  Future<void> _load({
    required int page,
    bool append = false,
  }) async {
    if (_isFreeTier || page <= 1) return;

    if (_loadingMore) return;
    setState(() => _loadingMore = true);

    try {
      final ok = await _ensureLocation();
      if (!mounted) return;
      if (!ok) {
        setState(() => _locationRequired = true);
        return;
      }

      final data = await fetchNearbyUsersWithRetry(
        radiusKm: NearbyUsersPreview.radiusKm,
        page: page,
        pageSize: _paidPageSize,
      );
      if (!mounted) return;
      setState(() {
        _locationRequired = false;
        _error = null;
        _page = page;
        _totalCount = data.totalCount;
        if (append) {
          if (data.users.isEmpty) {
            _hasMore = false;
          } else {
            final seen = _users.map((u) => u.profileId).toSet();
            var added = 0;
            for (final u in data.users) {
              if (seen.add(u.profileId)) {
                _users.add(u);
                added++;
              }
            }
            if (added == 0) {
              _hasMore = false;
            } else {
              _syncHasMore();
            }
          }
        } else {
          _syncHasMore();
        }
      });
      if (append && _allowViewportFill) {
        _scheduleFillViewport();
      }
    } catch (e) {
      if (!mounted) return;
      final code = serverErrorCode(e);
      if (code == 'location_not_set') {
        setState(() => _locationRequired = true);
      } else {
        setState(() => _error = serverErrorText(e));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    if (_isFreeTier) {
      _openUpgrade();
      return;
    }
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      NearbyUsersPreview.loaded = false;
      await NearbyUsersPreview.ensureLoaded(force: true);
      if (!mounted) return;
      setState(_applyPreviewCache);
      _scheduleFillViewport();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = serverErrorText(e));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _onLoadMore() async {
    if (_isFreeTier) return;
    if (_loading || _refreshing || _loadingMore || !_hasMore) return;
    if (_users.length >= _totalCount && _totalCount > 0) {
      setState(() => _hasMore = false);
      return;
    }
    await _load(page: _page + 1, append: true);
  }

  void _openUpgrade() {
    UpgradeScreen.open(context, reason: 'nearby_travelers', from: 'nearby');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_locationRequired) {
      return AppEmptyView(
        title: 'Location needed',
        subtitle: 'Share your location to see travelers nearby.',
        icon: Icons.location_off_outlined,
        actionLabel: 'Share location',
        onAction: () async {
          NearbyUsersPreview.loaded = false;
          await NearbyUsersPreview.ensureLoaded(force: true);
          if (!mounted) return;
          setState(_applyPreviewCache);
        },
      );
    }

    if (_loading && _users.isEmpty) {
      return const Center(child: AppLoading());
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: _users.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      if (_error != null)
                        AppEmptyView(
                          title: "Couldn't load nearby travelers",
                          subtitle: _error,
                          icon: Icons.error_outline,
                          actionLabel: 'Retry',
                          onAction: () => _bootstrap(),
                        )
                      else
                        const AppEmptyView(
                          title: 'No nearby travelers yet',
                          subtitle:
                              'Try widening your radius or check back a bit later.',
                          icon: Icons.people_outline,
                        ),
                    ],
                  )
                : NotificationListener<ScrollMetricsNotification>(
                    onNotification: (n) {
                      if (!_allowViewportFill) return false;
                      if (n.metrics.axis != Axis.vertical) return false;
                      if (n.metrics.maxScrollExtent <= _loadMoreThreshold) {
                        unawaited(_onLoadMore());
                      } else {
                        _allowViewportFill = false;
                      }
                      return false;
                    },
                    child: ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _users.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == _users.length) {
                          if (_isFreeTier) {
                            final moreExist =
                                _totalCount > _users.length ||
                                _users.length >=
                                    NearbyUsersPreview.initLoadSize;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: AppText(
                                    '$_totalCount travelers near you',
                                    variant: AppTextVariant.title,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (moreExist)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Material(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: _openUpgrade,
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.lock_rounded,
                                                color: AppColors.white,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'Upgrade to see all nearby travelers',
                                                  style: TextStyle(
                                                    color: AppColors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }
                          if (_loadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox(height: 8);
                        }

                        final u = _users[index];
                        final lockedFree =
                            _isFreeTier && index >= NearbyUsersPreview.previewSize;
                        return AppCard(
                          onTap: () {
                            if (lockedFree) {
                              _openUpgrade();
                              return;
                            }
                            ProfileViewScreen.open(
                              context,
                              profileId: u.profileId,
                              from: 'nearby',
                            );
                          },
                          child: Row(
                            children: [
                              _NearbyTravelerAvatar(
                                photoUrl: u.photoThumbnailUrl,
                                blurred: lockedFree,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(
                                      u.name,
                                      variant: AppTextVariant.label,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    AppText(
                                      _formatNearbyDistance(u.distanceKm),
                                      variant: AppTextVariant.caption,
                                      color: AppColors.textSecondaryOf(context),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _NearbyTravelerAvatar extends StatelessWidget {
  const _NearbyTravelerAvatar({
    required this.photoUrl,
    required this.blurred,
  });

  final String? photoUrl;
  final bool blurred;

  static const _size = 52.0;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    Widget avatar = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(photoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasPhoto
          ? null
          : const Icon(Icons.person_rounded, color: AppColors.primary),
    );

    if (blurred) {
      avatar = ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            avatar,
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: _size,
                height: _size,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Icon(
              Icons.lock_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ],
        ),
      );
    }

    return avatar;
  }
}
