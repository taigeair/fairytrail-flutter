import 'dart:convert';

import 'package:fairytrail/api/models/chat_models.dart';
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/utils/explore_logical_day.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys used by [LocalStorage].
abstract final class StorageKeys {
  static const apiToken = 'apiToken';
  static const email = 'email';
  static const user = 'user';
  static const profileMeta = 'profileMeta';
  static const profileStrength = 'profileStrength';
  static const registrationData = 'registrationData';
  static const photoUploadCommittedUserId = 'photoUploadCommittedUserId';
  static const location = 'location';
  static const lastLocationUpdateAt = 'lastLocationUpdateAt';
  static const signupStep = 'signupStep';
  static const hasSeenFakeConnectIntro = 'hasSeenFakeConnectIntro';
  static const hasSeenPostcardIntro = 'hasSeenPostcardIntro';
  static const trailBookVisitedCountryIds = 'trailBookVisitedCountryIds';
  static const alreadyConnected = 'alreadyConnected';

  /// One-shot: next Explore prefetch should send `firstime=true` after signup.
  static const pendingSignupFirstExplore = 'pendingSignupFirstExplore';
  static const noMatch = 'noMatch';

  /// Last visible Explore People profile — shown instantly on cold start.
  static const lastExploreProfile = 'lastExploreProfile';
  static const pushToken = 'pushToken';

  /// Per-user: `is_notification_prompted_<userId>` — soft prompt shown once.
  static const isNotificationPromptedPrefix = 'is_notification_prompted_';

  /// @deprecated Prefer per-user [isNotificationPromptedPrefix].
  static const hasPromptedNotifications = 'hasPromptedNotifications';

  /// RN `EXPLORE_AVAILABLE_NOTIFICATION_ID` — set once a limit-reset notif is scheduled.
  static const exploreAvailableNotificationId =
      'EXPLORE_AVAILABLE_NOTIFICATION_ID';

  /// RN `LOCAL_PUSH_NOTIFICATION_ID` — inactive-user reminder schedule marker.
  static const localPushNotificationId = 'LOCAL_PUSH_NOTIFICATION_ID';
  static const hasRequestedSignupNotificationPermission =
      'hasRequestedSignupNotificationPermission';
  static const hasRequestedLocationPermission =
      'hasRequestedLocationPermission';
  static const revealCount = 'revealCount';
  static const isImpersonating = 'isImpersonating';
  static const userAliasId = 'userAliasId';
  static const reviewRequested = 'reviewRequested';
  static const reviewLeft = 'reviewLeft';
  static const draftMessagePrefix = 'draft_message_';

  /// Per-activity group chat info notice dismissed:
  /// `activity_chat_info_notice_dismissed_<activityId>`.
  static const activityChatInfoNoticeDismissedPrefix =
      'activity_chat_info_notice_dismissed_';
  static const lastMatchesSyncTimestamp = 'lastMatchesSyncTimestamp';

  /// RN `${apiKey}_match_list` — cached 1:1 match inbox previews.
  static const matchList = 'matchList';

  /// Cached activity group chat inbox previews.
  static const activityChatList = 'activityChatList';

  /// Cached meetup group chat inbox previews.
  static const meetupChatList = 'meetupChatList';

  static const checkpointForAdsScreen = 'checkpointForAdsScreen';
  static const firstConnectAdGraceThroughAction =
      'firstConnectAdGraceThroughAction';
  static const bannerAdsScreenViewed = 'bannerAdsScreenViewed';
  static const skipAdsCountdownFinished = 'skipAdsCountdownFinished';
  static const rewardStatus = 'reward_status';

  /// When true, Explore never shows the free trail-money pickup modal.
  static const disablePickupTrailMoney = 'disablePickupTrailMoney';

  /// Last [show_admin_popup_version] seen per user:
  /// `lastSeenAdminPopupVersion_<userId>`.
  static const lastSeenAdminPopupVersionPrefix = 'lastSeenAdminPopupVersion_';

  /// Client-side engagement trigger for admin popups. Cleared on logout/delete.
  static const hasInitiatedConnectForAdminPopup =
      'hasInitiatedConnectForAdminPopup';

  /// @deprecated Global key — migrated to [lastSeenAdminPopupVersionPrefix].
  static const lastSeenAdminPopupVersion = 'lastSeenAdminPopupVersion';

  /// Profile IDs the user blocked/reported (client hide for group chat / lists).
  static const blockedProfileIds = 'blockedProfileIds';

  /// Activity IDs the user reported (client hide from Explore Activities feed).
  static const reportedActivityIds = 'reportedActivityIds';

  /// Meetup IDs the user reported (client hide from inbox / map).
  static const reportedMeetupIds = 'reportedMeetupIds';
}

/// Thin wrapper around [SharedPreferences] for app persistence.
class LocalStorage {
  LocalStorage._();

  static final LocalStorage instance = LocalStorage._();

  SharedPreferences? _prefs;
  bool _hadInitiatedConnectAtSessionStart = false;

  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    _hadInitiatedConnectAtSessionStart =
        _store.getBool(StorageKeys.hasInitiatedConnectForAdminPopup) ?? false;
  }

  SharedPreferences get _store {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('LocalStorage.init() must be called before use');
    }
    return prefs;
  }

  // ── Generic ──────────────────────────────────────────────

  Future<String?> getString(String key) async => _store.getString(key);

  Future<void> setString(String key, String value) async {
    await _store.setString(key, value);
  }

  Future<void> remove(String key) async {
    await _store.remove(key);
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = await getString(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await setString(key, jsonEncode(value));
  }

  // ── Auth helpers ─────────────────────────────────────────

  Future<String?> getApiToken() => getString(StorageKeys.apiToken);

  Future<void> setApiToken(String token) =>
      setString(StorageKeys.apiToken, token);

  Future<void> deleteApiToken() => remove(StorageKeys.apiToken);

  Future<String?> getEmail() => getString(StorageKeys.email);

  Future<void> setEmail(String email) => setString(StorageKeys.email, email);

  Future<void> deleteEmail() => remove(StorageKeys.email);

  Future<Map<String, dynamic>?> getUser() => getJson(StorageKeys.user);

  Future<void> setUser(Map<String, dynamic> user) =>
      setJson(StorageKeys.user, user);

  Future<void> deleteUser() => remove(StorageKeys.user);

  Future<Map<String, dynamic>?> getProfileMeta() =>
      getJson(StorageKeys.profileMeta);

  Future<void> setProfileMeta(Map<String, dynamic> meta) =>
      setJson(StorageKeys.profileMeta, meta);

  Future<void> deleteProfileMeta() => remove(StorageKeys.profileMeta);

  Future<int?> getProfileStrength() async =>
      _store.getInt(StorageKeys.profileStrength);

  Future<void> setProfileStrength(int value) async {
    await _store.setInt(StorageKeys.profileStrength, value.clamp(0, 100));
  }

  Future<void> deleteProfileStrength() => remove(StorageKeys.profileStrength);

  Future<Map<String, dynamic>?> getRegistrationData() =>
      getJson(StorageKeys.registrationData);

  Future<void> setRegistrationData(Map<String, dynamic> data) =>
      setJson(StorageKeys.registrationData, data);

  Future<void> deleteRegistrationData() => remove(StorageKeys.registrationData);

  Future<String?> getPhotoUploadCommittedUserId() =>
      getString(StorageKeys.photoUploadCommittedUserId);

  Future<void> setPhotoUploadCommittedUserId(String userId) =>
      setString(StorageKeys.photoUploadCommittedUserId, userId);

  Future<void> deletePhotoUploadCommitted() =>
      remove(StorageKeys.photoUploadCommittedUserId);

  Future<Map<String, dynamic>?> getLocation() => getJson(StorageKeys.location);

  /// Writes the latest GPS fix used as the fast local default.
  /// Preserves any existing last-posted baseline unless [markAsPosted] is true.
  Future<void> setLocation({
    required double latitude,
    required double longitude,
    bool markAsPosted = false,
  }) async {
    final existing = await getLocation();
    final lastPostedLat = markAsPosted
        ? latitude
        : (existing?['lastPostedLatitude'] as num?)?.toDouble();
    final lastPostedLng = markAsPosted
        ? longitude
        : (existing?['lastPostedLongitude'] as num?)?.toDouble();

    await setJson(StorageKeys.location, {
      'latitude': latitude,
      'longitude': longitude,
      if (lastPostedLat != null) 'lastPostedLatitude': lastPostedLat,
      if (lastPostedLng != null) 'lastPostedLongitude': lastPostedLng,
    });
  }

  /// Updates only the last-posted server baseline. Does not change stored
  /// `latitude` / `longitude`.
  Future<void> setLastPostedLocation({
    required double latitude,
    required double longitude,
  }) async {
    final existing = await getLocation();
    final storedLat = (existing?['latitude'] as num?)?.toDouble();
    final storedLng = (existing?['longitude'] as num?)?.toDouble();
    await setJson(StorageKeys.location, {
      if (storedLat != null) 'latitude': storedLat,
      if (storedLng != null) 'longitude': storedLng,
      'lastPostedLatitude': latitude,
      'lastPostedLongitude': longitude,
    });
  }

  Future<void> deleteLocation() => remove(StorageKeys.location);

  Future<DateTime?> getLastLocationUpdateAt() async {
    final value = _store.getInt(StorageKeys.lastLocationUpdateAt);
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<void> setLastLocationUpdateAt(DateTime at) async {
    await _store.setInt(
      StorageKeys.lastLocationUpdateAt,
      at.millisecondsSinceEpoch,
    );
  }

  Future<void> deleteLastLocationUpdateAt() =>
      remove(StorageKeys.lastLocationUpdateAt);

  Future<int?> getSignupStep() async {
    final value = _store.getInt(StorageKeys.signupStep);
    return value;
  }

  Future<void> setSignupStep(int step) async {
    await _store.setInt(StorageKeys.signupStep, step);
  }

  Future<void> deleteSignupStep() => remove(StorageKeys.signupStep);

  /// First-run Explore "Tap Connect" intro (RN `hasSeenFakeConnectIntro`).
  Future<bool> getHasSeenFakeConnectIntro() async {
    final value = await getString(StorageKeys.hasSeenFakeConnectIntro);
    return value == '1';
  }

  Future<void> setHasSeenFakeConnectIntro() =>
      setString(StorageKeys.hasSeenFakeConnectIntro, '1');

  Future<void> clearHasSeenFakeConnectIntro() =>
      remove(StorageKeys.hasSeenFakeConnectIntro);

  /// RN `alreadyConnected` — false until the user makes their first Connect.
  Future<bool> isFirstConnect() async {
    final value = await getString(StorageKeys.alreadyConnected);
    return value != '1';
  }

  Future<void> setAlreadyConnected() =>
      setString(StorageKeys.alreadyConnected, '1');

  Future<void> clearAlreadyConnected() => remove(StorageKeys.alreadyConnected);

  /// Marks that the next Explore prefetch should use `firstime=true`.
  Future<void> markPendingSignupFirstExplore() =>
      setString(StorageKeys.pendingSignupFirstExplore, '1');

  Future<bool> hasPendingSignupFirstExplore() async {
    final value = await getString(StorageKeys.pendingSignupFirstExplore);
    return value == '1';
  }

  Future<void> clearPendingSignupFirstExplore() =>
      remove(StorageKeys.pendingSignupFirstExplore);

  /// Cached Explore `no_match` flag. `null` means never resolved — bootstrap
  /// should check the matches list once, then persist true/false.
  Future<bool?> getNoMatch() async {
    final value = await getString(StorageKeys.noMatch);
    if (value == null) return null;
    return value == '1';
  }

  Future<void> setNoMatch(bool value) =>
      setString(StorageKeys.noMatch, value ? '1' : '0');

  /// Call when the user gets a mutual match from any surface.
  Future<void> markHasMatch() => setNoMatch(false);

  Future<void> clearNoMatch() => remove(StorageKeys.noMatch);

  /// Last People card shown on Explore — used for instant cold-start hydrate.
  Future<Map<String, dynamic>?> getLastExploreProfile() =>
      getJson(StorageKeys.lastExploreProfile);

  Future<void> setLastExploreProfile(Map<String, dynamic> profile) =>
      setJson(StorageKeys.lastExploreProfile, profile);

  Future<void> clearLastExploreProfile() =>
      remove(StorageKeys.lastExploreProfile);

  Future<bool> getHasSeenPostcardIntro() async {
    final value = await getString(StorageKeys.hasSeenPostcardIntro);
    return value == '1';
  }

  Future<void> setHasSeenPostcardIntro() =>
      setString(StorageKeys.hasSeenPostcardIntro, '1');

  Future<Set<int>> getTrailBookVisitedCountryIds() async {
    final raw = await getString(StorageKeys.trailBookVisitedCountryIds);
    if (raw == null || raw.isEmpty) return <int>{};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <int>{};
    return decoded.whereType<num>().map((value) => value.toInt()).toSet();
  }

  Future<void> setTrailBookVisitedCountryIds(Set<int> ids) async {
    final sorted = ids.toList()..sort();
    await setString(StorageKeys.trailBookVisitedCountryIds, jsonEncode(sorted));
  }

  Future<String?> getPushToken() => getString(StorageKeys.pushToken);

  Future<void> setPushToken(String token) =>
      setString(StorageKeys.pushToken, token);

  Future<void> deletePushToken() => remove(StorageKeys.pushToken);

  Future<String?> getCurrentUserId() async {
    final user = await getUser();
    final userId = user?['id']?.toString();
    if (userId != null && userId.isNotEmpty) return userId;
    final meta = await getProfileMeta();
    final metaId = meta?['id']?.toString();
    if (metaId != null && metaId.isNotEmpty && metaId != '0') return metaId;
    return null;
  }

  Future<bool> isNotificationPrompted(String userId) async {
    if (userId.isEmpty) return false;
    return (await getString(
          '${StorageKeys.isNotificationPromptedPrefix}$userId',
        )) ==
        '1';
  }

  Future<void> setNotificationPrompted(String userId) async {
    if (userId.isEmpty) return;
    await setString('${StorageKeys.isNotificationPromptedPrefix}$userId', '1');
  }

  /// Clears soft-prompt flag for [userId] (and legacy global key).
  Future<void> clearNotificationPrompted([String? userId]) async {
    final id = userId ?? await getCurrentUserId();
    if (id != null && id.isNotEmpty) {
      await remove('${StorageKeys.isNotificationPromptedPrefix}$id');
    }
    await remove(StorageKeys.hasPromptedNotifications);
  }

  @Deprecated('Use isNotificationPrompted(userId)')
  Future<bool> getHasPromptedNotifications() async =>
      (await getString(StorageKeys.hasPromptedNotifications)) == '1';

  @Deprecated('Use setNotificationPrompted(userId)')
  Future<void> setHasPromptedNotifications() =>
      setString(StorageKeys.hasPromptedNotifications, '1');

  @Deprecated('Use clearNotificationPrompted')
  Future<void> clearHasPromptedNotifications() => clearNotificationPrompted();

  Future<bool> hasExploreAvailableNotification() async =>
      (await getString(StorageKeys.exploreAvailableNotificationId)) != null;

  Future<void> setExploreAvailableNotification(String id) =>
      setString(StorageKeys.exploreAvailableNotificationId, id);

  Future<void> clearExploreAvailableNotification() =>
      remove(StorageKeys.exploreAvailableNotificationId);

  Future<bool> hasLocalPushNotification() async =>
      (await getString(StorageKeys.localPushNotificationId)) != null;

  Future<void> setLocalPushNotification(String id) =>
      setString(StorageKeys.localPushNotificationId, id);

  Future<void> clearLocalPushNotification() =>
      remove(StorageKeys.localPushNotificationId);

  Future<bool> getHasRequestedSignupNotificationPermission() async =>
      (await getString(StorageKeys.hasRequestedSignupNotificationPermission)) ==
      '1';

  Future<void> setHasRequestedSignupNotificationPermission() =>
      setString(StorageKeys.hasRequestedSignupNotificationPermission, '1');

  Future<bool> getHasRequestedLocationPermission() async =>
      (await getString(StorageKeys.hasRequestedLocationPermission)) == '1';

  Future<void> setHasRequestedLocationPermission() =>
      setString(StorageKeys.hasRequestedLocationPermission, '1');

  /// Free-tier "Reveal" tap count (RN `storageService.revealCount`).
  Future<int> getRevealCount() async {
    final value = _store.getInt(StorageKeys.revealCount);
    return value ?? 0;
  }

  Future<int> incrementRevealCount() async {
    final next = (await getRevealCount()) + 1;
    await _store.setInt(StorageKeys.revealCount, next);
    return next;
  }

  /// Admin impersonation session (RN `storageService.startImpersonation`).
  Future<void> startImpersonation() =>
      setString(StorageKeys.isImpersonating, '1');

  Future<void> endImpersonation() => remove(StorageKeys.isImpersonating);

  Future<bool> isImpersonating() async {
    final value = await getString(StorageKeys.isImpersonating);
    return value == '1';
  }

  /// Anonymous Mixpanel distinct id (RN `userAliasId`).
  Future<String?> getUserAliasId() => getString(StorageKeys.userAliasId);

  Future<void> setUserAliasId(String id) =>
      setString(StorageKeys.userAliasId, id);

  Future<void> deleteUserAliasId() => remove(StorageKeys.userAliasId);

  /// RN `storageService` review prompt counters.
  Future<int> getReviewRequestedTimes() async {
    final value = await getString(StorageKeys.reviewRequested);
    if (value == null || value.isEmpty) return 0;
    return int.tryParse(value) ?? 0;
  }

  Future<void> setReviewRequested(int times) =>
      setString(StorageKeys.reviewRequested, times.toString());

  Future<void> setReviewLeft() => setString(StorageKeys.reviewLeft, '1');

  Future<bool> isReviewLeft() async {
    final value = await getString(StorageKeys.reviewLeft);
    return value == '1';
  }

  /// RN `last_matches_sync_timestamp` — watermark for `/api/v2/matches`.
  Future<String> getLastMatchesSyncTimestamp() async {
    final value = await getString(StorageKeys.lastMatchesSyncTimestamp);
    if (value == null || value.isEmpty) {
      return '2018-01-01T00:00:00';
    }
    return value;
  }

  Future<void> setLastMatchesSyncTimestamp(String timestamp) =>
      setString(StorageKeys.lastMatchesSyncTimestamp, timestamp);

  Future<void> clearLastMatchesSyncTimestamp() =>
      remove(StorageKeys.lastMatchesSyncTimestamp);

  /// RN `match_list` — persisted 1:1 match inbox (conversation previews).
  Future<List<MatchDto>> getMatchList() async {
    final raw = await getString(StorageKeys.matchList);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => MatchDto.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.id > 0 && !m.canBeDeleted)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setMatchList(List<MatchDto> matches) async {
    final payload = [
      for (final m in matches)
        if (!m.canBeDeleted && m.id > 0) m.toJson(),
    ];
    await setString(StorageKeys.matchList, jsonEncode(payload));
  }

  Future<void> clearMatchList() => remove(StorageKeys.matchList);

  Future<List<ActivityChatDto>> getActivityChatList() async {
    final raw = await getString(StorageKeys.activityChatList);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => ActivityChatDto.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.id > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setActivityChatList(List<ActivityChatDto> chats) async {
    final payload = [
      for (final c in chats)
        if (c.id > 0) c.toJson(),
    ];
    await setString(StorageKeys.activityChatList, jsonEncode(payload));
  }

  Future<void> clearActivityChatList() => remove(StorageKeys.activityChatList);

  Future<List<MeetupChatDto>> getMeetupChatList() async {
    final raw = await getString(StorageKeys.meetupChatList);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => MeetupChatDto.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.id > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setMeetupChatList(List<MeetupChatDto> chats) async {
    final payload = [
      for (final c in chats)
        if (c.id > 0) c.toJson(),
    ];
    await setString(StorageKeys.meetupChatList, jsonEncode(payload));
  }

  Future<void> clearMeetupChatList() => remove(StorageKeys.meetupChatList);

  /// RN `draft_message_${matchId}` — per-conversation composer drafts.
  String _draftMessageKey(String draftId) =>
      '${StorageKeys.draftMessagePrefix}$draftId';

  Future<String?> getDraftMessage(String draftId) =>
      getString(_draftMessageKey(draftId));

  Future<void> setDraftMessage(String draftId, String message) async {
    final key = _draftMessageKey(draftId);
    if (message.isEmpty) {
      await remove(key);
      return;
    }
    await setString(key, message);
  }

  Future<void> deleteDraftMessage(String draftId) =>
      remove(_draftMessageKey(draftId));

  String _activityChatInfoNoticeDismissedKey(int activityId) =>
      '${StorageKeys.activityChatInfoNoticeDismissedPrefix}$activityId';

  Future<bool> isActivityChatInfoNoticeDismissed(int activityId) async =>
      _store.getBool(_activityChatInfoNoticeDismissedKey(activityId)) ?? false;

  Future<void> setActivityChatInfoNoticeDismissed(int activityId) async {
    await _store.setBool(_activityChatInfoNoticeDismissedKey(activityId), true);
  }

  Future<void> clearAllDraftMessages() async {
    final keys = _store
        .getKeys()
        .where((k) => k.startsWith(StorageKeys.draftMessagePrefix))
        .toList();
    for (final key in keys) {
      await _store.remove(key);
    }
  }

  // ── Ads (keys and semantics match the React Native app) ───

  Future<int?> getCheckpointForAdsScreen() async {
    final value = _store.get(StorageKeys.checkpointForAdsScreen);
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> setCheckpointForAdsScreen(int checkpoint) =>
      _store.setInt(StorageKeys.checkpointForAdsScreen, checkpoint);

  Future<int?> getFirstConnectAdGraceThroughAction() async =>
      _store.getInt(StorageKeys.firstConnectAdGraceThroughAction);

  Future<void> setFirstConnectAdGraceThroughAction(int action) =>
      _store.setInt(StorageKeys.firstConnectAdGraceThroughAction, action);

  Future<void> deleteFirstConnectAdGraceThroughAction() =>
      remove(StorageKeys.firstConnectAdGraceThroughAction);

  Future<int?> getBannerAdsScreenViewed() async {
    final value = _store.get(StorageKeys.bannerAdsScreenViewed);
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> setBannerAdsScreenViewed(int placement) =>
      _store.setInt(StorageKeys.bannerAdsScreenViewed, placement);

  Future<void> deleteBannerAdsScreenViewed() =>
      remove(StorageKeys.bannerAdsScreenViewed);

  Future<bool> getSkipAdsCountdownFinished() async =>
      (await getString(StorageKeys.skipAdsCountdownFinished)) == '1';

  Future<void> setSkipAdsCountdownFinished() =>
      setString(StorageKeys.skipAdsCountdownFinished, '1');

  Future<void> deleteSkipAdsCountdownFinished() =>
      remove(StorageKeys.skipAdsCountdownFinished);

  Future<void> setRewardTaken() => setJson(StorageKeys.rewardStatus, {
    'date': exploreLogicalDayKey(),
    'reward_taken': true,
  });

  Future<bool> hasRewardBeenTakenToday() async {
    final value = await getJson(StorageKeys.rewardStatus);
    if (value == null || value['reward_taken'] != true) return false;
    return value['date'] == exploreLogicalDayKey();
  }

  Future<bool> isPickupTrailMoneyDisabled() async =>
      _store.getBool(StorageKeys.disablePickupTrailMoney) ?? false;

  Future<void> setPickupTrailMoneyDisabled(bool disabled) =>
      _store.setBool(StorageKeys.disablePickupTrailMoney, disabled);

  Future<int> getLastSeenAdminPopupVersion(String userId) async {
    if (userId.isEmpty) return 0;
    return _store.getInt(
          '${StorageKeys.lastSeenAdminPopupVersionPrefix}$userId',
        ) ??
        0;
  }

  Future<void> setLastSeenAdminPopupVersion(String userId, int version) async {
    if (userId.isEmpty) return;
    await _store.setInt(
      '${StorageKeys.lastSeenAdminPopupVersionPrefix}$userId',
      version,
    );
    // Drop legacy device-wide key if present.
    await remove(StorageKeys.lastSeenAdminPopupVersion);
  }

  bool get hadInitiatedConnectAtSessionStart =>
      _hadInitiatedConnectAtSessionStart;

  Future<void> setHasInitiatedConnectForAdminPopup() =>
      _store.setBool(StorageKeys.hasInitiatedConnectForAdminPopup, true);

  Future<void> clearAdsState() async {
    await Future.wait([
      remove(StorageKeys.checkpointForAdsScreen),
      remove(StorageKeys.firstConnectAdGraceThroughAction),
      remove(StorageKeys.bannerAdsScreenViewed),
      remove(StorageKeys.skipAdsCountdownFinished),
      remove(StorageKeys.rewardStatus),
    ]);
  }

  /// Clears auth-related keys after logout (keeps email for login prefill).
  Future<void> clearAuth() async {
    // Capture before user keys are deleted.
    final userId = await getCurrentUserId();
    await clearNotificationPrompted(userId);
    await remove(StorageKeys.hasInitiatedConnectForAdminPopup);
    _hadInitiatedConnectAtSessionStart = false;
    await deleteApiToken();
    await deleteUser();
    await deleteProfileMeta();
    await deleteProfileStrength();
    await deleteRegistrationData();
    await deletePhotoUploadCommitted();
    await deleteLocation();
    await deleteLastLocationUpdateAt();
    await deleteSignupStep();
    await deletePushToken();
    await endImpersonation();
    await clearAllDraftMessages();
    await clearLastMatchesSyncTimestamp();
    await clearMatchList();
    await clearActivityChatList();
    await clearMeetupChatList();
    await clearAdsState();
    await remove(StorageKeys.blockedProfileIds);
    await remove(StorageKeys.reportedActivityIds);
    await remove(StorageKeys.reportedMeetupIds);
    await remove(StorageKeys.disablePickupTrailMoney);
    // Show connect intro again on next login.
    await clearHasSeenFakeConnectIntro();
    await clearAlreadyConnected();
    await clearPendingSignupFirstExplore();
    await clearNoMatch();
    await clearLastExploreProfile();
  }
}
