import 'dart:async';

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/auth/account_restored.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/push/notification_router.dart';
import 'package:fairytrail/push/push_service.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/screens/auth/account_disabled_screen.dart';
import 'package:fairytrail/screens/auth/ask_for_email_screen.dart';
import 'package:fairytrail/screens/auth/delete_goodbye_screen.dart';
import 'package:fairytrail/screens/auth/impersonate_screen.dart';
import 'package:fairytrail/screens/auth/session_expired_screen.dart';
import 'package:fairytrail/screens/auth/welcome_screen.dart';
import 'package:fairytrail/screens/registration/profile_photos_screen.dart';
import 'package:fairytrail/screens/signup/signup_flow_screen.dart';
import 'package:fairytrail/screens/shell/main_shell.dart';
import 'package:fairytrail/theme/app_theme.dart';
import 'package:fairytrail/theme/ios_appearance_sync.dart';
import 'package:fairytrail/theme/theme_controller.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/tracking/tracking_consent_service.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// Force Dart HTTP upload — FileSystemTransport (native) was accepting envelopes
// without uploading them, so Sentry Issues stayed empty.
// ignore: implementation_imports
import 'package:sentry/src/transport/noop_transport.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://2f4ba778d7ee48fd19e020bc4f54d97d@o4509753981337600.ingest.us.sentry.io/4509758460395520';
      // Adds more context data to events (IP address, cookies, user, etc.)
      // https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected/
      options.sendDefaultPii = true;
      options.environment = kReleaseMode
          ? 'production'
          : (kProfileMode ? 'profile' : 'debug');
      options.debug = false;
      // Native FileSystemTransport was set before this callback; reset so
      // SentryClient installs HttpTransport and POSTs envelopes to ingest.
      options.transport = NoOpTransport();
      // Session Replay (matches React Native mobile app)
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await LocalStorage.instance.init();

      // Init push / deep links early (permissions asked later on enable screen).
      // Firebase Core is initialized inside PushService.
      await PushService.instance.initialize();
      await AnalyticsService.instance.initialize();
      await AnalyticsService.instance.logEvent('app_open');

      final themeController = ThemeController();
      setTrackedDarkMode(themeController.isDark);
      setTrackedFindTrailTreasures(
        !await LocalStorage.instance.isPickupTrailMoneyDisabled(),
      );
      // Match iOS window style to app theme (Gboard / system chrome).
      unawaited(IosAppearanceSync.sync(themeController.mode));
      final authController = AuthController();
      final remoteConfigController = RemoteConfigController();
      await authController.bootstrap();
      if (authController.isSignupInProgress) {
        unawaited(PushService.instance.scheduleSignupReminder());
      } else {
        unawaited(PushService.instance.cancelSignupReminder());
      }
      if (authController.isAuthenticated) {
        unawaited(remoteConfigController.refresh());
      }

      runApp(
        SentryWidget(
          child: FairytrailApp(
            themeController: themeController,
            authController: authController,
            remoteConfigController: remoteConfigController,
          ),
        ),
      );
    },
  );
}

class FairytrailApp extends StatefulWidget {
  const FairytrailApp({
    super.key,
    required this.themeController,
    required this.authController,
    required this.remoteConfigController,
  });

  final ThemeController themeController;
  final AuthController authController;
  final RemoteConfigController remoteConfigController;

  @override
  State<FairytrailApp> createState() => _FairytrailAppState();
}

class _FairytrailAppState extends State<FairytrailApp>
    with WidgetsBindingObserver {
  AuthDestination? _destination;
  bool _wasAuthenticated = false;
  String? _remoteConfigUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _destination = _resolveDestination();
    _wasAuthenticated = widget.authController.isAuthenticated;
    _remoteConfigUserId = widget.authController.user?.id;
    widget.authController.addListener(_onAuthChanged);
    widget.themeController.addListener(_onThemeChanged);
    // Handle password-reset deep links while logged out (MainShell may
    // replace this handler later and still forwards password_reset).
    PushService.instance.onNotificationOpen = _onDeepLinkOpen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestTrackingConsentWhenActive());
    });
  }

  Future<void> _requestTrackingConsentWhenActive() {
    return TrackingConsentService.instance.requestAfterInterfaceIsVisible(
      isAppActive: () =>
          mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(IosAppearanceSync.sync(widget.themeController.mode));
      unawaited(_requestTrackingConsentWhenActive());
    }
  }

  // Engine / UIScene still delivers URLs as named routes. This app uses
  // `home:` plus app_links — swallow so WidgetsApp does not pushNamed.
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    return true;
  }

  void _onDeepLinkOpen(Map<String, dynamic> data) {
    // Password reset + impersonate work while logged out. Chat/match opens
    // need MainShell's MessagesController — defer them until it wires the
    // handler.
    final type = data['type']?.toString();
    if (type == 'password_reset' || type == 'impersonate') {
      NotificationRouter.handle(null, data: data, auth: widget.authController);
      return;
    }
    PushService.instance.deferOpen(data);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.authController.removeListener(_onAuthChanged);
    widget.themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  AuthDestination? _resolveDestination() {
    if (!widget.authController.isReady) return null;
    return widget.authController.destination;
  }

  void _onThemeChanged() {
    setTrackedDarkMode(widget.themeController.isDark);
    unawaited(IosAppearanceSync.sync(widget.themeController.mode));
    if (mounted) setState(() {});
  }

  void _onAuthChanged() {
    final authenticated = widget.authController.isAuthenticated;
    final userId = widget.authController.user?.id;
    if (authenticated && !_wasAuthenticated) {
      // Always start each session in light (white) theme.
      widget.themeController.setMode(ThemeMode.light);
    }
    // Login *and* impersonate — A/B keys like weekly are per-user.
    if (authenticated && userId != null && userId != _remoteConfigUserId) {
      widget.remoteConfigController.clear();
      unawaited(widget.remoteConfigController.refresh(force: true));
    } else if (!authenticated) {
      widget.remoteConfigController.clear();
    }
    _remoteConfigUserId = authenticated ? userId : null;
    _wasAuthenticated = authenticated;

    final next = _resolveDestination();
    // Fresh navigator key BEFORE rebuild — a reused GlobalKey pins the old
    // NavigatorState when MaterialApp is remounted via ValueKey(destination),
    // which leaves Login on screen after a successful sign-in.
    if (next != _destination) {
      NotificationRouter.remountNavigator();
      _destination = next;
    }
    if (mounted) setState(() {});
    // After remount, show restore dialog if login cancelled pending_deletion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = NotificationRouter.navigatorKey.currentContext;
      if (ctx == null) return;
      unawaited(maybeShowAccountRestoredAlert(ctx));
    });
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;

    return ThemeScope(
      controller: widget.themeController,
      child: AuthScope(
        controller: widget.authController,
        child: RemoteConfigScope(
          controller: widget.remoteConfigController,
          child: MaterialApp(
            key: ValueKey(destination),
            navigatorKey: NotificationRouter.navigatorKey,
            title: 'Fairytrail',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: widget.themeController.mode,
            builder: (context, child) {
              return ConnectivityRoot(child: child ?? const SizedBox.shrink());
            },
            onUnknownRoute: (settings) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const SizedBox.shrink(),
              );
            },
            home: destination == null
                ? const Scaffold(body: AppLoading())
                : switch (destination) {
                    AuthDestination.welcome => const WelcomeScreen(),
                    AuthDestination.emailSignup => const AskForEmailScreen(
                      showWelcomeBackButton: true,
                      prefillStoredEmail: true,
                    ),
                    AuthDestination.registration => const SignupFlowScreen(),
                    AuthDestination.profilePhotos =>
                      const ProfilePhotosScreen(),
                    AuthDestination.main => const MainShell(),
                    AuthDestination.sessionExpired =>
                      const SessionExpiredScreen(),
                    AuthDestination.impersonate => const ImpersonateScreen(),
                    AuthDestination.accountDisabled =>
                      const AccountDisabledScreen(),
                    AuthDestination.deleteGoodbye => DeleteGoodbyeScreen(
                      onUnderstood: () =>
                          widget.authController.dismissDeleteGoodbye(),
                    ),
                  },
          ),
        ),
      ),
    );
  }
}
