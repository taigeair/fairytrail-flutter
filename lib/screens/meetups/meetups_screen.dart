import 'dart:async';
import 'dart:math' as math;

import 'package:fairytrail/api/meetups.dart';
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/meetups/meetup_preview_card.dart';
import 'package:fairytrail/components/meetups/meetups_map_view.dart';
import 'package:fairytrail/constants/profile_status.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/location/location_service.dart';
import 'package:fairytrail/meetups/meetup_analytics.dart';
import 'package:fairytrail/meetups/meetups_controller.dart';
import 'package:fairytrail/meetups/nearby_users_preview.dart';
import 'package:fairytrail/screens/meetups/create_meetup_screen.dart';
import 'package:fairytrail/screens/meetups/meetup_browse_screen.dart';
import 'package:fairytrail/components/meetups/meetup_member_avatar_stack.dart';
import 'package:fairytrail/meetups/meetup_chat_close.dart';
import 'package:fairytrail/screens/meetups/meetup_chat_screen.dart';
import 'package:fairytrail/screens/meetups/meetup_terms_sheet.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Map of meetups around the traveller.
class MeetupsScreen extends StatefulWidget {
  const MeetupsScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<MeetupsScreen> createState() => _MeetupsScreenState();
}

class _MeetupsScreenState extends State<MeetupsScreen>
    with WidgetsBindingObserver {
  final _controller = MeetupsController();
  final _mapKey = GlobalKey<MeetupsMapViewState>();
  ({double latitude, double longitude})? _center;
  ({double latitude, double longitude})? _draftPin;
  MeetupDto? _selected;
  bool _bootstrapping = false;
  bool _didBootstrap = false;
  bool _termsPrompted = false;
  bool _previewBusy = false;
  bool _nearbyPreviewLoading = false;
  bool _refreshingLocationOnResume = false;

  /// Plus FAB: user must tap the map to choose where to create.
  bool _pickingLocation = false;
  String? _locationError;

  /// Fallback when the map hasn't reported zoom yet (~default framing).
  static const _pinHitRadiusKmFallback = 0.2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onChanged);
    if (widget.isActive) unawaited(_bootstrap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!widget.isActive) return;
    if (!_didBootstrap || !_controller.termsAccepted) return;
    unawaited(_refreshLocationOnResume());
  }

  @override
  void didUpdateWidget(covariant MeetupsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive || oldWidget.isActive) return;
    // Keep the map mounted — refresh location + pins when returning to the tab.
    if (_didBootstrap && _center != null && _controller.termsAccepted) {
      unawaited(_refreshLocationOnResume());
    } else if (!_bootstrapping) {
      unawaited(_bootstrap());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    if (_selected != null &&
        !_controller.meetups.any((m) => m.id == _selected!.id)) {
      _selected = null;
      _previewBusy = false;
    }
    setState(() {});
  }

  Future<void> _refreshNearby() async {
    final center = _center;
    if (center == null || !_controller.termsAccepted) return;
    await _controller.loadNearby(
      latitude: center.latitude,
      longitude: center.longitude,
    );
  }

  /// Fresh GPS → update map center / pan radius → reload nearby meetups.
  Future<void> _refreshLocationOnResume() async {
    if (_refreshingLocationOnResume) return;
    _refreshingLocationOnResume = true;
    try {
      final outcome = await LocationService.shareCurrentLocation(
        awaitFresh: true,
        logTag: 'Meetups/resume',
      );
      if (!mounted) return;
      if (outcome.latitude == null || outcome.longitude == null) {
        await _refreshNearby();
        return;
      }

      final next = (latitude: outcome.latitude!, longitude: outcome.longitude!);
      final prev = _center;
      final moved =
          prev == null ||
          Geolocator.distanceBetween(
                prev.latitude,
                prev.longitude,
                next.latitude,
                next.longitude,
              ) >
              25;

      setState(() {
        _center = next;
        if (moved) {
          _draftPin = null;
          _selected = null;
          _pickingLocation = false;
        }
      });
      // MeetupsMapView recenters + updates pan radius when latitude/longitude change.

      if (_controller.termsAccepted) {
        await _controller.loadNearby(
          latitude: next.latitude,
          longitude: next.longitude,
        );
      }
      if (moved) {
        unawaited(_loadNearbyPreview(force: true));
      }
    } finally {
      _refreshingLocationOnResume = false;
    }
  }

  Future<void> _bootstrap() async {
    if (_bootstrapping) return;
    setState(() {
      _bootstrapping = true;
      _locationError = null;
    });

    final stored = await LocationService.readStoredLocation();
    if (!mounted) return;
    if (stored != null) {
      _center = stored;
    } else {
      final outcome = await LocationService.shareCurrentLocation();
      if (!mounted) return;
      if (outcome.latitude != null && outcome.longitude != null) {
        _center = (latitude: outcome.latitude!, longitude: outcome.longitude!);
      } else {
        _locationError =
            outcome.errorMessage ?? 'Location not available, please try again.';
        setState(() {
          _bootstrapping = false;
          _didBootstrap = false;
        });
        return;
      }
    }

    await _controller.loadTerms();
    if (!mounted) return;

    if (!_controller.termsAccepted && !_termsPrompted) {
      _termsPrompted = true;
      final ok = await showMeetupTermsSheet(context, controller: _controller);
      if (!ok || !mounted) {
        setState(() => _bootstrapping = false);
        return;
      }
    }

    final center = _center;
    if (center != null && _controller.termsAccepted) {
      await _controller.loadNearby(
        latitude: center.latitude,
        longitude: center.longitude,
      );
      unawaited(_loadNearbyPreview());
    }
    if (mounted) {
      setState(() {
        _bootstrapping = false;
        _didBootstrap = _center != null && _controller.termsAccepted;
      });
    }
  }

  Future<void> _loadNearbyPreview({bool force = false}) async {
    if (NearbyUsersPreview.loaded && !force) return;
    if (_nearbyPreviewLoading) return;

    setState(() => _nearbyPreviewLoading = true);
    try {
      await NearbyUsersPreview.ensureLoaded(force: force);
    } finally {
      if (mounted) setState(() => _nearbyPreviewLoading = false);
    }
  }

  bool get _nearbyTravelersLoading =>
      _nearbyPreviewLoading || NearbyUsersPreview.loading;

  void _openNearbyBrowse() {
    unawaited(_openBrowse(initialTab: MeetupBrowseTab.nearby));
  }

  Future<void> _openBrowse({
    MeetupBrowseTab initialTab = MeetupBrowseTab.meetups,
  }) async {
    final selected = await MeetupBrowseScreen.open(
      context,
      meetups: _controller.meetups,
      meetupsController: _controller,
      initialTab: initialTab,
    );
    if (!mounted || selected == null) return;
    await _focusMeetup(selected);
  }

  Future<void> _focusMeetup(MeetupDto meetup) async {
    var m = meetup;
    final i = _controller.meetups.indexWhere((x) => x.id == meetup.id);
    if (i >= 0) m = _controller.meetups[i];

    setState(() {
      _pickingLocation = false;
      _draftPin = null;
      _selected = m;
      _previewBusy = false;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _mapKey.currentState?.animateTo(m.latitude, m.longitude);
  }

  Future<void> _recenter() async {
    final outcome = await LocationService.shareCurrentLocation(
      awaitFresh: true,
    );
    if (!mounted) return;
    if (outcome.latitude == null || outcome.longitude == null) {
      AppToast.show(
        context,
        message: outcome.errorMessage ?? 'Location unavailable',
      );
      return;
    }
    final center = (latitude: outcome.latitude!, longitude: outcome.longitude!);
    setState(() {
      _center = center;
      _draftPin = null;
      _selected = null;
      _pickingLocation = false;
    });
    await _mapKey.currentState?.animateTo(center.latitude, center.longitude);
    if (_controller.termsAccepted) {
      await _controller.loadNearby(
        latitude: center.latitude,
        longitude: center.longitude,
      );
    }
  }

  void _onMapTap(double lat, double lng) {
    if (_pickingLocation) {
      unawaited(_createAtLocation(lat, lng));
      return;
    }
    final nearby = _nearestMeetup(lat, lng);
    if (nearby != null) {
      _onMeetupPinTap(nearby);
      return;
    }
    setState(() {
      _selected = null;
      _draftPin = (latitude: lat, longitude: lng);
    });
  }

  void _onMeetupPinTap(MeetupDto meetup) {
    HapticsService.selection();
    setState(() {
      _pickingLocation = false;
      _draftPin = null;
      _selected = meetup;
      _previewBusy = false;
    });
  }

  void _startCreateFlow() {
    final status = AuthScope.of(context).profileMeta?.status;
    if (!canPostMeetups(status)) {
      AppToast.show(context, message: meetupCannotPostMessage);
      return;
    }
    setState(() {
      _pickingLocation = true;
      _selected = null;
      _draftPin = null;
    });
  }

  void _cancelCreateFlow() {
    setState(() {
      _pickingLocation = false;
      _draftPin = null;
    });
  }

  Future<void> _createAtLocation(double lat, double lng) async {
    setState(() {
      _pickingLocation = false;
      _draftPin = (latitude: lat, longitude: lng);
      _selected = null;
    });
    final created = await CreateMeetupScreen.open(
      context,
      latitude: lat,
      longitude: lng,
    );
    if (!mounted) return;
    setState(() => _draftPin = null);
    if (created != null) {
      _controller.upsert(created);
      setState(() => _selected = created);
    }
  }

  MeetupDto? _nearestMeetup(double lat, double lng) {
    // Match on-screen pin size at the current zoom (map taps often miss markers).
    final hitKm =
        _mapKey.currentState?.pinHitRadiusKm(lat) ?? _pinHitRadiusKmFallback;
    MeetupDto? best;
    var bestKm = hitKm;
    for (final m in _controller.meetups) {
      final d = _haversineKm(lat, lng, m.latitude, m.longitude);
      if (d <= bestKm) {
        bestKm = d;
        best = m;
      }
    }
    return best;
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  void _removeMeetupFromMap(int id) {
    _controller.removeLocally(id);
    if (_selected?.id == id) {
      _selected = null;
      _previewBusy = false;
    }
    setState(() {});
  }

  void _handleChatClose(MeetupChatCloseResult? result, MeetupDto meetup) {
    if (result == MeetupChatClose.deleted ||
        result == MeetupChatClose.reported) {
      _removeMeetupFromMap(meetup.id);
      return;
    }
    setState(() => _selected = meetup);
  }

  Future<void> _joinFromPreview(MeetupDto meetup) async {
    if (meetup.isFull && !meetup.joinedByMe) {
      AppToast.show(context, message: 'This meetup is full (500 members max).');
      return;
    }
    setState(() => _previewBusy = true);
    try {
      final wasJoined = meetup.joinedByMe;
      final joined = await joinMeetup(meetup.id);
      if (!wasJoined) trackJoinedMeetup(joined);
      if (!mounted) return;
      _controller.upsert(joined);
      setState(() {
        _selected = joined;
        _previewBusy = false;
      });
      final chatResult = await MeetupChatScreen.open(context, meetup: joined);
      if (!mounted) return;
      _handleChatClose(chatResult, joined);
    } catch (e) {
      if (mounted) {
        setState(() => _previewBusy = false);
        AppToast.show(context, message: serverErrorText(e));
      }
    }
  }

  Future<void> _openChatFromPreview(MeetupDto meetup) async {
    final result = await MeetupChatScreen.open(context, meetup: meetup);
    if (!mounted) return;
    _handleChatClose(result, meetup);
  }

  void _closePreview() {
    setState(() {
      _selected = null;
      _previewBusy = false;
    });
  }

  Future<void> _openCreateAtDraft() async {
    final pin = _draftPin;
    if (pin == null) return;
    await _createAtLocation(pin.latitude, pin.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final chrome = ShellChromeScope.maybeOf(context);
    final bottomPad = MediaQueryData.fromView(
      View.of(context),
    ).viewPadding.bottom;
    final navHeight =
        chrome?.bottomNavHeightOr(50 + bottomPad) ?? (50 + bottomPad);

    if (_bootstrapping) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final center = _center;
    if (center == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: AppEmptyView(
            icon: Icons.location_off_outlined,
            title: 'Location unavailable',
            subtitle: _locationError,
            actionLabel: 'Try again',
            onAction: _bootstrap,
          ),
        ),
      );
    }

    if (!_controller.termsAccepted) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: AppEmptyView(
            title: 'Agree to continue',
            subtitle: 'Meetup guidelines help keep hangouts safe',
            icon: Icons.handshake_outlined,
            actionLabel: 'Review guidelines',
            onAction: () async {
              _termsPrompted = false;
              await _bootstrap();
            },
          ),
        ),
      );
    }

    final meetups = _controller.meetups;
    final hasDraft = _draftPin != null && !_pickingLocation;
    final hasPreview = _selected != null;
    // Keep FABs above the bottom card / browse bar.
    final fabBottom =
        navHeight +
        (hasPreview
            ? 200
            : hasDraft || _pickingLocation
            ? 112
            : 88);
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: MeetupsMapView(
              key: _mapKey,
              latitude: center.latitude,
              longitude: center.longitude,
              meetups: meetups,
              draftLatitude: _draftPin?.latitude,
              draftLongitude: _draftPin?.longitude,
              onMeetupTap: _onMeetupPinTap,
              onMapTap: _onMapTap,
              onPanLimitReached: () => AppToast.show(
                context,
                message: 'You can only see and join meetups nearby',
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const ConnectivityBannerStrip(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Image.asset(
                            'assets/home/logo.png',
                            height: 26,
                            fit: BoxFit.contain,
                          ),
                        ),
                        if (_nearbyTravelersLoading ||
                            NearbyUsersPreview.totalCount > 0 ||
                            NearbyUsersPreview.users.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Flexible(
                            child: Material(
                              color: surface.withValues(alpha: 0.94),
                              elevation: 3,
                              shadowColor: Colors.black26,
                              borderRadius: BorderRadius.circular(999),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: _nearbyTravelersLoading
                                    ? null
                                    : _openNearbyBrowse,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    6,
                                    10,
                                    6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_nearbyTravelersLoading)
                                        const SizedBox(
                                          width: 92,
                                          height: 32,
                                          child: Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            MeetupMemberAvatarStack(
                                              avatars: NearbyUsersPreview.users
                                                  .take(
                                                    NearbyUsersPreview
                                                        .previewSize,
                                                  )
                                                  .map(
                                                    (u) =>
                                                        u.photoThumbnailUrl ??
                                                        '',
                                                  )
                                                  .toList(),
                                              size: 32,
                                              overlap: 20,
                                              borderColor: surface,
                                              placeholderSize: 32,
                                            ),
                                            if (NearbyUsersPreview.totalCount >
                                                0)
                                              Positioned(
                                                top: -6,
                                                right: -8,
                                                child: _MapCountBubble(
                                                  label:
                                                      _nearbyTravelersCountLabel(
                                                        NearbyUsersPreview
                                                            .totalCount,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: AppText(
                                          'People near you',
                                          variant: AppTextVariant.label,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: AppColors.textSecondaryOf(
                                          context,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Location → Add → Browse (browse on right when a meetup is selected).
          Positioned(
            right: 16,
            bottom: fabBottom,
            child: Theme(
              data: Theme.of(context).copyWith(
                floatingActionButtonTheme: const FloatingActionButtonThemeData(
                  // Default mini FAB is 40; +16% → 46.4
                  smallSizeConstraints: BoxConstraints.tightFor(
                    width: 46.4,
                    height: 46.4,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'meetups_my_location',
                    backgroundColor: surface,
                    foregroundColor: AppColors.primary,
                    onPressed: _recenter,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton.small(
                    heroTag: 'meetups_add',
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    onPressed: _pickingLocation
                        ? _cancelCreateFlow
                        : _startCreateFlow,
                    child: Icon(
                      _pickingLocation
                          ? Icons.close_rounded
                          : Icons.add_rounded,
                    ),
                  ),
                  if (hasPreview || hasDraft) ...[
                    const SizedBox(height: 16),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'meetups_browse',
                          backgroundColor: surface,
                          foregroundColor: AppColors.primary,
                          onPressed: () => unawaited(_openBrowse()),
                          child: const Icon(Icons.list_rounded),
                        ),
                        if (meetups.isNotEmpty)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: _MapCountBubble(label: '${meetups.length}'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Browse — bottom center when nothing is selected.
          // Empty map: prompt to create the first meetup instead.
          if (!hasPreview && !_pickingLocation && !hasDraft)
            Positioned(
              left: 0,
              right: 0,
              bottom: navHeight + 16,
              child: Center(
                child: FloatingActionButton.extended(
                  heroTag: 'meetups_browse_bar',
                  onPressed: meetups.isEmpty
                      ? _startCreateFlow
                      : () => unawaited(_openBrowse()),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  icon: Icon(
                    meetups.isEmpty ? Icons.add_rounded : Icons.list_rounded,
                  ),
                  label: Text(
                    meetups.isEmpty
                        ? 'Create meetup'
                        : 'Browse meetups (${meetups.length})',
                  ),
                ),
              ),
            ),
          // Pick-location hint (create flow from +).
          if (_pickingLocation)
            Positioned(
              left: 16,
              right: 16,
              bottom: navHeight + 24,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(14),
                color: surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: AppText(
                          'Tap the map to place your meetup',
                          variant: AppTextVariant.label,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelCreateFlow,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Create-at-pin CTA (map tap without + flow).
          if (hasDraft)
            Positioned(
              left: 16,
              right: 16,
              bottom: navHeight + 24,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                color: surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_location_alt_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: AppText(
                          'Create meetup here?',
                          variant: AppTextVariant.label,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _draftPin = null),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: _openCreateAtDraft,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                        ),
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Pin preview card with actions.
          if (hasPreview)
            Positioned(
              left: 16,
              right: 16,
              bottom: navHeight + 8,
              child: MeetupPreviewCard(
                meetup: _selected!,
                busy: _previewBusy,
                onJoin: () => _joinFromPreview(_selected!),
                onOpenChat: () => _openChatFromPreview(_selected!),
                onClose: _closePreview,
              ),
            ),
        ],
      ),
    );
  }

  static String _nearbyTravelersCountLabel(int count) {
    if (count <= 0) return '';
    if (count > NearbyUsersPreview.previewSize) return '$count+';
    return '$count';
  }
}

class _MapCountBubble extends StatelessWidget {
  const _MapCountBubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      constraints: const BoxConstraints(minHeight: 18),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
