import 'dart:async';

import 'package:fairytrail/activities/activities_warm_prefetch.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/auth/account_restored.dart';
import 'package:fairytrail/api/send_timezone.dart';
import 'package:fairytrail/components/location/location_prompt_view.dart';
import 'package:fairytrail/components/profile/travel_style_prompt_view.dart';
import 'package:fairytrail/config/app_version.dart';
import 'package:fairytrail/explore/explore_warm_prefetch.dart';
import 'package:fairytrail/location/location_service.dart';
import 'package:fairytrail/messages/incoming_connects_controller.dart';
import 'package:fairytrail/messages/messages_controller.dart';
import 'package:fairytrail/push/notification_router.dart';
import 'package:fairytrail/push/push_service.dart';
import 'package:fairytrail/registration/background_photo_upload.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/screens/bucket_list/bucket_list_screen.dart';
import 'package:fairytrail/screens/explore/begin_journey_screen.dart';
import 'package:fairytrail/screens/explore/explore_screen.dart';
import 'package:fairytrail/screens/explore/fake_connect_intro_screen.dart';
import 'package:fairytrail/screens/force_update/app_outdated_screen.dart';
import 'package:fairytrail/screens/meetups/meetups_screen.dart';
import 'package:fairytrail/screens/messages/messages_screen.dart';
import 'package:fairytrail/screens/profile/profile_screen.dart';
import 'package:fairytrail/screens/registration/finish_photo_upload_screen.dart';
import 'package:fairytrail/screens/shell/admin_popup_webview_screen.dart';
import 'package:fairytrail/screens/shell/floating_bottom_nav.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/trail_book/postcard_inbox.dart';
import 'package:fairytrail/gift_subscription/gift_subscription_inbox.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fairytrail/widgets/widgets.dart';

enum _LocationGate {
  /// Waiting until intro/begin-journey gates clear.
  pending,

  /// OS permission check in progress (Explore must not show yet).
  checking,

  /// No OS location permission / services — full-screen "Where are you?".
  blocked,

  /// OS location permission granted this session.
  ready,
}

/// Root shell with floating bottom nav and tab pages.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  AppTab _current = AppTab.explore;
  final _upload = BackgroundPhotoUpload.instance;
  late final ShellChromeController _chrome;
  late final MessagesController _messages;
  late final IncomingConnectsController _incoming;
  AuthController? _auth;
  bool _beginJourneyDone = false;
  bool _fakeConnectIntroDone = false;

  /// After educational intro this session, always show Begin Journey next.
  bool _beginJourneyAfterIntro = false;

  /// null = still loading local flag (avoid flashing Begin Journey first).
  bool? _hasSeenFakeConnectIntro;

  _LocationGate _locationGate = _LocationGate.pending;
  String? _locationBlockMessage;
  bool _locationNeedsSettings = false;
  bool _coldOpenLocationScheduled = false;
  bool _resettingInactiveReminder = false;
  bool _adminPopupChecked = false;

  /// Meetups tab + meetup group chats; kept in sync with remote config.
  bool? _meetupsVisible;

  /// Re-apply after init/`/me` on resume so enable/disable takes effect immediately.
  Future<void> _syncMeetupsVisibilityOnResume() async {
    await Future.wait([_refreshRemoteConfig(), _refreshUserOnResume()]);
    if (!mounted) return;
    final visible = _applyMeetupsVisibility(context);
    _messages.markRemoteConfigReady();
    if (!visible && _current == AppTab.meetups) {
      setState(() => _current = AppTab.explore);
    } else {
      setState(() {});
    }
  }

  /// Applies remote meetup flag once /init is ready (no flicker from unset → false → true).
  bool _applyMeetupsVisibility(BuildContext context) {
    final remote = RemoteConfigScope.maybeOf(context);
    if (remote == null || !remote.isReady) {
      return _meetupsVisible ?? false;
    }
    final visible = remote.meetupsVisibleForProfile(
      AuthScope.of(context).profileMeta?.countryCode,
    );
    final changed = _meetupsVisible != visible;
    _meetupsVisible = visible;
    _messages.setMeetupChatsVisible(visible);
    if (changed && !visible && _current == AppTab.meetups) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_current == AppTab.meetups && !(_meetupsVisible ?? false)) {
          setState(() => _current = AppTab.explore);
        }
      });
    }
    return visible;
  }

  bool _showMeetupsTab(BuildContext context) => _applyMeetupsVisibility(context);

  /// Cold start: remote config → meetup visibility → allow inbox group-chat fetches.
  Future<void> _bootstrapRemoteConfigForInbox() async {
    await _refreshRemoteConfig();
    if (!mounted) return;
    _applyMeetupsVisibility(context);
    _messages.markRemoteConfigReady();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chrome = ShellChromeController(onSelectTab: _onTabChanged);
    _messages = MessagesController();
    MessagesScope.active = _messages;
    ShellChromeScope.active = _chrome;
    _incoming = IncomingConnectsController();
    _upload.addListener(_onUploadChanged);
    _chrome.addListener(_onChrome);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadFakeConnectIntroFlag());
      unawaited(_bootstrapMessages());
      // Remote config first so activity/meetup chats don't race meetup_enabled.
      unawaited(_bootstrapRemoteConfigForInbox());
      unawaited(_resetInactiveReminderOnEntry());
      unawaited(maybeShowAccountRestoredAlert(context));
    });
  }

  Future<void> _loadFakeConnectIntroFlag() async {
    final seen = await LocalStorage.instance.getHasSeenFakeConnectIntro();
    if (!mounted) return;
    setState(() => _hasSeenFakeConnectIntro = seen);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _adminPopupChecked = false;
      unawaited(_resetInactiveReminderOnEntry());
      // Remote config → meetup visibility, then inbox only if on Messages.
      unawaited(() async {
        await _syncMeetupsVisibilityOnResume();
        if (!mounted) return;
        if (_current == AppTab.messages) {
          await _messages.ensureInboxStarted();
        }
      }());
      // RN loadUnreadTrailBook when app becomes active.
      unawaited(PostcardInbox.checkUnread());
      unawaited(GiftSubscriptionInbox.checkPending());
      unawaited(_maybeRefreshLocationOnResume());
      _maybeShowAdminPopup();
    }
  }

  Future<void> _resetInactiveReminderOnEntry() async {
    if (_resettingInactiveReminder) return;
    _resettingInactiveReminder = true;
    try {
      await _refreshRemoteConfig();
      if (mounted) {
        _applyMeetupsVisibility(context);
        _messages.markRemoteConfigReady();
      }
      await PushService.instance.clearInactiveReminder();
      if (!mounted) return;
      final params = RemoteConfigScope.maybeOf(
        context,
      )?.init?.scheduledLocalNotificationParams;
      await PushService.instance.scheduleInactiveReminder(
        // 3 days — ignore remote-config test values (e.g. staging duration: 5).
        durationMinutes: 4320,
        title: params?.title ?? '5,000+ people joined since your last visit!',
        body: params?.body ?? 'Tap to check out new profiles.',
      );
    } finally {
      _resettingInactiveReminder = false;
    }
  }

  Future<void> _refreshRemoteConfig() async {
    try {
      await RemoteConfigScope.of(context).refresh();
    } catch (_) {
      // Don't block the app if init fails (offline, etc.).
    }
  }

  Future<void> _refreshUserOnResume() async {
    final auth = _auth;
    if (auth == null || !auth.isAuthenticated) return;
    try {
      await auth.refreshMe();
    } catch (_) {
      // Don't block the app if /me fails (offline, etc.).
    }
  }

  /// Gate Explore on OS location permission only.
  ///
  /// Permission granted → ready (GPS refresh runs in the background).
  /// Otherwise → "Where are you?" blocker. Does not request permission here;
  /// [LocationPromptView] does that when the user taps Share location.
  Future<void> _resolveLocationPermissionGate({required String logTag}) async {
    final serviceEnabled = await LocationService.isServiceEnabled();
    final permission = await LocationService.checkPermission();
    final permissionGranted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    if (!mounted) return;

    if (!serviceEnabled || !permissionGranted) {
      final needsSettings =
          !serviceEnabled || permission == LocationPermission.deniedForever;
      setState(() {
        _locationGate = _LocationGate.blocked;
        _locationNeedsSettings = needsSettings;
        _locationBlockMessage = !serviceEnabled
            ? 'Turn on Location Services to continue.'
            : needsSettings
            ? LocationService.appLocationSettingsMessage
            : null;
      });
      return;
    }

    setState(() => _locationGate = _LocationGate.ready);
    final auth = AuthScope.of(context);
    ExploreWarmPrefetch.instance.start(profileMeta: auth.profileMeta);
    unawaited(
      LocationService.refreshLocationInBackground(
        updateCountry: true,
        logTag: logTag,
      ),
    );
  }

  /// Background → foreground: re-check permission; if still granted, refresh
  /// GPS in the background. No permission prompt.
  Future<void> _maybeRefreshLocationOnResume() async {
    if (!mounted) return;
    if (_locationGate != _LocationGate.ready &&
        _locationGate != _LocationGate.blocked) {
      return;
    }
    final auth = _auth;
    if (auth == null || !auth.isAuthenticated) return;

    final serviceEnabled = await LocationService.isServiceEnabled();
    final permission = await LocationService.checkPermission();
    if (!mounted) return;

    final permissionGranted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    if (!serviceEnabled || !permissionGranted) {
      final needsSettings =
          !serviceEnabled || permission == LocationPermission.deniedForever;
      setState(() {
        _locationGate = _LocationGate.blocked;
        _locationNeedsSettings = needsSettings;
        _locationBlockMessage = !serviceEnabled
            ? 'Turn on Location Services to continue.'
            : needsSettings
            ? LocationService.appLocationSettingsMessage
            : null;
      });
      return;
    }

    if (_locationGate != _LocationGate.ready) {
      setState(() => _locationGate = _LocationGate.ready);
    }
    unawaited(
      LocationService.refreshLocationInBackground(
        updateCountry: true,
        logTag: 'Location/resume',
      ),
    );
  }

  /// After intro gates: set [checking] synchronously so Explore never flashes,
  /// then resolve permission → ready or "Where are you?" blocker.
  void _maybeStartColdOpenLocationCheck() {
    if (_locationGate != _LocationGate.pending) return;
    if (_coldOpenLocationScheduled) return;
    if (_upload.hasFailedUpload) return;
    if (_hasSeenFakeConnectIntro == null &&
        !FakeConnectIntroScreen.shouldSkipForDevice(context)) {
      return;
    }
    if (_shouldShowFakeConnectIntro) return;
    if (_shouldAskBeginJourney) return;

    _coldOpenLocationScheduled = true;
    _locationGate = _LocationGate.checking;
    _locationBlockMessage = null;
    _locationNeedsSettings = false;

    unawaited(_resolveLocationPermissionGate(logTag: 'Location/cold-open'));
  }

  Future<void> _bootstrapMessages() async {
    final auth = AuthScope.of(context);
    _auth = auth;
    _messages.setToastCallbacks(
      onNewMessage: () {
        if (!mounted) return;
        if (_current == AppTab.messages) return;
        AppToast.show(context, message: 'New message');
      },
      onNewMatch: () {
        if (!mounted) return;
        AppToast.show(context, message: 'New connection!');
      },
    );
    _messages.setPostcardCallback(
      onNewPostcard: (id) {
        unawaited(PostcardInbox.presentFromWs({'postcardId': id}));
      },
    );
    _messages.setProfileStatusCallback(
      onProfileStatusUpdate: (oldStatus, newStatus) {
        unawaited(
          auth.applyProfileStatusUpdate(
            oldStatus: oldStatus,
            newStatus: newStatus,
          ),
        );
      },
    );
    await _messages.bootstrap(
      userId: auth.user?.id,
      token: auth.apiToken,
      profileStatus: auth.profileMeta?.status,
    );
    // Catch postcards missed while the WS was down (RN loadUnreadTrailBook).
    unawaited(PostcardInbox.checkUnread());
    unawaited(GiftSubscriptionInbox.checkPending());
    auth.addListener(_onAuthChanged);

    // Activities feed needs no location — warm during intro / location gate.
    ActivitiesWarmPrefetch.instance.start();

    // People: after location is on the server, run Get Started flow early
    // (seed prefs → matches → prefetch) while Begin Journey is on screen.
    final locationSet = auth.profileMeta?.isLocationSet ?? false;
    if (locationSet) {
      ExploreWarmPrefetch.instance.start(profileMeta: auth.profileMeta);
    }

    // Wire notification / deep-link opens → Messages tab / password reset.
    PushService.instance.onNotificationOpen = (data) {
      if (!mounted) {
        NotificationRouter.handle(
          null,
          data: data,
          auth: auth,
          messages: _messages,
          chrome: _chrome,
          incoming: _incoming,
        );
        return;
      }
      NotificationRouter.handle(
        context,
        data: data,
        messages: _messages,
        chrome: _chrome,
        auth: auth,
        incoming: _incoming,
      );
    };

    // Soft token refresh if permission already granted (RN usePushNotifications).
    // Permission prompt is deferred to first Connect / first message send.
    PushService.instance.refreshIfPermitted();

    // RN main/index always posts timezone (+ records IP for IP1 / Timezone2).
    unawaited(() async {
      final pushToken = await LocalStorage.instance.getPushToken();
      await sendTimezone(pushToken: pushToken);
    }());
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (auth == null) return;
    _messages.updateAuth(
      userId: auth.user?.id,
      token: auth.apiToken,
      profileStatus: auth.profileMeta?.status,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.removeListener(_onAuthChanged);
    _upload.removeListener(_onUploadChanged);
    _chrome.removeListener(_onChrome);
    if (identical(MessagesScope.active, _messages)) {
      MessagesScope.active = null;
    }
    if (identical(ShellChromeScope.active, _chrome)) {
      ShellChromeScope.active = null;
    }
    _chrome.dispose();
    _messages.dispose();
    _incoming.dispose();
    super.dispose();
  }

  void _onChrome() {
    if (mounted) setState(() {});
  }

  Future<void> _onUploadChanged() async {
    if (!mounted) return;
    setState(() {});

    if (_upload.status == BackgroundPhotoUploadStatus.done) {
      try {
        await AuthScope.of(context).refreshMe();
      } catch (_) {}
      _upload.acknowledgeCompleted();
    }
  }

  bool get _shouldShowFakeConnectIntro {
    if (_fakeConnectIntroDone) return false;
    if (_hasSeenFakeConnectIntro != false) return false;
    if (_upload.hasFailedUpload) return false;
    if (FakeConnectIntroScreen.shouldSkipForDevice(context)) return false;
    return true;
  }

  bool get _shouldAskBeginJourney {
    if (_beginJourneyDone) return false;
    if (_upload.hasFailedUpload) return false;
    // Wait until fake-intro flag is known / dismissed so it isn't shown second.
    if (_hasSeenFakeConnectIntro == null &&
        !FakeConnectIntroScreen.shouldSkipForDevice(context)) {
      return false;
    }
    if (_shouldShowFakeConnectIntro) return false;
    // Always follow educational/fake profile with Begin Journey.
    if (_beginJourneyAfterIntro) return true;
    final meta = AuthScope.of(context).profileMeta;
    return meta != null && meta.matchWithCount < 1;
  }

  bool get _shouldAskTravelStyle {
    // Null travel_style is Solo Traveler by convention — no mandatory prompt.
    return false;
  }

  void _onFakeConnectIntroDone() {
    if (!mounted) return;
    setState(() {
      _fakeConnectIntroDone = true;
      _beginJourneyAfterIntro = true;
      _beginJourneyDone = false;
    });
  }

  Future<void> _onBeginJourneyDone() async {
    if (!mounted) return;
    setState(() {
      _beginJourneyDone = true;
      _beginJourneyAfterIntro = false;
      _coldOpenLocationScheduled = true;
      _locationGate = _LocationGate.checking;
      _locationBlockMessage = null;
      _locationNeedsSettings = false;
    });
    await _resolveLocationPermissionGate(
      logTag: 'Location/after-begin-journey',
    );
  }

  Future<void> _onLocationSuccess() async {
    final auth = AuthScope.of(context);
    await auth.markLocationSet();
    ExploreWarmPrefetch.instance.start(profileMeta: auth.profileMeta);
    if (mounted) setState(() => _locationGate = _LocationGate.ready);
  }

  void _onTravelStyleSuccess() {
    if (mounted) setState(() {});
  }

  void _maybeShowAdminPopup() {
    if (_adminPopupChecked) return;
    if (_locationGate != _LocationGate.ready) return;
    _adminPopupChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await RemoteConfigScope.of(context).refresh();
      } catch (_) {}
      if (!mounted) return;
      final remote = RemoteConfigScope.of(context);
      final userId = AuthScope.of(context).user?.id;
      await AdminPopupWebViewScreen.maybeShow(
        context,
        userId: userId,
        enabled: remote.showAdminPopup,
        version: remote.showAdminPopupVersion,
        url: remote.showAdminPopupUrl,
      );
    });
  }

  void _onTabChanged(AppTab tab) {
    if (tab == AppTab.meetups && !_showMeetupsTab(context)) return;
    _chrome.show();
    setState(() => _current = tab);
    if (tab == AppTab.messages) {
      unawaited(_messages.ensureInboxStarted());
    }
  }

  @override
  Widget build(BuildContext context) {
    final remote = RemoteConfigScope.of(context);
    final forceUpdate = !AppVersionInfo.isAcceptableBuild(
      remote.acceptableBuild,
    );
    final maintenance = remote.isMaintenance;

    if (forceUpdate) {
      return AppOutdatedScreen(
        acceptableBuild: remote.acceptableBuild,
        onRecheck: _refreshRemoteConfig,
      );
    }

    if (maintenance) {
      return const AppMaintenanceScreen();
    }

    if (_upload.hasFailedUpload) {
      return const FinishPhotoUploadScreen();
    }

    if (_hasSeenFakeConnectIntro == null &&
        !FakeConnectIntroScreen.shouldSkipForDevice(context)) {
      // Avoid flashing Begin Journey before we know whether to show fake intro.
      return const SizedBox.shrink();
    }
    if (_shouldShowFakeConnectIntro) {
      return FakeConnectIntroScreen(onDone: _onFakeConnectIntroDone);
    }

    if (_shouldAskBeginJourney) {
      return BeginJourneyScreen(onDone: _onBeginJourneyDone);
    }

    // After intro gates: sync flip to [checking], then resolve OS permission.
    _maybeStartColdOpenLocationCheck();

    if (_locationGate == _LocationGate.pending ||
        _locationGate == _LocationGate.checking) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_locationGate == _LocationGate.blocked) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AppSafeArea(
          child: LocationPromptView(
            autoAsk: false,
            initialError: _locationBlockMessage,
            initialNeedsSettings: _locationNeedsSettings,
            onSuccess: _onLocationSuccess,
          ),
        ),
      );
    }

    if (_shouldAskTravelStyle) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AppSafeArea(
          child: TravelStylePromptView(onSuccess: _onTravelStyleSuccess),
        ),
      );
    }

    _maybeShowAdminPopup();

    final navVisible = _current != AppTab.explore || _chrome.visible;
    final hideProgress = _current == AppTab.explore
        ? _chrome.hideProgress
        : 0.0;
    final navHeight = _chrome.bottomNavHeight;
    return IncomingConnectsScope(
      controller: _incoming,
      child: MessagesScope(
        controller: _messages,
        child: ShellChromeScope(
          controller: _chrome,
          child: ListenableBuilder(
            listenable: Listenable.merge([_messages, _incoming]),
            builder: (context, _) {
              final showMeetups = _showMeetupsTab(context);
              final nav = MeasureSize(
                onChange: (size) => _chrome.setBottomNavHeight(size.height),
                child: FloatingBottomNav(
                  current: _current,
                  onChanged: _onTabChanged,
                  messagesBadge: _messages.unreadCount,
                  showMeetups: showMeetups,
                ),
              );

              final bottomBar = Transform.translate(
                offset: Offset(0, navHeight * hideProgress),
                child: Opacity(
                  opacity: (1.0 - hideProgress).clamp(0.0, 1.0),
                  child: IgnorePointer(
                    ignoring: !navVisible || hideProgress > 0.9,
                    child: nav,
                  ),
                ),
              );

              return Scaffold(
                extendBody: true,
                body: IndexedStack(
                  index: _current.index,
                  children: [
                    const ExploreScreen(),
                    BucketListScreen(isActive: _current == AppTab.bucketList),
                    MeetupsScreen(isActive: _current == AppTab.meetups),
                    MessagesScreen(isActive: _current == AppTab.messages),
                    ProfileScreen(isActive: _current == AppTab.profile),
                  ],
                ),
                bottomNavigationBar: bottomBar,
              );
            },
          ),
        ),
      ),
    );
  }
}
