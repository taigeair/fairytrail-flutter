import 'dart:async';

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/analytics/meta_events_service.dart';
import 'package:fairytrail/api/chat.dart' as chat_api;
import 'package:fairytrail/api/explore.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/api/prefs.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/config/explore_options.dart';
import 'package:fairytrail/config/upcoming_destinations.dart';
import 'package:fairytrail/constants/profile_status.dart';
import 'package:fairytrail/explore/explore_warm_prefetch.dart';
import 'package:fairytrail/location/location_service.dart';
import 'package:fairytrail/push/push_service.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/explore_logical_day.dart';
import 'package:fairytrail/utils/image_warm.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/widgets.dart';

enum ExploreLoadState {
  idle,
  loading,
  ready,
  empty,
  error,
  needsLocation,
  dailyLimit,
  unapproved,
  profileRequired,
}

/// In-memory People deck + prefs (auto-saved).
/// Entitlement (gold/paid) comes from [AuthController], not prefetch meta.
class ExploreController extends ChangeNotifier with WidgetsBindingObserver {
  ExploreController() {
    WidgetsBinding.instance.addObserver(this);
  }

  final List<FullProfileDto> _profiles = [];
  final Set<int> _removedIds = {};
  int? _currentId;
  FullProfileDto? _lastSkippedProfile;
  int _connectsSinceMeta = 0;

  ExploreMetaDto? _meta;
  UserPrefsDto _prefs = const UserPrefsDto();
  List<CountryDto> _countries = [];
  List<LanguageDto> _languages = [];
  List<NationalityDto> _nationalities = [];

  ExploreLoadState _loadState = ExploreLoadState.idle;
  String? _error;
  String? _unapprovedReason;
  bool _prefsReady = false;

  /// One-shot retry when local deck is empty after a successful prefetch merge.
  bool _emptyDeckAutoPrefetchAttempted = false;
  bool _bootstrapping = false;
  Timer? _prefsSaveTimer;

  /// Fires at the next local 4 AM while [ExploreLoadState.dailyLimit] is shown.
  Timer? _dailyLimitResetTimer;

  /// Logical day key when daily limit was entered (for resume / timer checks).
  String? _dailyLimitDayKey;
  AuthController? _auth;
  String? _boundTier;
  String? _boundProfileStatus;

  ExploreLoadState get loadState => _loadState;
  String? get error => _error;
  String? get unapprovedReason => _unapprovedReason;
  bool get prefsReady => _prefsReady;
  ExploreMetaDto? get meta => _meta;
  int get effectiveTotalConnectsCount =>
      (_meta?.totalConnectsCount ?? _meta?.connectsCount ?? 0) +
      _connectsSinceMeta;

  /// RN: after pickup modal opens, server sets next checkpoint — keep local meta in sync
  /// so the modal does not reappear on every subsequent skip/connect.
  void applyPickupMoneyCountdown(int countdown) {
    final meta = _meta;
    if (meta == null) return;
    if (meta.pickupMoneyCountdown == countdown) return;
    _meta = meta.copyWith(pickupMoneyCountdown: countdown);
    notifyListeners();
  }

  void applyTravelMoneyPickedUp({int amountCents = 100}) {
    final meta = _meta;
    if (meta == null) return;
    final next = (meta.totalTravelMoney ?? 0) + amountCents;
    _meta = meta.copyWith(totalTravelMoney: next);
    notifyListeners();
  }

  UserPrefsDto get prefs => _prefs;
  List<CountryDto> get countries => _countries;
  List<LanguageDto> get languages => _languages;
  List<NationalityDto> get nationalities => _nationalities;
  bool get isPaid => _auth?.isPaid ?? false;
  bool get isGold => _auth?.isGold ?? false;
  FullProfileDto? get lastSkippedProfile => _lastSkippedProfile;
  bool get canUndo => _lastSkippedProfile != null;

  /// Bind global Auth so tier/gold updates rebuild Explore (like ThemeScope).
  void bindAuth(AuthController auth) {
    if (identical(_auth, auth)) return;
    _auth?.removeListener(_onAuthChanged);
    _auth = auth;
    _boundTier = auth.tier;
    _boundProfileStatus = auth.profileMeta?.status;
    _auth!.addListener(_onAuthChanged);
    notifyListeners();
  }

  void _onAuthChanged() {
    final nextTier = _auth?.tier;
    final tierChanged = nextTier != null && nextTier != _boundTier;
    _boundTier = nextTier;

    final nextStatus = _auth?.profileMeta?.status;
    final statusChanged =
        nextStatus != null && nextStatus != _boundProfileStatus;
    final wasUnapproved = _boundProfileStatus == ProfileStatus.unapproved;
    _boundProfileStatus = nextStatus;

    if (statusChanged &&
        wasUnapproved &&
        nextStatus == ProfileStatus.approved) {
      unawaited(bootstrap());
      return;
    }
    if (statusChanged && nextStatus == ProfileStatus.unapproved) {
      _profiles.clear();
      _currentId = null;
      _loadState = ExploreLoadState.unapproved;
      unawaited(LocalStorage.instance.clearLastExploreProfile());
      notifyListeners();
      return;
    }

    if (!isGold && _prefsReady) {
      final defaults = _withoutPremiumFilters(_prefs);
      if (!_prefsUnchanged(_prefs, defaults)) {
        _prefsSaveTimer?.cancel();
        _prefs = defaults;
        notifyListeners();
        unawaited(_persistPrefs(reloadDeck: true));
        return;
      }
    }

    // A tier refresh changes the server-side daily action limit. Reload the
    // deck so a stale dailyLimit response does not remain on screen after an
    // upgrade or verification completes while the app is backgrounded.
    if (tierChanged && _prefsReady) {
      resetProfiles();
      _loadState = ExploreLoadState.loading;
      notifyListeners();
      unawaited(loadProfiles(refreshNearMeLocation: false));
      return;
    }
    notifyListeners();
  }

  FullProfileDto? get current {
    final id = _currentId;
    if (id == null) return null;
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> bootstrap() async {
    if (_bootstrapping) return;
    _bootstrapping = true;

    try {
      final hydrated = await _hydrateFromCache();
      if (!hydrated) {
        _loadState = ExploreLoadState.loading;
        _error = null;
        notifyListeners();
      }

      await loadPrefs();
      // Prefer deck warmed after location (prefs → matches → prefetch).
      final warmed = await ExploreWarmPrefetch.instance.take();
      if (warmed != null) {
        await _applyPrefetchResponse(
          warmed.response,
          firstTime: warmed.firstTime,
        );
        return;
      }
      final isFirst = await _signupFirstTime();
      await loadProfiles(firstTime: isFirst);
      await _consumeSignupFirstTime(isFirst);
    } catch (e) {
      // Keep the cached card visible if the background prefetch fails.
      if (current == null) {
        _applyLoadError(e);
      } else {
        _loadState = ExploreLoadState.ready;
        notifyListeners();
      }
    } finally {
      _bootstrapping = false;
    }
  }

  /// Instant cold-start: show the last People card while prefetch runs.
  Future<bool> _hydrateFromCache() async {
    try {
      final json = await LocalStorage.instance.getLastExploreProfile();
      if (json == null) return false;
      final profile = FullProfileDto.fromJson(json);
      if (profile.id == 0) return false;
      _profiles
        ..clear()
        ..add(profile);
      _currentId = profile.id;
      _loadState = ExploreLoadState.ready;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ExploreController] last profile hydrate failed: $e');
      unawaited(LocalStorage.instance.clearLastExploreProfile());
      return false;
    }
  }

  void _persistCurrentProfile() {
    final profile = current;
    if (profile == null) {
      unawaited(LocalStorage.instance.clearLastExploreProfile());
      return;
    }
    unawaited(LocalStorage.instance.setLastExploreProfile(profile.toJson()));
  }

  /// Call after the user shares location successfully.
  Future<void> onLocationShared() async {
    resetProfiles();
    _loadState = ExploreLoadState.loading;
    notifyListeners();
    try {
      await loadProfiles();
    } catch (e) {
      _applyLoadError(e);
    }
  }

  /// Refreshes discovery after a paused account becomes active again.
  ///
  /// Explore stays mounted in Flutter's tab stack, unlike RN where the people
  /// screen remounts after unpausing. Clear the response fetched while paused
  /// so the active account receives a fresh deck.
  Future<void> refreshAfterUnpause() async {
    resetProfiles();
    _loadState = ExploreLoadState.loading;
    _error = null;
    notifyListeners();
    final isFirst = await _signupFirstTime();
    await loadProfiles(firstTime: isFirst);
    await _consumeSignupFirstTime(isFirst);
  }

  void dismissLocationPrompt() {
    _loadState = ExploreLoadState.empty;
    _error = 'Location helps us show people near you.';
    notifyListeners();
  }

  void requestLocationAgain() {
    _error = null;
    _loadState = ExploreLoadState.needsLocation;
    notifyListeners();
  }

  /// Loads prefs. Empty matchWith is seeded by [BeginJourneyScreen], not here.
  Future<void> loadPrefs() async {
    final res = await getPrefs();
    final noneId = UpcomingDestinations.noneOf(res.countries)?.id;
    _countries = UpcomingDestinations.realCountries(res.countries);
    _languages = res.languages;
    _nationalities = res.nationalitiesList;

    final loaded = _normalizePrefs(res.userPrefs, noneCountryId: noneId);
    _prefs = isGold ? loaded : _withoutPremiumFilters(loaded);

    // A downgrade must also clear the server copy before profiles are fetched,
    // otherwise a saved Gold filter (for example Near me) remains effective.
    if (!_prefsUnchanged(loaded, _prefs)) {
      await putPrefs(_prefs.copyWith(openTo: const []));
    }

    _prefsReady = true;
    notifyListeners();
  }

  /// Client defaults matching RN when the server has never saved search prefs.
  UserPrefsDto _normalizePrefs(UserPrefsDto p, {int? noneCountryId}) {
    var next = p;
    if (next.matchWith.isEmpty) {
      next = next.copyWith(matchWith: [for (final o in matchWithOptions) o.$2]);
    }
    if (next.ageFrom == null) next = next.copyWith(ageFrom: 18);
    if (next.ageTo == null) next = next.copyWith(ageTo: 99);
    // Never keep synthetic "None" in Traveling-to search prefs.
    if (noneCountryId != null &&
        next.upcomingCountries.contains(noneCountryId)) {
      next = next.copyWith(
        upcomingCountries: [
          for (final id in next.upcomingCountries)
            if (id != noneCountryId) id,
        ],
      );
    }
    // Leave empty mobility alone — RN default is [] (no mobility filter).
    return next;
  }

  void _clearPremiumIfNeeded() {
    if (isGold) return;
    _prefs = _withoutPremiumFilters(_prefs);
  }

  static UserPrefsDto _withoutPremiumFilters(UserPrefsDto prefs) {
    return prefs.copyWith(
      keyword: '',
      travelStyles: const [],
      clearRecentlyActiveWeeks: true,
      clearRadiusMiles: true,
    );
  }

  Future<void> loadProfiles({
    bool firstTime = false,
    bool refreshNearMeLocation = true,
    bool emptyDeckAutoRetry = false,
  }) async {
    // Each externally initiated load may auto-retry once if the local deck
    // stays empty; the retry itself must not reset that latch.
    if (!emptyDeckAutoRetry) {
      _emptyDeckAutoPrefetchAttempted = false;
    }

    try {
      // Near me: refresh GPS before fetching people; never reuse stale coords.
      if (refreshNearMeLocation) {
        if (!_prefsReady) await loadPrefs();
        if (_prefs.radiusMiles != null && _prefs.radiusMiles! > 0) {
          final outcome = await LocationService.shareCurrentLocation();
          if (!outcome.isSuccess) {
            _error = outcome.errorMessage;
            _loadState = ExploreLoadState.needsLocation;
            notifyListeners();
            return;
          }
        }
      }

      final noMatch = await _resolveNoMatch();
      final res = await prefetchProfiles(
        firstTime: firstTime,
        noMatch: noMatch,
      );

      await _applyPrefetchResponse(res, firstTime: firstTime);
    } on ApiException catch (e) {
      if (current != null) {
        _loadState = ExploreLoadState.ready;
        notifyListeners();
        return;
      }
      _applyLoadError(e);
    }
  }

  Future<void> _applyPrefetchResponse(
    PrefetchProfilesResponse res, {
    required bool firstTime,
  }) async {
    _meta = res.meta;
    _connectsSinceMeta = 0;
    _clearPremiumIfNeeded();
    // A successful prefetch means we are past (or never in) the daily-limit
    // screen — drop any pending 4 AM refresh timer.
    _cancelDailyLimitResetTimer();

    final keepId = _currentId;

    for (final profile in res.profiles) {
      if (_removedIds.contains(profile.id)) continue;
      if (_profiles.any((p) => p.id == profile.id)) continue;
      _profiles.add(profile);
    }

    // Prefer a fresher server copy of the hydrated card when present.
    if (keepId != null) {
      final serverIdx = res.profiles.indexWhere((p) => p.id == keepId);
      if (serverIdx >= 0) {
        final fresh = res.profiles[serverIdx];
        _profiles.removeWhere((p) => p.id == keepId);
        _profiles.insert(0, fresh);
        _currentId = keepId;
      } else if (!_profiles.any((p) => p.id == keepId)) {
        _currentId = _profiles.isEmpty ? null : _profiles.first.id;
      } else {
        // Keep hydrated card at front until the user acts on it.
        final idx = _profiles.indexWhere((p) => p.id == keepId);
        if (idx > 0) {
          final kept = _profiles.removeAt(idx);
          _profiles.insert(0, kept);
        }
        _currentId = keepId;
      }
    } else if (_profiles.isNotEmpty) {
      _currentId = _profiles.first.id;
    }

    // Empty = local deck, not whether this API batch had rows (filtered dupes /
    // removed ids can leave state empty even when the response was non-empty).
    if (_profiles.isEmpty || (_meta?.seenAll == true && current == null)) {
      if (!_emptyDeckAutoPrefetchAttempted) {
        _emptyDeckAutoPrefetchAttempted = true;
        _loadState = ExploreLoadState.loading;
        notifyListeners();
        await loadProfiles(
          firstTime: firstTime,
          refreshNearMeLocation: false,
          emptyDeckAutoRetry: true,
        );
        return;
      }
      _loadState = ExploreLoadState.empty;
      _persistCurrentProfile();
    } else {
      _emptyDeckAutoPrefetchAttempted = false;
      _loadState = ExploreLoadState.ready;
      _persistCurrentProfile();
    }
    notifyListeners();
    warmExploreProfilePhotos(_profiles);
  }

  /// Local `no_match` cache. If unset, fetch matches once to seed it.
  Future<bool> _resolveNoMatch() async {
    final cached = await LocalStorage.instance.getNoMatch();
    if (cached != null) return cached;

    try {
      final matches = await chat_api.fetchMatches(
        timestamp: EndPoints.matchesSyncEpoch,
      );
      final noMatch = matches.isEmpty;
      await LocalStorage.instance.setNoMatch(noMatch);
      return noMatch;
    } catch (e) {
      debugPrint('[ExploreController] no_match bootstrap failed: $e');
      // Optimistic "no matches yet" until proven otherwise.
      await LocalStorage.instance.setNoMatch(true);
      return true;
    }
  }

  /// Maps prefetch errors to RN `handleError` outcomes in people.tsx.
  void _applyLoadError(Object e) {
    final code = serverErrorCode(e);
    _error = null;
    _unapprovedReason = null;

    if (code == 'location_required') {
      _cancelDailyLimitResetTimer();
      _loadState = ExploreLoadState.needsLocation;
    } else if (code == 'daily_limit_reached') {
      _profiles.clear();
      _removedIds.clear();
      _currentId = null;
      _loadState = ExploreLoadState.dailyLimit;
      _dailyLimitDayKey = exploreLogicalDayKey();
      _persistCurrentProfile();
      _scheduleDailyLimitResetTimer();
      unawaited(PushService.instance.scheduleExploreAvailableNotification());
    } else if (code == 'profile_not_approved') {
      _cancelDailyLimitResetTimer();
      _profiles.clear();
      _currentId = null;
      _unapprovedReason = serverErrorReason(e);
      _loadState = ExploreLoadState.unapproved;
      _persistCurrentProfile();
    } else if (code == 'profile_required') {
      _cancelDailyLimitResetTimer();
      _loadState = ExploreLoadState.profileRequired;
    } else {
      _cancelDailyLimitResetTimer();
      _loadState = ExploreLoadState.error;
      _error = serverErrorText(e);
    }
    notifyListeners();
  }

  void resetProfiles() {
    _cancelDailyLimitResetTimer();
    _profiles.clear();
    _removedIds.clear();
    _currentId = null;
    _lastSkippedProfile = null;
    _meta = null;
    _connectsSinceMeta = 0;
    _error = null;
    _unapprovedReason = null;
    _emptyDeckAutoPrefetchAttempted = false;
    _loadState = ExploreLoadState.idle;
    unawaited(LocalStorage.instance.clearLastExploreProfile());
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRefreshAfterDailyLimitReset();
    }
  }

  /// Schedules a one-shot refresh for the next local 4 AM Explore day boundary.
  void _scheduleDailyLimitResetTimer() {
    _dailyLimitResetTimer?.cancel();
    if (_loadState != ExploreLoadState.dailyLimit) return;

    final delay = durationUntilNextExploreLogicalDay();
    if (delay <= Duration.zero) {
      unawaited(_refreshAfterDailyLimitReset());
      return;
    }
    _dailyLimitResetTimer = Timer(delay, () {
      if (_loadState != ExploreLoadState.dailyLimit) return;
      // Still the same logical day (clock skew / early fire) — reschedule.
      if (_dailyLimitDayKey == exploreLogicalDayKey()) {
        _scheduleDailyLimitResetTimer();
        return;
      }
      unawaited(_refreshAfterDailyLimitReset());
    });
  }

  void _cancelDailyLimitResetTimer() {
    _dailyLimitResetTimer?.cancel();
    _dailyLimitResetTimer = null;
    _dailyLimitDayKey = null;
  }

  /// Resume / timer safety: leave the stale daily-limit screen once the day rolls.
  void _maybeRefreshAfterDailyLimitReset() {
    if (_loadState != ExploreLoadState.dailyLimit) return;
    final hitDay = _dailyLimitDayKey;
    if (hitDay != null && hitDay == exploreLogicalDayKey()) {
      if (_dailyLimitResetTimer == null || !_dailyLimitResetTimer!.isActive) {
        _scheduleDailyLimitResetTimer();
      }
      return;
    }
    unawaited(_refreshAfterDailyLimitReset());
  }

  Future<void> _refreshAfterDailyLimitReset() async {
    if (_loadState != ExploreLoadState.dailyLimit) return;
    resetProfiles();
    _loadState = ExploreLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final isFirst = await _signupFirstTime();
      await loadProfiles(firstTime: isFirst);
      await _consumeSignupFirstTime(isFirst);
    } catch (e) {
      _applyLoadError(e);
    }
  }

  /// Peek: `firstime` is true only once after signup completes.
  Future<bool> _signupFirstTime() =>
      LocalStorage.instance.hasPendingSignupFirstExplore();

  Future<void> _consumeSignupFirstTime(bool used) async {
    if (used) {
      await LocalStorage.instance.clearPendingSignupFirstExplore();
    }
  }

  void _advance({bool expectRefill = false}) {
    final cur = current;
    if (cur != null) {
      _removedIds.add(cur.id);
      _profiles.removeWhere((p) => p.id == cur.id);
    }
    _currentId = _profiles.isEmpty ? null : _profiles.first.id;
    if (_currentId == null) {
      _loadState = expectRefill
          ? ExploreLoadState.loading
          : ExploreLoadState.empty;
    }
    _persistCurrentProfile();
    notifyListeners();
  }

  /// Remove current after block/report (no skip API — report already handled it).
  void dismissCurrent() => _advance();

  /// Optimistic connect: advances immediately, API runs in background.
  void connectOptimistic({
    void Function(ConnectProfileResponse result)? onDone,
    void Function(Object error)? onError,
  }) {
    final profile = current;
    if (profile == null) return;

    final id = profile.id;
    _lastSkippedProfile = null;
    _connectsSinceMeta++;
    _advance(expectRefill: true);
    // Prefetch only when the local deck is exhausted — not on every swipe.
    if (_profiles.isEmpty) {
      unawaited(loadProfiles(refreshNearMeLocation: false));
    }

    unawaited(() async {
      try {
        final result = await connectProfile(profileId: id);
        unawaited(
          AnalyticsService.instance.logEvent('connect_sent', {
            'receiver_user_id': id,
            'source': 'explore',
          }),
        );
        onDone?.call(result);
      } catch (e) {
        if (_connectsSinceMeta > 0) _connectsSinceMeta--;
        _removedIds.remove(id);
        _profiles.removeWhere((p) => p.id == id);
        _profiles.insert(0, profile);
        _currentId = id;
        _loadState = ExploreLoadState.ready;
        _persistCurrentProfile();
        notifyListeners();
        onError?.call(e);
      }
    }());
  }

  /// Sends a Connect without changing the visible deck.
  ///
  /// The caller advances only after the server accepts the request, so a
  /// verification or other rejection cannot briefly reveal the next profile.
  Future<ConnectProfileResponse> sendConnectForCurrent() async {
    final profile = current;
    if (profile == null) throw StateError('No profile to connect');

    final result = await connectProfile(profileId: profile.id);
    _connectsSinceMeta++;
    unawaited(
      AnalyticsService.instance.logEvent('connect_sent', {
        'receiver_user_id': profile.id,
        'source': 'explore',
      }),
    );
    return result;
  }

  void advanceAfterAcceptedConnect(int profileId) {
    if (current?.id != profileId) return;
    _lastSkippedProfile = null;
    _advance(expectRefill: true);
    if (_profiles.isEmpty) {
      unawaited(loadProfiles(refreshNearMeLocation: false));
    }
  }

  /// Sends a Skip without changing the visible deck.
  ///
  /// The caller advances only after the server accepts the request.
  Future<void> sendSkipForCurrent() async {
    final profile = current;
    if (profile == null) throw StateError('No profile to skip');

    await skipProfile(profileId: profile.id);
    unawaited(
      AnalyticsService.instance.logEvent('skip_sent', {
        'receiver_user_id': profile.id,
        'source': 'explore',
      }),
    );
  }

  void advanceAfterAcceptedSkip(int profileId) {
    final profile = current;
    if (profile == null || profile.id != profileId) return;
    _lastSkippedProfile = profile;
    _advance(expectRefill: true);
    if (_profiles.isEmpty) {
      unawaited(loadProfiles(refreshNearMeLocation: false));
    }
  }

  /// Optimistic skip: advances immediately, API runs in background.
  void skipOptimistic({void Function(Object error)? onError}) {
    final profile = current;
    if (profile == null) return;

    final id = profile.id;
    final skipped = profile;
    _advance(expectRefill: true);
    _lastSkippedProfile = skipped;
    notifyListeners();

    // Prefetch only when the local deck is exhausted — not on every swipe.
    if (_profiles.isEmpty) {
      unawaited(loadProfiles(refreshNearMeLocation: false));
    }

    unawaited(() async {
      try {
        await skipProfile(profileId: id);
        unawaited(
          AnalyticsService.instance.logEvent('skip_sent', {
            'receiver_user_id': id,
            'source': 'explore',
          }),
        );
      } catch (e) {
        onError?.call(e);
      }
    }());
  }

  /// Restore the last skipped profile to the front of the deck.
  void undoLastSkip({void Function(Object error)? onError}) {
    final skipped = _lastSkippedProfile;
    if (skipped == null) return;

    _lastSkippedProfile = null;
    _removedIds.remove(skipped.id);
    if (!_profiles.any((p) => p.id == skipped.id)) {
      _profiles.insert(0, skipped);
    } else {
      _profiles.removeWhere((p) => p.id == skipped.id);
      _profiles.insert(0, skipped);
    }
    _currentId = skipped.id;
    _loadState = ExploreLoadState.ready;
    _persistCurrentProfile();
    notifyListeners();

    unawaited(() async {
      try {
        await undoSkipProfile(profileId: skipped.id);
      } catch (e) {
        onError?.call(e);
      }
    }());
  }

  @Deprecated('Use connectOptimistic')
  Future<ConnectProfileResponse> connect() async {
    final profile = current;
    if (profile == null) throw StateError('No profile to connect');
    final id = profile.id;
    _lastSkippedProfile = null;
    _advance(expectRefill: true);
    final needsRefill = _profiles.isEmpty;
    try {
      final result = await connectProfile(profileId: id);
      if (needsRefill) {
        unawaited(loadProfiles(refreshNearMeLocation: false));
      }
      return result;
    } catch (e) {
      if (needsRefill) {
        unawaited(loadProfiles(refreshNearMeLocation: false));
      }
      rethrow;
    }
  }

  @Deprecated('Use skipOptimistic')
  Future<void> skip() async {
    final profile = current;
    if (profile == null) return;
    final id = profile.id;
    final skipped = profile;
    _advance(expectRefill: true);
    _lastSkippedProfile = skipped;
    notifyListeners();
    final needsRefill = _profiles.isEmpty;
    try {
      await skipProfile(profileId: id);
      if (needsRefill) {
        unawaited(loadProfiles(refreshNearMeLocation: false));
      }
    } catch (_) {
      if (needsRefill) {
        unawaited(loadProfiles(refreshNearMeLocation: false));
      }
      rethrow;
    }
  }

  /// True when [other] matches current prefs (order-insensitive for lists).
  bool prefsMatch(UserPrefsDto other) => _prefsUnchanged(_prefs, other);

  /// Updates prefs locally and auto-saves (debounced). Reloads deck after save.
  /// No-ops when [next] matches current prefs (order-insensitive for list fields).
  void updatePrefs(UserPrefsDto next, {bool reloadDeck = true}) {
    var sanitized = isGold ? next : _withoutPremiumFilters(next);
    // Radius clears country filters (mutual exclusion).
    if (sanitized.radiusMiles != null && sanitized.radiusMiles! > 0) {
      sanitized = sanitized.copyWith(
        currentCountries: const [],
        upcomingCountries: const [],
      );
    }
    if (_prefsUnchanged(_prefs, sanitized)) return;

    _prefs = sanitized;
    notifyListeners();

    _prefsSaveTimer?.cancel();
    _prefsSaveTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(_persistPrefs(reloadDeck: reloadDeck));
    });
  }

  static bool _prefsUnchanged(UserPrefsDto a, UserPrefsDto b) {
    return a.ageFrom == b.ageFrom &&
        a.ageTo == b.ageTo &&
        a.keyword == b.keyword &&
        a.radiusMiles == b.radiusMiles &&
        a.recentlyActiveWeeks == b.recentlyActiveWeeks &&
        _sameUnordered(a.matchWith, b.matchWith) &&
        _sameUnordered(a.currentCountries, b.currentCountries) &&
        _sameUnordered(a.upcomingCountries, b.upcomingCountries) &&
        _sameUnordered(a.mobility, b.mobility) &&
        _sameUnordered(a.openTo, b.openTo) &&
        _sameUnordered(a.nationalities, b.nationalities) &&
        _sameUnordered(a.speaking, b.speaking) &&
        _sameUnordered(a.travelStyles, b.travelStyles);
  }

  static bool _sameUnordered<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    if (a.isEmpty) return true;
    return Set<T>.from(a).containsAll(b);
  }

  Future<void> _persistPrefs({required bool reloadDeck}) async {
    try {
      await putPrefs(_prefs.copyWith(openTo: const []));
      if (reloadDeck) {
        resetProfiles();
        _loadState = ExploreLoadState.loading;
        notifyListeners();
        try {
          await loadProfiles();
        } catch (e) {
          _applyLoadError(e);
        }
      }
    } catch (e) {
      debugPrint('[ExploreController] prefs save failed: $e');
    }
  }

  void toggleMatchWith(String value) {
    final list = List<String>.from(_prefs.matchWith);
    if (list.contains(value)) {
      list.remove(value);
    } else {
      list.add(value);
    }
    updatePrefs(_prefs.copyWith(matchWith: list));
  }

  void toggleMobility(String value) {
    final list = List<String>.from(_prefs.mobility);
    if (list.contains(value)) {
      if (list.length <= 1) return; // keep at least one
      list.remove(value);
    } else {
      list.add(value);
    }
    updatePrefs(_prefs.copyWith(mobility: list));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.removeListener(_onAuthChanged);
    _prefsSaveTimer?.cancel();
    _cancelDailyLimitResetTimer();
    super.dispose();
  }
}
