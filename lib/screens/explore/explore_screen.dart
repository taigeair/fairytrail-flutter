import 'dart:async';
import 'dart:math';

import 'package:fairytrail/activities/activities_controller.dart';
import 'package:fairytrail/ads/ad_policy.dart';
import 'package:fairytrail/ads/ads_service.dart';
import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/api/travel.dart' as travel_api;
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/explore/explore_action_bar.dart';
import 'package:fairytrail/components/explore/explore_filter_chips_bar.dart';
import 'package:fairytrail/components/explore/explore_filters_sheet.dart';
import 'package:fairytrail/components/explore/explore_profile_actions.dart';
import 'package:fairytrail/components/explore/explore_profile_card.dart';
import 'package:fairytrail/components/explore/explore_segmented_header.dart';
import 'package:fairytrail/components/explore/explore_status_views.dart';
import 'package:fairytrail/components/explore/explore_paused_gate.dart';
import 'package:fairytrail/components/explore/photo_issue_sheet.dart';
import 'package:fairytrail/components/location/location_prompt_view.dart';
import 'package:fairytrail/constants/profile_status.dart';
import 'package:fairytrail/explore/explore_controller.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/push/notification_prompt_store.dart';
import 'package:fairytrail/push/notification_router.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/screens/ads/native_offer_ad_screen.dart';
import 'package:fairytrail/screens/ads/rewarded_ad_gate.dart';
import 'package:fairytrail/screens/explore/activities_screen.dart';
import 'package:fairytrail/screens/explore/connected_screen.dart';
import 'package:fairytrail/screens/explore/pickup_travel_money_screen.dart';
import 'package:fairytrail/screens/profile/notifications_settings_screen.dart';
import 'package:fairytrail/screens/registration/profile_photos_screen.dart';
import 'package:fairytrail/screens/shell/floating_bottom_nav.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/screens/trail_book/trail_book_nav.dart';
import 'package:fairytrail/screens/upgrade/upgrade_screen.dart';
import 'package:fairytrail/screens/verification/verification_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
// import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/explore_logical_day.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Explore shell — People deck + Activities feed.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  late final ExploreController _controller;
  late final ActivitiesController _activities;
  late final TabController _tabController;
  late final AnimationController _exitAnim;
  late final AnimationController _enterAnim;
  late final AnimationController _connectStampAnim;

  late final Animation<double> _exitFade;
  late final Animation<double> _exitScale;
  late final Animation<double> _enterFade;
  late final Animation<double> _enterScale;
  late final Animation<double> _connectStampFade;

  final _scrollController = ScrollController();
  final _scrollOffset = ValueNotifier<double>(0);

  bool _animating = false;
  bool _connecting = false;
  bool _skipping = false;
  bool _entering = false;

  /// API + transition must not advance sooner than this.
  static const _minActionAnim = Duration(milliseconds: 1035);
  static const _actionApiTimeout = Duration(seconds: 15);
  bool _showConnectStamp = false;
  bool _rewardGateVisible = false;
  bool _rewardGateDismissed = false;
  bool _rewardEvaluationScheduled = false;
  bool _evaluatingRewardGate = false;
  bool _restoringPendingAd = false;
  bool _presentingActionAd = false;
  bool? _isFirstTimeUser;
  bool _firstConnectAdGraceLoaded = false;
  int? _firstConnectAdGraceThroughAction;
  int _adFreeProfileActionsRemaining = 0;
  bool _suppressAdsForCurrentAction = false;
  int? _effectiveTotalActions;
  int? _effectiveDailyActions;
  String? _effectiveDailyActionsDayKey;
  RewardedAd? _rewardedAd;
  FullProfileDto? _exitingProfile;
  bool? _wasPaused;
  int _popularActivitiesRequest = 0;
  ShellChromeController? _shellChrome;

  static const _actionBarChrome = 64.0; // button + fade padding
  static const _gapAboveNav = 6.0;
  static const _headerH = ExploreSegmentedHeader.height;

  ExploreTopTab get _topTab => ExploreTopTab.values[_tabController.index];

  @override
  void initState() {
    super.initState();
    _controller = ExploreController();
    _controller.addListener(_onController);
    _activities = ActivitiesController();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabControllerTick);

    // iOS-style dissolve: fade + gentle scale (no slide).
    _exitAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _exitFade = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _exitAnim, curve: Curves.easeInOutCubic));
    _exitScale = Tween<double>(
      begin: 1,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _exitAnim, curve: Curves.easeInOutCubic));

    _enterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _enterFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _enterAnim, curve: Curves.easeOutCubic));
    _enterScale = Tween<double>(
      begin: 1.1,
      end: 1,
    ).animate(CurvedAnimation(parent: _enterAnim, curve: Curves.easeOutCubic));

    _connectStampAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _connectStampFade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 30),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 35,
      ),
    ]).animate(_connectStampAnim);

    _scrollController.addListener(_onScroll);
    _controller.bootstrap();
    // Warm Activities while user is on People so the tab switch feels instant.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = AuthScope.of(context);
      _activities.currentUserAvatarUrl = auth.profileMeta?.photoUrl;
      unawaited(_activities.bootstrap());
    });
    unawaited(_loadFirstTimeUserState());
    Future<void>.delayed(const Duration(seconds: 3), _restorePendingAd);
  }

  Future<void> _loadFirstTimeUserState() async {
    final storage = LocalStorage.instance;
    final isFirstTimeUser = await storage.isFirstConnect();
    final graceThroughAction = await storage
        .getFirstConnectAdGraceThroughAction();
    if (!mounted) return;
    // A successful or server-reconciled Connect may have been found while the
    // local read was in flight. Never restore first-time suppression after it.
    final alreadyKnownReturning = _isFirstTimeUser == false;
    setState(() {
      if (!alreadyKnownReturning) {
        _isFirstTimeUser = isFirstTimeUser;
      }
      _firstConnectAdGraceThroughAction = graceThroughAction;
      _firstConnectAdGraceLoaded = true;
    });
    if (_isFirstTimeUser == false && !_isInFirstConnectAdGrace) {
      _scheduleAdsEvaluation();
    }
  }

  bool get _isInFirstConnectAdGrace {
    return AdPolicy.isInFirstConnectGrace(
      graceLoaded: _firstConnectAdGraceLoaded,
      graceThroughAction: _firstConnectAdGraceThroughAction,
      totalActions:
          _effectiveTotalActions ?? _controller.meta?.totalProfileActions,
    );
  }

  void _browseActivityIdeas() {
    if (!mounted) return;
    setState(() => _popularActivitiesRequest++);
    _onTopTabChanged(ExploreTopTab.activities);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chrome = ShellChromeScope.maybeOf(context);
    if (!identical(chrome, _shellChrome)) {
      if (_shellChrome?.onBrowseActivityIdeas == _browseActivityIdeas) {
        _shellChrome?.onBrowseActivityIdeas = null;
      }
      _shellChrome = chrome;
      _shellChrome?.onBrowseActivityIdeas = _browseActivityIdeas;
    }
    final auth = AuthScope.of(context);
    _controller.bindAuth(auth);
    final isPaused = auth.user?.accountStatus == 'paused';
    if (_wasPaused == true && !isPaused) {
      unawaited(_controller.refreshAfterUnpause());
    }
    _wasPaused = isPaused;
    _scheduleAdsEvaluation();
  }

  void _onController() {
    if (!mounted) return;
    _syncEffectiveAdActionCounts();
    setState(() {});
    _scheduleAdsEvaluation();
  }

  void _syncEffectiveAdActionCounts() {
    final meta = _controller.meta;
    if (meta == null) return;

    // `alreadyConnected` is device-local. Reconcile it from lifetime server
    // data so returning users on a reinstall/new device are not treated as
    // first-time users with ads suppressed indefinitely.
    if ((meta.totalConnects ?? 0) > 0 && _isFirstTimeUser != false) {
      _isFirstTimeUser = false;
      unawaited(LocalStorage.instance.setAlreadyConnected());
    }

    final serverTotal = meta.totalProfileActions;
    _effectiveTotalActions = max(_effectiveTotalActions ?? 0, serverTotal);

    final dayKey = exploreLogicalDayKey();
    final isNewDay = _effectiveDailyActionsDayKey != dayKey;
    _effectiveDailyActionsDayKey = dayKey;
    _effectiveDailyActions = isNewDay
        ? meta.dailyActions
        : max(_effectiveDailyActions ?? 0, meta.dailyActions);
  }

  int _recordAdAction() {
    _syncEffectiveAdActionCounts();
    final meta = _controller.meta;
    final previousTotal =
        _effectiveTotalActions ?? meta?.totalProfileActions ?? 0;
    final nextTotal = previousTotal + 1;
    final graceThroughAction = _firstConnectAdGraceThroughAction;
    final actionIsInGrace = AdPolicy.isInFirstConnectGrace(
      graceLoaded: _firstConnectAdGraceLoaded,
      graceThroughAction: graceThroughAction,
      totalActions: nextTotal,
    );
    _suppressAdsForCurrentAction =
        _isFirstTimeUser != false ||
        actionIsInGrace ||
        _adFreeProfileActionsRemaining > 0;
    if (_adFreeProfileActionsRemaining > 0) {
      _adFreeProfileActionsRemaining--;
    }
    _effectiveTotalActions = nextTotal;
    _effectiveDailyActions =
        (_effectiveDailyActions ?? meta?.dailyActions ?? 0) + 1;
    _effectiveDailyActionsDayKey = exploreLogicalDayKey();
    if (graceThroughAction != null && nextTotal > graceThroughAction) {
      _firstConnectAdGraceThroughAction = null;
      unawaited(LocalStorage.instance.deleteFirstConnectAdGraceThroughAction());
    }
    return previousTotal;
  }

  void _startFirstConnectAdGrace() {
    final remote = RemoteConfigScope.of(context);
    final graceActions = remote.firstConnectAdGraceActions;
    final currentTotal =
        _effectiveTotalActions ?? _controller.meta?.totalProfileActions ?? 0;
    final graceThroughAction = currentTotal + graceActions;
    _firstConnectAdGraceThroughAction = graceThroughAction;
    _firstConnectAdGraceLoaded = true;

    unawaited(
      _persistFirstConnectAdGrace(
        graceThroughAction: graceThroughAction,
        nextAdCheckpoint: graceThroughAction + remote.adsFrequency,
      ),
    );
  }

  Future<void> _persistFirstConnectAdGrace({
    required int graceThroughAction,
    required int nextAdCheckpoint,
  }) async {
    final storage = LocalStorage.instance;
    try {
      await Future.wait([
        storage.setFirstConnectAdGraceThroughAction(graceThroughAction),
        storage.setCheckpointForAdsScreen(nextAdCheckpoint),
      ]);
    } catch (error, stackTrace) {
      debugPrint(
        '[ExploreAds] Failed to persist first-Connect grace: '
        '$error\n$stackTrace',
      );
    }
  }

  void _scheduleAdsEvaluation() {
    if (_rewardEvaluationScheduled ||
        !mounted ||
        _isFirstTimeUser != false ||
        _isInFirstConnectAdGrace) {
      return;
    }
    _rewardEvaluationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rewardEvaluationScheduled = false;
      if (!mounted) return;
      if (_controller.current != null) {
        unawaited(AdsService.instance.prefetchInterstitial());
      }
      unawaited(_evaluateRewardGate());
    });
  }

  Future<void> _evaluateRewardGate() async {
    if (!mounted ||
        _rewardGateDismissed ||
        _rewardGateVisible ||
        _presentingActionAd ||
        _isFirstTimeUser != false ||
        _isInFirstConnectAdGrace ||
        _suppressAdsForCurrentAction ||
        _evaluatingRewardGate) {
      return;
    }
    final meta = _controller.meta;
    if (meta == null) return;
    _evaluatingRewardGate = true;
    final rewardTaken = await LocalStorage.instance.hasRewardBeenTakenToday();
    if (!mounted) {
      _evaluatingRewardGate = false;
      return;
    }
    final show = AdPolicy.shouldShowRewardGate(
      tier: AuthScope.of(context).tier,
      dailyActions: _effectiveDailyActions ?? meta.dailyActions,
      frequency: RemoteConfigScope.of(context).rewardsAdsFrequency,
      rewardTakenToday: rewardTaken,
      isFirstTimeUser: _isFirstTimeUser != false,
    );
    if (!show) {
      _evaluatingRewardGate = false;
      if (_rewardGateVisible) setState(() => _rewardGateVisible = false);
      return;
    }

    final ad = await AdsService.instance.takeOrLoadRewarded();
    _evaluatingRewardGate = false;
    if (!mounted) {
      ad?.dispose();
      return;
    }
    if (ad == null) {
      // Never block Explore when Google has no eligible inventory. A later
      // profile action can retry after AdsService's cooldown has elapsed.
      return;
    }
    await _consumeCollidingActionAdCheckpoint();
    if (!mounted) {
      ad.dispose();
      return;
    }
    setState(() {
      _rewardedAd = ad;
      _rewardGateVisible = true;
    });
  }

  Future<ExploreAdPlacement?> _actionAdPlacement({
    required int previousTotalActions,
  }) async {
    if (_presentingActionAd ||
        _rewardGateVisible ||
        _rewardedAd != null ||
        _evaluatingRewardGate ||
        _isFirstTimeUser != false ||
        _isInFirstConnectAdGrace ||
        _suppressAdsForCurrentAction) {
      return null;
    }
    final auth = AuthScope.of(context);
    final meta = _controller.meta;
    if (meta == null ||
        !AdPolicy.isAdSupportedTier(
          auth.tier,
          isFirstTimeUser: _isFirstTimeUser != false,
        )) {
      return null;
    }

    // Rewarded eligibility wins when both checkpoints are reached by the same
    // action. This prevents selecting an action ad while a reward gate loads.
    final rewardTaken = await LocalStorage.instance.hasRewardBeenTakenToday();
    if (!mounted) return null;
    if (!_rewardGateDismissed &&
        AdPolicy.shouldShowRewardGate(
          tier: auth.tier,
          dailyActions: _effectiveDailyActions ?? meta.dailyActions,
          frequency: RemoteConfigScope.of(context).rewardsAdsFrequency,
          rewardTakenToday: rewardTaken,
          isFirstTimeUser: _isFirstTimeUser != false,
        )) {
      return null;
    }
    final adsFrequency = RemoteConfigScope.of(context).adsFrequency;

    final storage = LocalStorage.instance;
    final checkpoint = await storage.getCheckpointForAdsScreen();
    final decision = AdPolicy.actionDecision(
      totalActions: _effectiveTotalActions ?? meta.totalProfileActions,
      frequency: adsFrequency,
      checkpoint: checkpoint,
      previousTotalActions: previousTotalActions,
    );
    if (decision.nextCheckpoint != checkpoint) {
      await storage.setCheckpointForAdsScreen(decision.nextCheckpoint);
    }
    if (!decision.showAd ||
        (_effectiveTotalActions ?? meta.totalProfileActions) ==
            meta.pickupMoneyCountdown ||
        !mounted) {
      return null;
    }

    const placement = ExploreAdPlacement.interstitial;
    unawaited(
      AnalyticsService.instance.logEvent('ad_checkpoint_reached', {
        'action_count': _effectiveTotalActions ?? meta.totalProfileActions,
        'frequency': adsFrequency,
        'placement': placement.name,
      }),
    );
    await storage.setBannerAdsScreenViewed(1);
    return placement;
  }

  Future<void> _presentActionAd() async {
    if (!mounted ||
        _presentingActionAd ||
        _rewardGateVisible ||
        _rewardedAd != null ||
        _evaluatingRewardGate ||
        _isFirstTimeUser != false ||
        _isInFirstConnectAdGrace ||
        _suppressAdsForCurrentAction) {
      await LocalStorage.instance.deleteBannerAdsScreenViewed();
      return;
    }
    _presentingActionAd = true;
    var displayed = false;
    try {
      final remote = RemoteConfigScope.of(context);
      if (!remote.isReady) {
        try {
          await remote.refresh();
        } catch (_) {
          // A Google ad can still be shown when Remote Config is unavailable.
        }
      }
      if (!mounted) return;
      final interstitialShown = AdsService.instance.isInitialized
          ? await AdsService.instance.showInterstitial()
          : false;
      if (interstitialShown) {
        displayed = true;
        _trackAdDisplayed('interstitial');
        return;
      }

      if (!mounted || !_hasNativeOffer(remote)) {
        _trackAdSkipped(
          AdsService.instance.isInitialized
              ? 'interstitial_unavailable_and_no_native_fallback'
              : 'sdk_not_ready_and_no_native_fallback',
        );
        return;
      }

      await LocalStorage.instance.setBannerAdsScreenViewed(2);
      if (!mounted) return;
      displayed = true;
      _trackAdDisplayed('native_offer', fallback: true);
      await NativeOfferAdScreen.open(
        context,
        imageUrl: remote.nativeAdsBannerImage,
        offerUrl: remote.nativeAdsOfferUrl,
      );
    } finally {
      _presentingActionAd = false;
      await LocalStorage.instance.deleteBannerAdsScreenViewed();
      if (displayed) {
        _adFreeProfileActionsRemaining = 1;
        _suppressAdsForCurrentAction = true;
      }
      if (mounted) unawaited(AdsService.instance.prefetchInterstitial());
    }
  }

  void _onRewardGateClosed() {
    _adFreeProfileActionsRemaining = 1;
    _suppressAdsForCurrentAction = true;
    if (!mounted) return;
    setState(() {
      _rewardGateVisible = false;
      _rewardGateDismissed = true;
      _rewardedAd = null;
    });
  }

  /// A rewarded ad and an action ad can become due on the same profile action.
  /// Rewarded wins, and the action-ad checkpoint advances by its normal
  /// frequency instead of remaining overdue and appearing on the next turn.
  Future<void> _consumeCollidingActionAdCheckpoint() async {
    final meta = _controller.meta;
    if (meta == null) return;
    final totalActions = _effectiveTotalActions ?? meta.totalProfileActions;
    final frequency = RemoteConfigScope.of(context).adsFrequency;
    final storage = LocalStorage.instance;
    final checkpoint = await storage.getCheckpointForAdsScreen();
    final decision = AdPolicy.actionDecision(
      totalActions: totalActions,
      frequency: frequency,
      checkpoint: checkpoint,
      previousTotalActions: totalActions > 0 ? totalActions - 1 : 0,
    );
    if (decision.showAd && decision.nextCheckpoint != checkpoint) {
      await storage.setCheckpointForAdsScreen(decision.nextCheckpoint);
      unawaited(
        AnalyticsService.instance.logEvent('ad_collision_resolved', {
          'winner': 'rewarded',
          'next_action_checkpoint': decision.nextCheckpoint,
        }),
      );
    }
  }

  bool _hasNativeOffer(RemoteConfigController remote) {
    final uri = Uri.tryParse(remote.nativeAdsOfferUrl ?? '');
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }

  void _trackAdDisplayed(String format, {bool fallback = false}) {
    unawaited(
      AnalyticsService.instance.logEvent('ad_displayed', {
        'format': format,
        'fallback': fallback ? 1 : 0,
      }),
    );
  }

  void _trackAdSkipped(String reason) {
    unawaited(
      AnalyticsService.instance.logEvent('ad_skipped', {'reason': reason}),
    );
  }

  Future<void> _restorePendingAd() async {
    if (!mounted || _restoringPendingAd || _presentingActionAd) return;
    _restoringPendingAd = true;
    try {
      final placement = await LocalStorage.instance.getBannerAdsScreenViewed();
      if (!mounted || placement == null) return;
      if (!_firstConnectAdGraceLoaded) return;
      if (_isFirstTimeUser != false ||
          _isInFirstConnectAdGrace ||
          !AdPolicy.isAdSupportedTier(
            AuthScope.of(context).tier,
            isFirstTimeUser: _isFirstTimeUser != false,
          )) {
        await LocalStorage.instance.deleteBannerAdsScreenViewed();
        return;
      }
      await _presentActionAd();
    } finally {
      _restoringPendingAd = false;
    }
  }

  void _onTabControllerTick() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_topTab != ExploreTopTab.people) return;
    final offset = _scrollController.offset.clamp(0.0, double.infinity);
    _scrollOffset.value = offset;

    final chrome = ShellChromeScope.maybeOf(context);
    if (chrome == null) return;

    // Short scroll distance so buttons fully settle into the nav slot.
    const scrollForFullHide = 56.0;
    chrome.setHideProgress(offset / scrollForFullHide);
  }

  void _resetScrollChrome() {
    _scrollOffset.value = 0;
    ShellChromeScope.maybeOf(context)?.setHideProgress(0);
  }

  void _onTopTabChanged(ExploreTopTab tab) {
    if (_tabController.index == tab.index) return;
    // unawaited(track('explore_switch', {'enter_screen': tab.label}));
    _tabController.animateTo(tab.index);
    _resetScrollChrome();
  }

  @override
  void dispose() {
    if (_shellChrome?.onBrowseActivityIdeas == _browseActivityIdeas) {
      _shellChrome?.onBrowseActivityIdeas = null;
    }
    _tabController.removeListener(_onTabControllerTick);
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    _controller.removeListener(_onController);
    _controller.dispose();
    _activities.dispose();
    _exitAnim.dispose();
    _enterAnim.dispose();
    _connectStampAnim.dispose();
    super.dispose();
  }

  Future<void> _openFilters([ExploreFilterFocus? focus]) async {
    HapticsService.selection();
    await showExploreFiltersSheet(
      context,
      controller: _controller,
      initialFocus: focus,
    );
  }

  Future<void> _onLocationSuccess() async {
    await AuthScope.of(context).markLocationSet();
    await _controller.onLocationShared();
  }

  Future<void> _runCardExitThenAdvance(VoidCallback advance) async {
    if (_animating || _controller.current == null) return;
    _animating = true;
    setState(() => _exitingProfile = _controller.current);

    await _exitAnim.forward(from: 0);
    advance();

    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _resetScrollChrome();

    _exitAnim.reset();
    if (mounted) {
      setState(() {
        _exitingProfile = null;
        _entering = true;
      });
    }

    await _enterAnim.forward(from: 0);
    if (mounted) {
      _enterAnim.reset();
      _animating = false;
      _entering = false;
      setState(() {});
    } else {
      _animating = false;
      _entering = false;
    }
  }

  Future<void> _onSkip() async {
    // Press haptic fired by ExploreActionBar.
    if (_animating || _connecting || _skipping || _controller.current == null) {
      return;
    }
    final skippingProfile = _controller.current!;
    setState(() => _skipping = true);

    final advanced = await _runActionWithImmediateAnim<void>(
      api: () => _controller.sendSkipForCurrent().timeout(_actionApiTimeout),
      onAdvance: () => _controller.advanceAfterAcceptedSkip(skippingProfile.id),
      onError: (e) async {
        if (mounted) AppToast.show(context, message: serverErrorText(e));
      },
    );
    if (!mounted) return;
    setState(() => _skipping = false);
    if (!advanced) return;

    final previousTotalActions = _recordAdAction();
    await _presentPostActionScreens(
      previousTotalActions: previousTotalActions,
      isMatch: false,
    );
  }

  Future<void> _onCare() async {
    final profile = _controller.current;
    if (profile == null) return;
    final photo = profile.photos.isEmpty
        ? null
        : profile.photos.first.displayUrl;
    await openCareFlow(
      context,
      profileId: profile.id,
      name: profile.name,
      profilePhotoUrl: photo,
      path: 'explore',
    );
  }

  Future<void> _waitOutMinActionDuration(DateTime started) async {
    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minActionAnim) {
      await Future<void>.delayed(_minActionAnim - elapsed);
    }
  }

  /// Exit + stamp fade-in immediately; holds stamp until caller finishes.
  Future<void> _playExitAndStampIn() async {
    await _exitAnim.forward(from: 0);
    if (!mounted) return;
    setState(() => _showConnectStamp = true);
    // Stamp sequence: fade-in (35) + hold (30) = 65% — stop before fade-out.
    await _connectStampAnim.animateTo(0.65);
  }

  /// API failed/timed out — reverse back to the same profile.
  Future<void> _abortTransitionBack() async {
    _connectStampAnim.stop();
    if (mounted) setState(() => _showConnectStamp = false);
    _connectStampAnim.reset();
    if (_exitAnim.value > 0) {
      await _exitAnim.reverse();
    }
    _exitAnim.reset();
    if (mounted) {
      setState(() => _exitingProfile = null);
    }
    _animating = false;
  }

  /// Stamp fade-out → advance deck → next profile enter.
  Future<void> _finishStampAndEnter(VoidCallback advance) async {
    if (_connectStampAnim.value < 1) {
      await _connectStampAnim.forward();
    }
    if (!mounted) {
      _animating = false;
      return;
    }

    advance();

    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _resetScrollChrome();

    _exitAnim.reset();
    _connectStampAnim.reset();
    if (mounted) {
      setState(() {
        _showConnectStamp = false;
        _exitingProfile = null;
        _entering = true;
      });
    }

    await _enterAnim.forward(from: 0);
    if (mounted) {
      _enterAnim.reset();
      _animating = false;
      _entering = false;
      setState(() {});
    } else {
      _animating = false;
      _entering = false;
    }
  }

  /// Starts the hiking transition immediately, runs [api] in parallel.
  /// Advances only after API success + min 1s; reverses on failure/timeout.
  /// Returns `true` when the deck advanced.
  Future<bool> _runActionWithImmediateAnim<T>({
    required Future<T> Function() api,
    required VoidCallback onAdvance,
    Future<void> Function(Object error)? onError,
    void Function(T result)? onSuccess,
  }) async {
    if (_animating || _controller.current == null) return false;
    _animating = true;
    setState(() => _exitingProfile = _controller.current);
    final started = DateTime.now();

    // Animation starts now — don't wait for the network.
    final animIn = _playExitAndStampIn();

    T result;
    try {
      result = await api();
    } catch (e) {
      try {
        await animIn;
      } catch (_) {}
      if (!mounted) {
        _animating = false;
        return false;
      }
      await _abortTransitionBack();
      if (onError != null) await onError(e);
      return false;
    }

    onSuccess?.call(result);

    await Future.wait<void>([animIn, _waitOutMinActionDuration(started)]);
    if (!mounted) {
      _animating = false;
      return false;
    }

    await _finishStampAndEnter(onAdvance);
    return true;
  }

  Future<void> _onConnect() async {
    // Press haptic fired by ExploreActionBar.

    if (_needsVerificationBeforeConnect()) {
      await VerificationScreen.open(context, from: 'explore');
      return;
    }

    if (_animating || _connecting || _skipping || _controller.current == null) {
      return;
    }
    final connectingProfile = _controller.current!;
    setState(() => _connecting = true);

    ConnectProfileResponse? connectResult;
    final advanced = await _runActionWithImmediateAnim<ConnectProfileResponse>(
      api: () => _controller.sendConnectForCurrent().timeout(_actionApiTimeout),
      onAdvance: () =>
          _controller.advanceAfterAcceptedConnect(connectingProfile.id),
      onSuccess: (result) {
        connectResult = result;
        unawaited(LocalStorage.instance.setAlreadyConnected());
      },
      onError: (e) async {
        if (!mounted) return;
        final code = serverErrorCode(e);
        if (code == 'photo_issue') {
          await showPhotoIssueSheet(context);
          return;
        }
        if (code == 'gated_limit') {
          await VerificationScreen.open(context, from: 'explore');
          return;
        }
        AppToast.show(context, message: serverErrorText(e));
      },
    );
    if (!mounted) return;
    setState(() => _connecting = false);
    if (!advanced || connectResult == null) return;

    final wasFirstConnect = _isFirstTimeUser != false;
    final previousTotalActions = _recordAdAction();
    if (wasFirstConnect) {
      _startFirstConnectAdGrace();
    }
    _isFirstTimeUser = false;
    final matchedPhoto = connectingProfile.photos.isNotEmpty
        ? connectingProfile.photos.first
        : null;

    await _presentPostActionScreens(
      previousTotalActions: previousTotalActions,
      isMatch: connectResult!.isMatch,
      matchName: connectingProfile.name,
      matchProfileId: connectingProfile.id,
      matchPreviewUrl: matchedPhoto?.displayUrl,
      matchBlurHash: matchedPhoto?.blurHash,
      allowNotificationPrompt: true,
    );
  }

  /// Client screens first (notification → pickup trail money), then server
  /// ([ConnectedScreen] on match). Ads only when neither client nor match UI ran.
  Future<void> _presentPostActionScreens({
    required int previousTotalActions,
    required bool isMatch,
    String? matchName,
    int? matchProfileId,
    String? matchPreviewUrl,
    String? matchBlurHash,
    bool allowNotificationPrompt = false,
  }) async {
    var showedClientScreen = false;

    // 1) First-connect notifications (client) — before Connected.
    if (allowNotificationPrompt && !NotificationPromptStore.wasPrompted) {
      String? userId;
      try {
        userId = AuthScope.of(context).user?.id;
      } catch (_) {}
      NotificationPromptStore.markPrompted(userId: userId);
      showedClientScreen = true;
      await EnableNotificationsScreen.open(context, from: 'first_connect');
      if (!mounted) return;
    }

    // 2) Pickup trail money (client) — before Connected; skip if notif just shown
    //    (RN blocks pickup on first connect).
    if (!showedClientScreen) {
      final showedPickup = await _maybeShowPickupTrailMoney();
      if (!mounted) return;
      if (showedPickup) showedClientScreen = true;
    }

    // 3) Server match screen — after client prompts.
    if (isMatch) {
      unawaited(LocalStorage.instance.markHasMatch());
      HapticsService.success();
      _suppressAdsForCurrentAction = true;
      _showConnected(
        matchName ?? '',
        profileId: matchProfileId,
        previewUrl: matchPreviewUrl,
        blurHash: matchBlurHash,
      );
      return;
    }

    // 4) Ads only when no client/server overlay took this action.
    if (showedClientScreen) {
      _suppressAdsForCurrentAction = true;
      return;
    }

    final adPlacement = await _actionAdPlacement(
      previousTotalActions: previousTotalActions,
    );
    if (adPlacement != null && mounted) {
      await _presentActionAd();
    }
  }

  /// RN `checkUserProfileActions` — returns true if the pickup modal was shown.
  Future<bool> _maybeShowPickupTrailMoney() async {
    if (await LocalStorage.instance.isPickupTrailMoneyDisabled()) {
      return false;
    }

    final meta = _controller.meta;
    if (meta == null) return false;

    final totalActions = _effectiveTotalActions ?? meta.totalProfileActions;
    if (totalActions <= 0) return false;

    final currentMoney = meta.totalTravelMoney ?? 0;
    final maxMoney = meta.freeMoneyMax;
    if (maxMoney == null) return false;

    // RN: currentMoney + 100 cents must stay under freeMoneyMax.
    final isLessThanMaxMoney = currentMoney + 100 < maxMoney;
    final countdown = meta.pickupMoneyCountdown ?? 0;

    final shouldShow =
        isLessThanMaxMoney &&
        (countdown == 0 ||
            totalActions == countdown ||
            totalActions > countdown);

    if (shouldShow) {
      // RN modal calls update-pickup-countdown on open; apply locally so the
      // next skip/connect does not re-hit the same stale checkpoint.
      await _advancePickupCountdown(totalActions);
      if (!mounted) return true;
      final pickedUp = await PickupTravelMoneyScreen.open(
        context,
        totalActions: totalActions,
      );
      if (pickedUp) {
        _controller.applyTravelMoneyPickedUp();
      }
      return true;
    }

    // Past countdown but at free-money cap — advance checkpoint with no UI.
    if (totalActions > countdown && !isLessThanMaxMoney) {
      await _advancePickupCountdown(totalActions);
    }
    return false;
  }

  /// Server sets next checkpoint (`totalActions + random`); mirror into local meta.
  Future<void> _advancePickupCountdown(int totalActions) async {
    try {
      final next = await travel_api.updatePickupCountdown(
        totalActions: totalActions,
      );
      _controller.applyPickupMoneyCountdown(next ?? totalActions + 1);
    } catch (_) {
      // Still move local checkpoint forward to avoid an infinite pickup loop.
      _controller.applyPickupMoneyCountdown(totalActions + 1);
    }
  }

  /// Matches RN: gated users at/over connectsLimit open verification.
  bool _needsVerificationBeforeConnect() {
    final auth = AuthScope.of(context);
    final meta = _controller.meta;
    if (auth.tier != 'gated' && meta?.tier != 'gated') return false;
    final limit = meta?.connectsLimit;
    if (limit == null) return false;

    return _controller.effectiveTotalConnectsCount >= limit;
  }

  void _showConnected(
    String profileName, {
    int? profileId,
    String? previewUrl,
    String? blurHash,
  }) {
    final messages = MessagesScope.maybeOf(context);
    // Prefetch matches so Send message can open instantly.
    unawaited(messages?.loadInbox(silent: true));

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => ConnectedScreen(
          profileName: profileName,
          onLater: () => Navigator.of(ctx).pop(),
          onSendMessage: () {
            final chrome = ShellChromeScope.maybeOf(context);
            Navigator.of(ctx).pop();
            if (profileId == null || messages == null) {
              chrome?.selectTab(AppTab.messages);
              return;
            }
            NotificationRouter.openMatchChat(
              profileId: profileId,
              profileName: profileName,
              previewUrl: previewUrl,
              blurHash: blurHash,
              messages: messages,
              chrome: chrome,
            );
          },
        ),
      ),
    );
  }

  Future<void> _onMorePressed() async {
    final profile = _controller.current;
    if (profile == null || _animating) return;
    final reported = await showExploreProfileActionsSheet(
      context,
      profileId: profile.id,
    );
    if (!reported || !mounted) return;
    await _runCardExitThenAdvance(_controller.dismissCurrent);
  }

  void _onUndoPressed() {
    if (_animating || !_controller.canUndo) return;
    if (!AuthScope.of(context).isPaid) {
      HapticsService.selection();
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const UpgradeScreen(reason: 'undo', from: 'explore'),
        ),
      );
      return;
    }
    HapticsService.light();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _resetScrollChrome();
    _controller.undoLastSkip(
      onError: (e) {
        if (mounted) AppToast.show(context, message: serverErrorText(e));
      },
    );
  }

  double _buttonsBottom({
    required double hideProgress,
    required double navHeight,
    required double bottomPad,
  }) {
    // Resting: snug just above the nav.
    final resting = navHeight + _gapAboveNav;
    // Settled: low in the former tab-bar band (above home indicator).
    final inNavSlot = bottomPad + 8;
    return resting + (inNavSlot - resting) * hideProgress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    if (auth.user?.accountStatus == 'paused') {
      return const ExplorePausedGate();
    }
    // Proactive unapproved gate (RN people.tsx / main/index.tsx).
    if (auth.profileMeta?.status == ProfileStatus.unapproved ||
        _controller.loadState == ExploreLoadState.unapproved) {
      final bottomPad = MediaQueryData.fromView(
        View.of(context),
      ).viewPadding.bottom;
      final chrome = ShellChromeScope.maybeOf(context);
      final navHeight =
          chrome?.bottomNavHeightOr(50 + bottomPad) ?? (50 + bottomPad);
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: ExploreUnapprovedView(
          reason: _controller.unapprovedReason,
          bottomInset: navHeight,
          onEditPhoto: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProfilePhotosScreen(reupload: true),
              ),
            );
          },
        ),
      );
    }

    final theme = Theme.of(context);
    final topPad = MediaQuery.paddingOf(context).top;
    // Raw inset — Scaffold/extendBody can zero out MediaQuery.padding.bottom.
    final bottomPad = MediaQueryData.fromView(
      View.of(context),
    ).viewPadding.bottom;
    final chrome = ShellChromeScope.maybeOf(context);
    final navHeight =
        chrome?.bottomNavHeightOr(50 + bottomPad) ?? (50 + bottomPad);
    final needsLocation =
        _controller.loadState == ExploreLoadState.needsLocation;

    if (needsLocation) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: AppSafeArea(
          child: LocationPromptView(
            compact: true,
            onSuccess: _onLocationSuccess,
            onSkip: _controller.dismissLocationPrompt,
          ),
        ),
      );
    }

    final profile = _exitingProfile ?? _controller.current;
    final showDeck =
        _controller.loadState == ExploreLoadState.ready && profile != null;

    final restingBottom = navHeight + _gapAboveNav;
    final scrollBottomInset = restingBottom + _actionBarChrome + 16;
    // Chip bar height (34) + gap below People/Activities header.
    const chipsGap = 6.0;
    final filtersH = _controller.prefsReady ? 34.0 + chipsGap : 0.0;
    final bannerExtent = ConnectivityScope.maybeOf(context)?.extent ?? 0;
    final headerBlockH = topPad + _headerH + bannerExtent;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: headerBlockH,
            left: 0,
            right: 0,
            bottom: 0,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPeoplePage(
                  theme: theme,
                  chrome: chrome,
                  topPad: 0,
                  filtersH: filtersH,
                  scrollBottomInset: scrollBottomInset,
                  bottomPad: bottomPad,
                  showDeck: showDeck,
                  profile: profile,
                ),
                ActivitiesScreen(
                  controller: _activities,
                  isActive: _topTab == ExploreTopTab.activities,
                  popularRequest: _popularActivitiesRequest,
                ),
              ],
            ),
          ),

          // Themed header (status bar + People/Activities) stays white/dark;
          // offline strip extends it downward by text height only.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: theme.scaffoldBackgroundColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: topPad),
                  ExploreSegmentedHeader(
                    selected: _topTab,
                    onChanged: _onTopTabChanged,
                  ),
                  const ConnectivityBannerStrip(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeoplePage({
    required ThemeData theme,
    required ShellChromeController? chrome,
    required double topPad,
    required double filtersH,
    required double scrollBottomInset,
    required double bottomPad,
    required bool showDeck,
    required FullProfileDto? profile,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_rewardGateVisible)
          RewardedAdGate(ad: _rewardedAd!, onClose: _onRewardGateClosed)
        else if (showDeck && profile != null)
          _buildAnimatedCard(
            profile,
            topInset: filtersH + 8,
            bottomInset: scrollBottomInset,
          )
        else
          _buildNonReadyBody(
            bottomInset:
                (chrome?.bottomNavHeightOr(50 + bottomPad) ??
                    (50 + bottomPad)) +
                12,
          ),

        if (!_rewardGateVisible &&
            _controller.prefsReady &&
            (showDeck || kDebugMode))
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ListenableBuilder(
              listenable: Listenable.merge([_scrollOffset, ?chrome]),
              builder: (context, child) {
                final t = (1.0 - (chrome?.hideProgress ?? 0)).clamp(0.0, 1.0);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * -40),
                    child: child,
                  ),
                );
              },
              child: Material(
                color: theme.scaffoldBackgroundColor.withValues(alpha: 0.94),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ExploreFilterChipsBar(
                    controller: _controller,
                    onOpenMore: _openFilters,
                    onOpenNearMe: () => _openFilters(ExploreFilterFocus.nearMe),
                    onOpenLocation: () =>
                        _openFilters(ExploreFilterFocus.location),
                    onOpenIdentity: () =>
                        _openFilters(ExploreFilterFocus.identity),
                    onOpenNextDestination: () =>
                        _openFilters(ExploreFilterFocus.nextDestination),
                    onOpenRecentlyActive: () =>
                        _openFilters(ExploreFilterFocus.recentlyActive),
                  ),
                ),
              ),
            ),
          ),

        if (!_rewardGateVisible && showDeck && !_animating)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: Listenable.merge([_scrollOffset, ?chrome]),
              builder: (context, child) {
                final progress = chrome?.hideProgress ?? 0;
                final measured = chrome?.bottomNavHeight ?? 0;
                final effectiveNavHeight = measured > 0
                    ? measured
                    : (50 + bottomPad);
                final pad = _buttonsBottom(
                  hideProgress: progress,
                  navHeight: effectiveNavHeight,
                  bottomPad: bottomPad,
                );
                return Padding(
                  padding: EdgeInsets.only(bottom: pad),
                  child: child,
                );
              },
              child: ExploreActionBar(
                onSkip: _onSkip,
                onCare: _onCare,
                onConnect: _onConnect,
                enabled: !_animating && !_connecting && !_skipping,
                connecting: _connecting,
              ),
            ),
          ),

        if (!_rewardGateVisible && _showConnectStamp)
          IgnorePointer(
            child: Center(
              child: FadeTransition(
                opacity: _connectStampFade,
                child: Image.asset(
                  'assets/explore/connect-hiking.png',
                  width: 112,
                  height: 112,
                  color: AppColors.isDark(context)
                      ? AppColors.darkTextSecondary
                      : AppColors.primary,
                  colorBlendMode: BlendMode.srcIn,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAnimatedCard(
    FullProfileDto profile, {
    required double topInset,
    required double bottomInset,
  }) {
    final card = ExploreProfileCard(
      key: ValueKey('card-${profile.id}'),
      profile: profile,
      scrollController: _scrollController,
      topInset: topInset,
      bottomInset: bottomInset,
      onMore: _onMorePressed,
      onUndo: _onUndoPressed,
      canUndo: _controller.canUndo,
    );

    // Keep Fade/Scale parents stable so the card State isn't remounted when
    // enter animation ends (that was double-fetching profile activities).
    final Animation<double> fade;
    final Animation<double> scale;
    if (_exitingProfile != null) {
      fade = _exitFade;
      scale = _exitScale;
    } else if (_entering || _enterAnim.isAnimating) {
      fade = _enterFade;
      scale = _enterScale;
    } else {
      fade = const AlwaysStoppedAnimation(1);
      scale = const AlwaysStoppedAnimation(1);
    }

    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: scale,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        child: card,
      ),
    );
  }

  Widget _buildNonReadyBody({required double bottomInset}) {
    final isGold = AuthScope.of(context).isGold;

    switch (_controller.loadState) {
      case ExploreLoadState.idle:
      case ExploreLoadState.loading:
        return const AppLoading(message: 'Searching the world ...');
      case ExploreLoadState.needsLocation:
        return const SizedBox.shrink();
      case ExploreLoadState.dailyLimit:
        return _buildDailyLimitBody(isGold: isGold, bottomInset: bottomInset);
      case ExploreLoadState.unapproved:
        return ExploreUnapprovedView(
          reason: _controller.unapprovedReason,
          bottomInset: bottomInset,
          onEditPhoto: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProfilePhotosScreen(reupload: true),
              ),
            );
          },
        );
      case ExploreLoadState.profileRequired:
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: AppEmptyView(
            title: 'Finish your profile',
            subtitle: 'Complete registration to start exploring people.',
            icon: Icons.person_add_alt_1_outlined,
            actionLabel: 'Retry',
            onAction: () => _controller.bootstrap(),
          ),
        );
      case ExploreLoadState.error:
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: AppEmptyView(
            title: "Couldn't load people",
            subtitle: _controller.error ?? 'Please try again',
            icon: Icons.wifi_off_rounded,
            actionLabel: 'Retry',
            onAction: () => _controller.bootstrap(),
          ),
        );
      case ExploreLoadState.empty:
        if (_controller.error != null) {
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: AppEmptyView(
              title: 'Location needed',
              subtitle: _controller.error,
              icon: Icons.location_off_outlined,
              actionLabel: 'Share location',
              onAction: _controller.requestLocationAgain,
            ),
          );
        }
        return ExploreNoMoreProfilesView(
          onModifySearch: _openFilters,
          bottomInset: bottomInset,
        );
      case ExploreLoadState.ready:
        return const AppLoading(message: 'Searching the world ...');
    }
  }

  Widget _buildDailyLimitBody({
    required bool isGold,
    required double bottomInset,
  }) {
    return ExploreDailyLimitView(
      isGold: isGold,
      bottomInset: bottomInset,
      onExploreActivities: _browseActivityIdeas,
      onUpgrade: isGold
          ? null
          : () {
              UpgradeScreen.open(
                context,
                reason: 'limit_reached',
                from: 'explore',
              );
            },
    );
  }
}
