import 'dart:async';
import 'dart:io' show Platform;

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/analytics/meta_events_service.dart';
import 'package:fairytrail/api/check_email.dart';
import 'package:fairytrail/api/get_me.dart';
import 'package:fairytrail/api/login_via_password.dart';
import 'package:fairytrail/api/logout.dart' as logout_api;
import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/api/password_reset.dart' as password_reset_api;
import 'package:fairytrail/api/registration.dart' as registration_api;
import 'package:fairytrail/api/send_timezone.dart';
import 'package:fairytrail/auth/social_auth_service.dart';
import 'package:fairytrail/billing/revenue_cat_service.dart';
import 'package:fairytrail/constants/profile_status.dart';
import 'package:fairytrail/push/notification_prompt_store.dart';
import 'package:fairytrail/push/push_service.dart';
import 'package:fairytrail/registration/background_photo_upload.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/trail_book/trail_book_memory_cache.dart';
import 'package:fairytrail/activities/activities_warm_prefetch.dart';
import 'package:fairytrail/explore/explore_warm_prefetch.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

enum AuthDestination {
  welcome,
  emailSignup,
  registration,
  profilePhotos,
  main,
  sessionExpired,
  impersonate,
  accountDisabled,
  deleteGoodbye,
}

/// Holds auth session state for the app.
class AuthController extends ChangeNotifier {
  AuthController();

  // Highest persisted step ID; Story Time (12) precedes finalization (11).
  static const signupStepCount = 12;

  bool _isReady = false;
  bool _isAuthenticated = false;
  bool _sessionExpired = false;
  UserDto? _user;
  ProfileMetaDto? _profileMeta;
  String? _apiToken;
  int? _signupStep;
  bool _impersonationPending = false;
  String? _pendingImpersonateToken;
  bool _emailSignupRequested = false;

  /// Sticky gate so `/account-disabled` stays visible after local logout (RN).
  bool _accountDisabledGate = false;

  /// Sticky gate for post-delete goodbye (RN `/login/delete-goodbye`).
  bool _deleteGoodbyeGate = false;

  /// Show "Account restored" once after login cancelled pending deletion.
  bool _pendingAccountRestoredAlert = false;

  bool get isReady => _isReady;
  bool get isAuthenticated => _isAuthenticated;
  bool get sessionExpired => _sessionExpired;
  UserDto? get user => _user;
  ProfileMetaDto? get profileMeta => _profileMeta;
  String? get apiToken => _apiToken;
  bool get impersonationPending => _impersonationPending;
  String? get pendingImpersonateToken => _pendingImpersonateToken;

  /// Entitlement — read these globally; do not copy into feature controllers.
  String get tier => _profileMeta?.tier ?? 'gated';
  bool get isGold => _profileMeta?.isGold ?? false;
  bool get isPaid => _profileMeta?.isPaid ?? false;

  /// 1–11 while multi-step signup is in progress; null when done / N/A.
  int? get signupStep => _signupStep;

  bool get isSignupInProgress {
    final step = _signupStep;
    return step != null && step >= 1 && step <= signupStepCount;
  }

  /// A temporary email signup can change its email until registration creates
  /// the profile at the end of step 3.
  bool get canChangeSignupEmail {
    final step = _signupStep;
    return _isAuthenticated &&
        _user == null &&
        _profileMeta == null &&
        step != null &&
        step <= 3;
  }

  /// Where the authenticated user should land (signup resume).
  AuthDestination get destination {
    if (_deleteGoodbyeGate) return AuthDestination.deleteGoodbye;
    if (_accountDisabledGate) return AuthDestination.accountDisabled;
    if (_impersonationPending) return AuthDestination.impersonate;
    if (!_isAuthenticated) {
      return _emailSignupRequested
          ? AuthDestination.emailSignup
          : AuthDestination.welcome;
    }
    if (_sessionExpired) return AuthDestination.sessionExpired;

    if (isSignupInProgress) {
      return AuthDestination.registration;
    }

    final meta = _profileMeta;
    if (meta != null && meta.status == ProfileStatus.disabled) {
      _accountDisabledGate = true;
      return AuthDestination.accountDisabled;
    }
    if (meta == null || !meta.isProfileCompleted) {
      return AuthDestination.registration;
    }
    if (meta.photosCount < 1) {
      final upload = BackgroundPhotoUpload.instance;
      // Pending / failed / just-done uploads: enter main (blocker handles fail).
      if (upload.hasPendingUpload ||
          upload.hasFailedUpload ||
          upload.hasJustCompletedUpload) {
        return AuthDestination.main;
      }
      return AuthDestination.registration;
    }
    return AuthDestination.main;
  }

  /// Applies a live `profile_status_update` websocket payload (RN AppContext).
  Future<void> applyProfileStatusUpdate({
    required String oldStatus,
    required String newStatus,
  }) async {
    final prev = _profileMeta;
    if (prev == null) return;
    if (prev.status == newStatus) return;

    if (newStatus == ProfileStatus.disabled) {
      _accountDisabledGate = true;
    } else if (oldStatus == ProfileStatus.disabled) {
      _accountDisabledGate = false;
    }

    _profileMeta = prev.copyWith(status: newStatus);
    await LocalStorage.instance.setProfileMeta(_profileMeta!.toJson());
    notifyListeners();
    // Refresh /me so reason / photos stay in sync after admin flips status.
    if (newStatus != ProfileStatus.disabled) {
      try {
        await refreshMe();
      } catch (_) {
        // Keep the WS-applied status if offline.
      }
    }
  }

  /// Loads token/user from storage, then refreshes `/me` when possible.
  Future<void> bootstrap() async {
    final storage = LocalStorage.instance;
    final token = await storage.getApiToken();
    final userJson = await storage.getUser();
    final metaJson = await storage.getProfileMeta();
    _signupStep = await storage.getSignupStep();

    if (token != null && token.isNotEmpty) {
      _apiToken = token;
      HttpClient.instance.setAuthToken(token);
      if (await storage.isImpersonating()) {
        HttpClient.instance.setImpersonating(true);
      }
      _isAuthenticated = true;
      if (userJson != null) {
        _user = UserDto.fromJson(userJson);
      }
      if (metaJson != null) {
        _profileMeta = ProfileMetaDto.fromJson(metaJson);
      }

      await NotificationPromptStore.loadForUser(_user?.id);

      try {
        await refreshMe();
        _sessionExpired = false;
        await _reconcileSignupStep();
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          // Token invalid for this API host (common after switching
          // prod ↔ staging). Drop it so the user can sign in fresh.
          await LocalStorage.instance.clearAuth();
          await _clearInMemory();
        } else {
          // Keep cached session if offline / me fails.
          await _configureRevenueCat();
          await _configureAnalytics();
          await _reconcileSignupStep();
        }
      } catch (_) {
        // Keep cached session if offline / me fails.
        await _configureRevenueCat();
        await _configureAnalytics();
        await _reconcileSignupStep();
      }
    } else {
      await _clearInMemory();
    }

    _isReady = true;
    notifyListeners();
  }

  Future<LoginSuccessResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await loginViaPassword(email: email, password: password);
    await _persistSession(result);
    return result;
  }

  /// Completes password reset via email token and signs the user in.
  Future<LoginSuccessResponse> resetPasswordWithToken({
    required String token,
    required String password,
  }) async {
    final result = await password_reset_api.confirmPasswordReset(
      token: token,
      password: password,
    );
    await _persistSession(result);
    return result;
  }

  Future<LoginSuccessResponse> loginWithGoogle() async {
    final result = await SocialAuthService.instance.signInWithGoogle();
    await _persistSession(result);
    return result;
  }

  Future<LoginSuccessResponse> loginWithApple() async {
    final result = await SocialAuthService.instance.signInWithApple();
    await _persistSession(result);
    return result;
  }

  /// Email step: existing → login; new → authenticate draft token → registration.
  Future<EmailCheckResponse> startEmailSignup(String email) async {
    final normalized = email.trim().toLowerCase();
    final result = await checkEmail(normalized);
    final existingDraft = _emailSignupRequested
        ? await LocalStorage.instance.getRegistrationData()
        : null;

    await LocalStorage.instance.clearAuth();
    await LocalStorage.instance.setEmail(normalized);
    await _clearInMemory();
    BackgroundPhotoUpload.instance.reset();

    if (!result.isEmailExists) {
      if (existingDraft != null) {
        await LocalStorage.instance.setRegistrationData(existingDraft);
      }
      final token = result.apiToken;
      if (token == null || token.isEmpty) {
        throw StateError('Email check did not return a signup token');
      }
      await LocalStorage.instance.setApiToken(token);
      HttpClient.instance.setAuthToken(token);
      _apiToken = token;
      _isAuthenticated = true;
      _emailSignupRequested = false;
      await setSignupStep(1);
    }

    return result;
  }

  /// Discards the temporary signup token and returns to email entry. This is
  /// intentionally unavailable after the profile has been registered.
  Future<void> changeSignupEmail() async {
    if (!canChangeSignupEmail) return;

    final draft = await LocalStorage.instance.getRegistrationData();
    BackgroundPhotoUpload.instance.reset();
    await LocalStorage.instance.clearAuth();
    if (draft != null) {
      await LocalStorage.instance.setRegistrationData(draft);
    }
    await _clearInMemory();
    _emailSignupRequested = true;
    notifyListeners();
  }

  void cancelEmailSignup() {
    if (_isAuthenticated || !_emailSignupRequested) return;
    _emailSignupRequested = false;
    notifyListeners();
  }

  Future<void> setSignupStep(int step) async {
    final wasInProgress = isSignupInProgress;
    final clamped = step.clamp(1, signupStepCount);
    _signupStep = clamped;

    // Don't persist past the photo step until /me has a real photo URL.
    // Local upload paths are in-memory only and vanish on restart.
    final meta = _profileMeta;
    final hasConfirmedPhoto =
        meta != null &&
        meta.photosCount >= 1 &&
        (meta.photoUrl?.isNotEmpty ?? false);
    final persistAs = (!hasConfirmedPhoto && clamped > 6) ? 6 : clamped;
    await LocalStorage.instance.setSignupStep(persistAs);
    if (!wasInProgress) {
      unawaited(PushService.instance.scheduleSignupReminder());
    }
    notifyListeners();
  }

  /// Clears signup progress and enters main.
  Future<void> completeSignupFlow() async {
    _signupStep = null;
    await PushService.instance.cancelSignupReminder();
    await LocalStorage.instance.deleteSignupStep();
    await LocalStorage.instance.deleteRegistrationData();
    await LocalStorage.instance.deletePhotoUploadCommitted();
    // Woman-first Explore deck once after signup — not on later logins.
    await LocalStorage.instance.markPendingSignupFirstExplore();
    notifyListeners();
  }

  Future<RegistrationSuccessResponse> completeRegistration(
    RegistrationRequest request,
  ) async {
    await LocalStorage.instance.setRegistrationData(request.toJson());
    final result = await registration_api.register(request);

    await LocalStorage.instance.setApiToken(result.apiToken);
    HttpClient.instance.setAuthToken(result.apiToken);
    _apiToken = result.apiToken;
    _isAuthenticated = true;

    // RN registration screen calls sendTimezone after auth (fills Timezone2 + IP1).
    final pushToken = await LocalStorage.instance.getPushToken();
    unawaited(sendTimezone(pushToken: pushToken));
    await LocalStorage.instance.clearAlreadyConnected();
    // New user — prompt cache starts fresh (per-user key not set yet).
    await NotificationPromptStore.loadForUser(result.userId);

    final method = (request.email != null && request.email!.isNotEmpty)
        ? 'email'
        : 'social';
    final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

    unawaited(
      AnalyticsService.instance.logEvent('account_created', {
        'method': method,
        'platform': platform,
        'profile_type': request.profileType,
        'user_id': result.userId,
      }),
    );
    unawaited(
      MetaEventsService.instance.logRegistrationCompleted(
        registrationMethod: method,
        profileType: request.profileType,
        userId: result.userId,
        additionalData: request.toJson(),
      ),
    );

    _profileMeta = const ProfileMetaDto(
      id: 0,
      isProfileCompleted: true,
      photosCount: 0,
      status: 'incomplete',
    );
    await LocalStorage.instance.setProfileMeta(_profileMeta!.toJson());

    if (request.email != null && request.email!.isNotEmpty) {
      await LocalStorage.instance.setEmail(request.email!);
    }

    // Keep multi-step signup active; the flow screen advances the step.
    if (_signupStep == null) {
      _signupStep = 3;
      await LocalStorage.instance.setSignupStep(3);
    }
    notifyListeners();
    return result;
  }

  Future<void> markPhotosComplete() async {
    // Keep registration draft until the full signup flow finishes.
    await LocalStorage.instance.deletePhotoUploadCommitted();

    final prev = _profileMeta;
    _profileMeta =
        (prev ??
                const ProfileMetaDto(
                  id: 0,
                  isProfileCompleted: true,
                  photosCount: 0,
                  status: 'active',
                ))
            .copyWith(
              isProfileCompleted: true,
              // In-memory only — BackgroundPhotoUpload path is not durable.
              // Persisting photosCount:1 would resume past the photo step on
              // restart before /me confirms a real upload.
              photosCount: (prev?.photosCount ?? 0) < 1 ? 1 : prev!.photosCount,
              status: prev?.status ?? 'active',
            );
    notifyListeners();
  }

  /// After failed upload — send user back to photo step.
  Future<void> beginPhotoReupload() async {
    BackgroundPhotoUpload.instance.reset();
    final prev = _profileMeta;
    _profileMeta =
        (prev ??
                const ProfileMetaDto(
                  id: 0,
                  isProfileCompleted: true,
                  photosCount: 0,
                  status: 'incomplete',
                ))
            .copyWith(
              isProfileCompleted: true,
              photosCount: 0,
              status: prev?.status ?? 'incomplete',
            );
    await LocalStorage.instance.setProfileMeta(_profileMeta!.toJson());
    notifyListeners();
  }

  Future<void> markLocationSet() async {
    final prev = _profileMeta;
    if (prev == null) return;
    _profileMeta = prev.copyWith(isLocationSet: true);
    await LocalStorage.instance.setProfileMeta(_profileMeta!.toJson());
    notifyListeners();
    try {
      await refreshMe();
    } catch (_) {}
  }

  Future<void> refreshMe() async {
    final info = await getMe();
    _user = info.user;
    _profileMeta = info.profileMeta;
    _sessionExpired = false;
    await LocalStorage.instance.setUser(info.user.toJson());
    await LocalStorage.instance.setProfileMeta(info.profileMeta.toJson());
    await NotificationPromptStore.loadForUser(info.user.id);
    await _configureRevenueCat();
    await _configureAnalytics();
    notifyListeners();
  }

  /// Retries `/me` from the session-expired screen.
  Future<void> retrySession() async {
    await refreshMe();
    await _reconcileSignupStep();
    notifyListeners();
  }

  /// Optimistic tier flip after verification purchase (webhook is source of truth).
  Future<void> setTierOptimistic(String tier) async {
    final prev = _profileMeta;
    if (prev == null) return;
    _profileMeta = prev.copyWith(tier: tier);
    await LocalStorage.instance.setProfileMeta(_profileMeta!.toJson());
    notifyListeners();
  }

  Future<void> logout() async {
    unawaited(track('logged_out'));
    unawaited(AnalyticsService.instance.logEvent('logged_out'));
    try {
      await logout_api.logout();
    } catch (_) {
      // Still clear local session even if the network call fails.
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    BackgroundPhotoUpload.instance.reset();
    TrailBookMemoryCache.instance.clear();
    ActivitiesWarmPrefetch.instance.clear();
    ExploreWarmPrefetch.instance.clear();
    await PushService.instance.cancelSignupReminder();
    await PushService.instance.unregister();
    await RevenueCatService.instance.logOut();
    await resetUserAliasId();
    await LocalStorage.instance.clearAuth();
    await _clearInMemory();
    notifyListeners();
  }

  /// Local reset after admin disables the account (keeps disabled screen up).
  Future<void> clearSessionForDisabledAccount() async {
    _accountDisabledGate = true;
    await clearSession();
  }

  /// After DELETE /delete-account — show goodbye, then welcome on dismiss.
  Future<void> enterDeleteGoodbye() async {
    _deleteGoodbyeGate = true;
    _accountDisabledGate = false;
    await clearSession();
  }

  /// RN "Understood" on delete-goodbye → back to welcome.
  void dismissDeleteGoodbye() {
    if (!_deleteGoodbyeGate) return;
    _deleteGoodbyeGate = false;
    notifyListeners();
  }

  /// Consumes the one-shot restore alert after login (MainShell shows it).
  bool consumeAccountRestoredAlert() {
    if (!_pendingAccountRestoredAlert) return false;
    _pendingAccountRestoredAlert = false;
    return true;
  }

  /// Opens the admin impersonation confirm screen (deep link entry).
  ///
  /// RN: `/dl/impersonate/{apiToken}` → ImpersonateScreen.
  void prepareImpersonation(String apiToken) {
    var sanitized = apiToken.trim();
    if (sanitized.contains('&app')) {
      sanitized = sanitized.split('&app').first;
    }
    if (sanitized.isEmpty) return;
    _pendingImpersonateToken = sanitized;
    _impersonationPending = true;
    notifyListeners();
  }

  /// Clears the current session, signs in as the impersonated user, and
  /// marks the HTTP client with `X-IMPERSONATING` (RN ImpersonateScreen).
  Future<void> executeImpersonation() async {
    final token = _pendingImpersonateToken;
    if (token == null || token.isEmpty) {
      throw StateError('No impersonation token');
    }

    // Local reset only — do not call logout API (RN authService.resetAuth).
    BackgroundPhotoUpload.instance.reset();
    await PushService.instance.cancelSignupReminder();
    await PushService.instance.unregister();
    await RevenueCatService.instance.logOut();
    await LocalStorage.instance.clearAuth();
    // Keep pending token / confirm screen through the in-memory clear.
    HttpClient.instance.setAuthToken(null);
    HttpClient.instance.setImpersonating(false);
    _apiToken = null;
    _user = null;
    _profileMeta = null;
    _isAuthenticated = false;
    _sessionExpired = false;
    _signupStep = null;

    await LocalStorage.instance.setApiToken(token);
    HttpClient.instance.setAuthToken(token);
    _apiToken = token;
    _isAuthenticated = true;
    _impersonationPending = true;
    _pendingImpersonateToken = token;

    await refreshMe();

    await LocalStorage.instance.startImpersonation();
    HttpClient.instance.setImpersonating(true);
    notifyListeners();
  }

  /// Leaves the confirm screen and enters the app as the impersonated user.
  void confirmImpersonation() {
    _impersonationPending = false;
    _pendingImpersonateToken = null;
    notifyListeners();
  }

  /// Drops a failed impersonation attempt and returns to welcome/login.
  ///
  /// Local reset only — the impersonation token is invalid, so do not call
  /// the logout API.
  Future<void> cancelImpersonation() async {
    await clearSession();
  }

  Future<void> _clearInMemory() async {
    HttpClient.instance.setAuthToken(null);
    HttpClient.instance.setImpersonating(false);
    _apiToken = null;
    _user = null;
    _profileMeta = null;
    _isAuthenticated = false;
    _sessionExpired = false;
    _signupStep = null;
    _impersonationPending = false;
    _pendingImpersonateToken = null;
    NotificationPromptStore.clear();
  }

  Future<void> _persistSession(LoginSuccessResponse result) async {
    final storage = LocalStorage.instance;
    await storage.setApiToken(result.apiToken);
    await storage.setEmail(result.user.email);
    await storage.setUser(result.user.toJson());
    await storage.setProfileMeta(result.profileMeta.toJson());
    // Connect intro once per login session.
    await storage.clearHasSeenFakeConnectIntro();

    HttpClient.instance.setAuthToken(result.apiToken);
    _apiToken = result.apiToken;
    _user = result.user;
    _profileMeta = result.profileMeta;
    _isAuthenticated = true;
    _emailSignupRequested = false;
    _sessionExpired = false;
    _accountDisabledGate = result.profileMeta.status == ProfileStatus.disabled;
    _deleteGoodbyeGate = false;
    if (result.accountRestored) {
      _pendingAccountRestoredAlert = true;
    }

    final meta = result.profileMeta;
    if (!meta.isProfileCompleted || meta.photosCount < 1) {
      // Set step without notifying — single notify below drives navigation.
      final step = !meta.isProfileCompleted ? 1 : 6;
      _signupStep = step;
      await storage.setSignupStep(step);
    } else {
      _signupStep = null;
      await storage.deleteSignupStep();
    }

    // Navigate immediately — RevenueCat/StoreKit must not block login.
    // Prompt flag is a cheap local read; load before UI so connect check is sync.
    await NotificationPromptStore.loadForUser(result.user.id);
    notifyListeners();
    unawaited(_configureRevenueCat());
    unawaited(_configureAnalytics());
    // RN main index sends timezone on every authenticated session.
    unawaited(() async {
      final pushToken = await LocalStorage.instance.getPushToken();
      await sendTimezone(pushToken: pushToken);
    }());
  }

  /// Aligns persisted step with server profile state after bootstrap/refresh.
  Future<void> _reconcileSignupStep() async {
    final meta = _profileMeta;
    if (meta == null) return;

    if (meta.isProfileCompleted &&
        meta.photosCount >= 1 &&
        (meta.photoUrl?.isNotEmpty ?? false) &&
        meta.isLocationSet &&
        (_signupStep == null || _signupStep! > signupStepCount)) {
      _signupStep = null;
      await LocalStorage.instance.deleteSignupStep();
      return;
    }

    if (!meta.isProfileCompleted) {
      if (_signupStep == null || _signupStep! < 1) {
        await setSignupStep(1);
      }
      return;
    }

    final hasConfirmedPhoto =
        meta.photosCount >= 1 && (meta.photoUrl?.isNotEmpty ?? false);
    final hasLocalPhoto =
        BackgroundPhotoUpload.instance.photoPath?.isNotEmpty == true;

    // Photo step (6) and beyond require a durable photo. Local upload state is
    // in-memory only — on restart, pull back to profile upload.
    if (!hasConfirmedPhoto) {
      final step = _signupStep ?? 0;
      if (step > 6 && !hasLocalPhoto) {
        if (meta.photosCount != 0) {
          _profileMeta = meta.copyWith(photosCount: 0);
          await LocalStorage.instance.setProfileMeta(_profileMeta!.toJson());
        }
        await setSignupStep(6);
      } else if (step < 6) {
        await setSignupStep(6);
      }
      return;
    }

    // Profile + photos done but still mid post-photo signup (location/rate/upgrade).
    if (_signupStep == null && !meta.isLocationSet) {
      await setSignupStep(9);
    }
  }

  Future<void> _configureRevenueCat() async {
    final userId = _user?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      await RevenueCatService.instance.configure(userId);
    } catch (e) {
      debugPrint('[Auth] RevenueCat configure failed: $e');
    }
  }

  Future<void> _configureAnalytics() async {
    final userId = _user?.id;
    if (userId == null || userId.isEmpty) return;
    await AnalyticsService.instance.identify(userId);
  }
}

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope not found in widget tree');
    return scope!.notifier!;
  }
}
