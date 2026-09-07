import 'dart:async';

import 'package:fairytrail/api/chat.dart' as chat_api;
import 'package:fairytrail/api/meetups.dart' as meetup_api;
import 'package:fairytrail/api/models/chat_models.dart';
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/constants/profile_status.dart';
import 'package:fairytrail/moderation/local_moderation.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/utils/uuid.dart';
import 'package:fairytrail/ws/app_websocket.dart';
import 'package:flutter/material.dart';

enum MessagesLoadState { idle, loading, ready, error }

/// Inbox + open thread + WebSocket realtime for Messages.
class MessagesController extends ChangeNotifier {
  MessagesController();

  final List<MatchDto> _matches = [];
  final List<ActivityChatDto> _activityChats = [];
  final List<MeetupChatDto> _meetupChats = [];
  final Map<int, List<ChatMessageDto>> _matchMessages = {};
  final Map<int, List<ActivityChatMessageDto>> _activityMessages = {};
  final Map<int, String?> _activityCursors = {};
  final Map<int, bool> _activityHasMore = {};

  /// Local composer drafts keyed like ChatComposer (`match_12`, `activity_34`).
  final Map<String, String> _drafts = {};

  MessagesLoadState _loadState = MessagesLoadState.idle;
  String? _error;
  int _unreadCount = 0;
  bool _inboxLoading = false;

  MatchDto? _currentMatch;
  ActivityChatDto? _currentActivity;
  bool _threadLoading = false;
  String? _threadError;

  AppWebSocket? _ws;
  String? _currentUserId;
  String? _viewerProfileStatus;
  VoidCallback? _onNewMessageToast;
  VoidCallback? _onNewMatchToast;
  void Function(int postcardId)? _onNewPostcard;
  void Function(String oldStatus, String newStatus)? _onProfileStatusUpdate;
  Timer? _inboxPollTimer;

  /// Inbox HTTP + polling stay off until the Messages tab is opened.
  bool _inboxStarted = false;

  /// Completes after MainShell syncs meetup visibility from remote config.
  /// Activity + meetup chat fetches wait on this so they don't race init.
  Completer<void>? _remoteConfigReady;

  /// Re-run [loadInbox] after an in-flight load if meetup visibility flipped on.
  bool _pendingGroupChatsRefresh = false;

  /// Paid feature: filter 1:1 matches by partner country (null = show all).
  int? _matchCountryFilterId;
  String? _matchCountryFilterName;

  /// When false (meetups disabled for the user's country), meetup chats stay
  /// out of the inbox even if the API still returns them.
  /// Defaults false until [setMeetupChatsVisible] syncs with remote config.
  bool _meetupChatsVisible = false;

  static const _inboxPollInterval = Duration(minutes: 2);

  MessagesLoadState get loadState => _loadState;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  bool get inboxLoading => _inboxLoading;
  List<MatchDto> get matches => List.unmodifiable(_matches);
  List<ActivityChatDto> get activityChats => List.unmodifiable(_activityChats);

  ActivityChatDto? activityChatFor(int activityId) {
    for (final chat in _activityChats) {
      if (chat.activity.id == activityId) return chat;
    }
    return null;
  }

  MatchDto? get currentMatch => _currentMatch;
  ActivityChatDto? get currentActivity => _currentActivity;
  bool get threadLoading => _threadLoading;
  String? get threadError => _threadError;
  bool get isMatchOpen => _currentMatch != null;
  bool get isActivityOpen => _currentActivity != null;
  int? get matchCountryFilterId => _matchCountryFilterId;
  String? get matchCountryFilterName => _matchCountryFilterName;
  bool get hasMatchCountryFilter => _matchCountryFilterId != null;
  bool get meetupChatsVisible => _meetupChatsVisible;

  Iterable<MatchDto> get _visibleMatches {
    if (_matchCountryFilterId == null) return _matches;
    return _matches.where(
      (m) => m.profile.country?.id == _matchCountryFilterId,
    );
  }

  Iterable<MeetupChatDto> get _visibleMeetupChats {
    if (!_meetupChatsVisible) return const [];
    return _meetupChats;
  }

  void setMatchCountryFilter(int? countryId, {String? countryName}) {
    _matchCountryFilterId = countryId;
    _matchCountryFilterName = countryName;
    notifyListeners();
  }

  void clearMatchCountryFilter() {
    if (_matchCountryFilterId == null) return;
    _matchCountryFilterId = null;
    _matchCountryFilterName = null;
    notifyListeners();
  }

  /// Sync with remote config / Meetups tab visibility for this session.
  void setMeetupChatsVisible(bool visible) {
    if (_meetupChatsVisible == visible) return;
    final becameVisible = visible && !_meetupChatsVisible;
    _meetupChatsVisible = visible;
    if (!visible) {
      // Hide in memory only — keep disk cache for when meetups turn back on.
      _meetupChats.clear();
    }
    _unreadCount = _countUnreadFromMatches() + _countUnreadFromMeetups();
    // Safe if called during build (MainShell captures visibility in build).
    scheduleMicrotask(() {
      notifyListeners();
      if (becameVisible && _inboxStarted) {
        _pendingGroupChatsRefresh = true;
        unawaited(() async {
          await _hydrateInboxFromStorage();
          await loadInbox(silent: true);
        }());
      }
    });
  }

  /// Call after remote config is loaded and [setMeetupChatsVisible] is applied.
  void markRemoteConfigReady() {
    final gate = _remoteConfigReady ??= Completer<void>();
    if (!gate.isCompleted) gate.complete();
  }

  Future<void> _waitForRemoteConfigReady() async {
    final gate = _remoteConfigReady ??= Completer<void>();
    if (gate.isCompleted) return;
    try {
      await gate.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      // Proceed with current meetup visibility (usually still false).
    }
  }

  List<ChatMessageDto> get openMatchMessages {
    final m = _currentMatch;
    if (m == null) return const [];
    return List.unmodifiable(_matchMessages[m.id] ?? const []);
  }

  List<ActivityChatMessageDto> get openActivityMessages {
    final a = _currentActivity;
    if (a == null) return const [];
    return List.unmodifiable(_activityMessages[a.id] ?? const []);
  }

  bool get activityHasMore {
    final a = _currentActivity;
    if (a == null) return false;
    return _activityHasMore[a.id] ?? false;
  }

  List<InboxItem> get inboxItems {
    final items = <InboxItem>[
      for (final m in _visibleMatches) InboxItem.match(m),
      for (final a in _activityChats) InboxItem.activity(a),
      for (final u in _visibleMeetupChats) InboxItem.meetup(u),
    ];
    items.sort((a, b) => b.sortAt.compareTo(a.sortAt));
    return items;
  }

  List<MeetupChatDto> get meetupChats => List.unmodifiable(_meetupChats);

  /// Non-empty draft for [draftKey], or null.
  String? draftFor(String draftKey) {
    final draft = _drafts[draftKey]?.trim();
    if (draft == null || draft.isEmpty) return null;
    return draft;
  }

  static String matchDraftKey(int matchId) => 'match_$matchId';

  static String activityDraftKey(int activityId) => 'activity_$activityId';

  /// Reloads local drafts for the current inbox (call after leaving a chat).
  Future<void> reloadDrafts({bool notify = true}) async {
    final storage = LocalStorage.instance;
    final next = <String, String>{};
    for (final m in _matches) {
      final key = matchDraftKey(m.id);
      final draft = await storage.getDraftMessage(key);
      final trimmed = draft?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        next[key] = trimmed;
      }
    }
    for (final a in _activityChats) {
      final key = activityDraftKey(a.activity.id);
      final draft = await storage.getDraftMessage(key);
      final trimmed = draft?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        next[key] = trimmed;
      }
    }
    _drafts
      ..clear()
      ..addAll(next);
    if (notify) notifyListeners();
  }

  void setToastCallbacks({
    VoidCallback? onNewMessage,
    VoidCallback? onNewMatch,
  }) {
    _onNewMessageToast = onNewMessage;
    _onNewMatchToast = onNewMatch;
  }

  /// RN AppContext `new_postcard` → careReceived blocker.
  void setPostcardCallback({void Function(int postcardId)? onNewPostcard}) {
    _onNewPostcard = onNewPostcard;
  }

  /// RN AppContext `profile_status_update`.
  void setProfileStatusCallback({
    void Function(String oldStatus, String newStatus)? onProfileStatusUpdate,
  }) {
    _onProfileStatusUpdate = onProfileStatusUpdate;
  }

  /// Connects WebSocket only. Inbox APIs run on [ensureInboxStarted].
  Future<void> bootstrap({
    required String? userId,
    required String? token,
    String? profileStatus,
  }) async {
    _currentUserId = userId;
    _viewerProfileStatus = profileStatus;
    if (token == null || token.isEmpty) return;
    _connectWs(token);
  }

  /// First Messages-tab open: hydrate cache, then full sync + start polling.
  /// Later visits to the tab: incremental [loadInbox] only.
  ///
  /// Activity + meetup chat APIs run only after [markRemoteConfigReady].
  Future<void> ensureInboxStarted({bool force = false}) async {
    await _waitForRemoteConfigReady();
    if (!_inboxStarted) {
      _inboxStarted = true;
      // Hydrate match / activity / meetup previews from disk — show cache instantly.
      await _hydrateInboxFromStorage();
      final hasData =
          _matches.isNotEmpty ||
          _activityChats.isNotEmpty ||
          _meetupChats.isNotEmpty;
      // Fresh app open: full epoch sync so partner countries are current.
      await loadInbox(silent: hasData && !force, fullMatchesSync: true);
      _startInboxPoll();
      return;
    }
    // Returning to Messages (e.g. after other tabs / background) — delta only.
    await loadInbox(silent: true);
  }

  void updateAuth({
    required String? userId,
    required String? token,
    String? profileStatus,
  }) {
    _currentUserId = userId;
    if (profileStatus != null) {
      _viewerProfileStatus = profileStatus;
    }
    if (token == null || token.isEmpty) {
      _stopInboxPoll();
      _inboxStarted = false;
      _viewerProfileStatus = null;
      _matches.clear();
      _activityChats.clear();
      _meetupChats.clear();
      _matchMessages.clear();
      _activityMessages.clear();
      _unreadCount = 0;
      _ws?.disconnect();
      _ws = null;
      return;
    }
    if (_ws == null) {
      _connectWs(token);
    }
    // Don't start inbox poll until the Messages tab has been opened.
    if (_inboxStarted) {
      _startInboxPoll();
    }
  }

  void _connectWs(String token) {
    _ws?.disconnect();
    final ws = AppWebSocket(token);
    _ws = ws;
    ws.on('new_message', _onWsNewMessage);
    ws.on('new_match', _onWsNewMatch);
    ws.on('new_postcard', _onWsNewPostcard);
    ws.on('profile_status_update', _onWsProfileStatusUpdate);
    ws.connect();
  }

  void _startInboxPoll() {
    if (_inboxPollTimer != null) return;
    _inboxPollTimer = Timer.periodic(_inboxPollInterval, (_) {
      unawaited(loadInbox(silent: true));
    });
  }

  void _stopInboxPoll() {
    _inboxPollTimer?.cancel();
    _inboxPollTimer = null;
  }

  Completer<void>? _inboxLoadCompleter;

  /// When true, the next [loadInbox] (or a follow-up after an in-flight load)
  /// fetches matches from epoch and replaces the list (fresh countries).
  bool _pendingFullMatchesSync = false;

  Future<void> loadInbox({
    bool silent = false,
    bool fullMatchesSync = false,
  }) async {
    // Activity + meetup chats depend on meetup_enabled from /init.
    await _waitForRemoteConfigReady();

    if (fullMatchesSync) _pendingFullMatchesSync = true;

    // Coalesce concurrent callers so deep-link / Send message waits for the
    // in-flight fetch instead of returning with a stale empty inbox.
    final inFlight = _inboxLoadCompleter;
    if (inFlight != null) {
      await inFlight.future;
      if (!_pendingFullMatchesSync && !_pendingGroupChatsRefresh) return;
      // A delta poll may have finished — run again for full / group-chat refresh.
      if (_inboxLoadCompleter != null) {
        await _inboxLoadCompleter!.future;
        if (!_pendingFullMatchesSync && !_pendingGroupChatsRefresh) return;
      }
    }

    final doFullMatchesSync = _pendingFullMatchesSync;
    _pendingFullMatchesSync = false;
    _pendingGroupChatsRefresh = false;

    _inboxLoading = true;
    final completer = Completer<void>();
    _inboxLoadCompleter = completer;
    if (!silent) {
      _loadState = MessagesLoadState.loading;
      _error = null;
      notifyListeners();
    }

    try {
      final storage = LocalStorage.instance;
      // Hydrate disk cache first, then sync (delta or full).
      if (_matches.isEmpty ||
          _activityChats.isEmpty ||
          (_meetupChatsVisible && _meetupChats.isEmpty)) {
        await _hydrateInboxFromStorage();
      }
      final timestamp = doFullMatchesSync || _matches.isEmpty
          ? EndPoints.matchesSyncEpoch
          : await storage.getLastMatchesSyncTimestamp();
      // Matches can sync anytime; activity + meetup chats only after remote config.
      final results = await Future.wait([
        chat_api.fetchMatches(timestamp: timestamp),
        chat_api.fetchActivityChats(),
        () async {
          if (!_meetupChatsVisible) return <MeetupChatDto>[];
          try {
            return await meetup_api.fetchMeetupChats();
          } catch (_) {
            return <MeetupChatDto>[];
          }
        }(),
        LocalModeration.instance.reportedMeetupIds(),
      ]);
      final delta = results[0] as List<MatchDto>;
      final reportedMeetups = results[3] as Set<int>;
      // Full sync replaces the list (RN fullSync) so countries refresh.
      _mergeMatchesDelta(delta, replace: doFullMatchesSync);
      _activityChats
        ..clear()
        ..addAll(results[1] as List<ActivityChatDto>);
      if (_meetupChatsVisible) {
        _meetupChats
          ..clear()
          ..addAll(
            (results[2] as List<MeetupChatDto>).where(
              (c) => !reportedMeetups.contains(c.meetup.id),
            ),
          );
      } else {
        _meetupChats.clear();
      }
      await _persistInboxLists();
      // Include meetup unread in the nav badge (plan default).
      _unreadCount = _countUnreadFromMatches() + _countUnreadFromMeetups();
      final nextTs = DateTime.now().toUtc().subtract(
        const Duration(minutes: 10),
      );
      await storage.setLastMatchesSyncTimestamp(nextTs.toIso8601String());
      _loadState = MessagesLoadState.ready;
      _error = null;
    } catch (e) {
      _error = serverErrorText(e);
      if (_matches.isEmpty && _activityChats.isEmpty) {
        _loadState = MessagesLoadState.error;
      }
    } finally {
      await reloadDrafts(notify: false);
      _inboxLoading = false;
      _inboxLoadCompleter = null;
      completer.complete();
      notifyListeners();
    }
  }

  /// Restore conversation previews from disk (matches + activity + meetup).
  Future<void> _hydrateInboxFromStorage() async {
    final storage = LocalStorage.instance;
    var changed = false;

    if (_matches.isEmpty) {
      final stored = await storage.getMatchList();
      if (stored.isNotEmpty) {
        _matches
          ..clear()
          ..addAll(stored);
        changed = true;
      }
    }

    if (_activityChats.isEmpty) {
      final stored = await storage.getActivityChatList();
      if (stored.isNotEmpty) {
        _activityChats
          ..clear()
          ..addAll(stored);
        changed = true;
      }
    }

    if (_meetupChatsVisible && _meetupChats.isEmpty) {
      final stored = await storage.getMeetupChatList();
      if (stored.isNotEmpty) {
        _meetupChats
          ..clear()
          ..addAll(stored);
        changed = true;
      }
    }

    if (!changed) return;
    _unreadCount = _countUnreadFromMatches() + _countUnreadFromMeetups();
    if (_loadState == MessagesLoadState.idle) {
      _loadState = MessagesLoadState.ready;
    }
    notifyListeners();
  }

  /// Persist inbox previews after sync / local lastMessage updates.
  Future<void> _persistInboxLists() async {
    final storage = LocalStorage.instance;
    await Future.wait([
      storage.setMatchList(_matches),
      storage.setActivityChatList(_activityChats),
      // Don't wipe meetup cache when meetups are hidden for this country.
      if (_meetupChatsVisible) storage.setMeetupChatList(_meetupChats),
    ]);
  }

  /// RN matchesHook merge: upsert by id, drop `canBeDeleted`.
  ///
  /// Exception (v1 parity): fraud viewers keep fraud matches. The v2 API marks
  /// all fraud peers as `canBeDeleted` (no viewer check), so without this,
  /// fraud↔fraud 1:1 chats disappear from the inbox.
  void _mergeMatchesDelta(List<MatchDto> delta, {bool replace = false}) {
    final keepDeleted = _viewerProfileStatus == ProfileStatus.fraud;
    // First sync / explicit full sync replaces the list; later polls merge.
    final isFullish = replace || _matches.isEmpty;
    if (isFullish) {
      _matches
        ..clear()
        ..addAll(
          keepDeleted
              ? delta.map(
                  (m) => m.canBeDeleted ? m.copyWith(canBeDeleted: false) : m,
                )
              : delta.where((m) => !m.canBeDeleted),
        );
      return;
    }
    for (final incoming in delta) {
      if (incoming.canBeDeleted && !keepDeleted) {
        _matches.removeWhere((m) => m.id == incoming.id);
        continue;
      }
      final idx = _matches.indexWhere((m) => m.id == incoming.id);
      if (idx >= 0) {
        _matches[idx] = incoming.copyWith(
          // Keep local thread when API says deletable but viewer is fraud.
          canBeDeleted: keepDeleted ? false : incoming.canBeDeleted,
        );
      } else {
        _matches.add(
          keepDeleted && incoming.canBeDeleted
              ? incoming.copyWith(canBeDeleted: false)
              : incoming,
        );
      }
    }
    if (!keepDeleted) {
      _matches.removeWhere((m) => m.canBeDeleted);
    }
  }

  /// RN AppContext unread: count matches whose last message is from the other
  /// user and not seen by me.
  int _countUnreadFromMatches() {
    return _matches
        .where(
          (m) =>
              m.lastMessage != null &&
              !m.lastMessage!.seenByMe &&
              (_currentUserId == null ||
                  m.lastMessage!.userId != _currentUserId),
        )
        .length;
  }

  int _countUnreadFromMeetups() {
    if (!_meetupChatsVisible) return 0;
    return _meetupChats
        .where(
          (c) =>
              c.lastMessage != null &&
              !c.lastMessage!.seenByMe &&
              (_currentUserId == null ||
                  c.lastMessage!.userId != _currentUserId),
        )
        .length;
  }

  Future<void> refreshUnread() async {
    _unreadCount = _countUnreadFromMatches() + _countUnreadFromMeetups();
    notifyListeners();
  }

  // ── Open / close threads ──────────────────────────────────────────

  Future<void> openMatch(MatchDto match) async {
    _currentMatch = match;
    _currentActivity = null;
    _threadError = null;

    // Show something immediately: cache, last preview, or empty thread.
    // Fetch continues in the background; UI shows a thin header loader.
    final cached = _matchMessages[match.id];
    if (cached != null && cached.isNotEmpty) {
      // keep cache
    } else if (match.lastMessage != null) {
      _matchMessages[match.id] = [match.lastMessage!];
    } else {
      _matchMessages[match.id] ??= const [];
    }
    _threadLoading = true;
    notifyListeners();

    try {
      final messages = await chat_api.fetchMatchMessages(
        profileId: match.profile.id,
      );
      if (_currentMatch?.profile.id != match.profile.id) return;

      // Oldest → newest for chat list (reverse of API if needed).
      final sorted = [...messages]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Upgrade provisional match (id 0) once we know the real matchId.
      var resolved = _currentMatch ?? match;
      final realId = sorted.isNotEmpty ? sorted.first.matchId : 0;
      if (resolved.id == 0 && realId != 0) {
        resolved = resolved.copyWith(id: realId);
        final pending = _matchMessages.remove(0);
        _currentMatch = resolved;
        if (pending != null && pending.isNotEmpty) {
          _matchMessages[realId] = [
            ...pending,
            for (final m in sorted)
              if (!pending.any((p) => p.id == m.id)) m,
          ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        } else {
          _matchMessages[realId] = sorted;
        }
      } else {
        _matchMessages[resolved.id] = sorted;
      }
      _threadLoading = false;
      notifyListeners();

      // Seen / unread are not needed to show the thread.
      unawaited(_afterMatchOpened(resolved));
    } catch (e) {
      if (_currentMatch?.profile.id != match.profile.id) return;
      _threadError = serverErrorText(e);
      _threadLoading = false;
      notifyListeners();
    }
  }

  Future<void> openActivity(ActivityChatDto chat) async {
    _currentActivity = chat;
    _currentMatch = null;
    _threadError = null;

    // Show something immediately: cache, last preview, or empty thread.
    // Fetch continues in the background; UI shows a thin header loader.
    final cached = _activityMessages[chat.id];
    if (cached != null && cached.isNotEmpty) {
      // keep cache
    } else if (chat.lastMessage != null) {
      _activityMessages[chat.id] = [chat.lastMessage!];
    } else {
      _activityMessages[chat.id] ??= const [];
    }
    _threadLoading = true;
    notifyListeners();

    try {
      final page = await chat_api.fetchActivityMessages(
        activityId: chat.activity.id,
      );
      if (_currentActivity?.id != chat.id) return;

      // API returns newest-first typically; normalize oldest → newest.
      final sorted = [...page.messages]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _activityMessages[chat.id] = sorted;
      _activityCursors[chat.id] = page.nextCursor;
      _activityHasMore[chat.id] = page.hasMore;
      _threadLoading = false;
      notifyListeners();

      // Seen / unread are not needed to show the thread.
      unawaited(_afterActivityOpened(chat));
    } catch (e) {
      if (_currentActivity?.id != chat.id) return;
      _threadError = serverErrorText(e);
      _threadLoading = false;
      notifyListeners();
    }
  }

  Future<void> _afterMatchOpened(MatchDto match) async {
    try {
      await chat_api.markMatchSeen(profileId: match.profile.id);
      if (_currentMatch?.id != match.id) return;
      _markMatchSeenLocal(match.id);
      await refreshUnread();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _afterActivityOpened(ActivityChatDto chat) async {
    try {
      await chat_api.markActivitySeen(activityId: chat.activity.id);
      if (_currentActivity?.id != chat.id) return;
      _markActivitySeenLocal(chat.id);
      await refreshUnread();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadMoreActivityMessages() async {
    final chat = _currentActivity;
    if (chat == null) return;
    if (_threadLoading) return;
    if (!(_activityHasMore[chat.id] ?? false)) return;

    _threadLoading = true;
    notifyListeners();
    try {
      final page = await chat_api.fetchActivityMessages(
        activityId: chat.activity.id,
        cursor: _activityCursors[chat.id],
      );
      final existing = _activityMessages[chat.id] ?? [];
      final merged = [...page.messages, ...existing];
      merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      // Dedupe by id
      final seen = <String>{};
      _activityMessages[chat.id] = [
        for (final m in merged)
          if (seen.add(m.id)) m,
      ];
      _activityCursors[chat.id] = page.nextCursor;
      _activityHasMore[chat.id] = page.hasMore;
    } catch (e) {
      _threadError = serverErrorText(e);
    } finally {
      _threadLoading = false;
      notifyListeners();
    }
  }

  void closeThread() {
    _currentMatch = null;
    _currentActivity = null;
    _threadError = null;
    _threadLoading = false;
    notifyListeners();
    unawaited(reloadDrafts());
  }

  // ── Send ──────────────────────────────────────────────────────────

  Future<void> sendMatchMessage(String text) async {
    final match = _currentMatch;
    final userId = _currentUserId;
    if (match == null || userId == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final id = uuidV4();
    final optimistic = ChatMessageDto(
      id: id,
      matchId: match.id,
      userId: userId,
      message: trimmed,
      createdAt: DateTime.now(),
      seenByMe: true,
      seenByOther: false,
      pending: true,
    );
    _upsertMatchMessage(optimistic);
    _bumpMatchLastMessage(optimistic);
    notifyListeners();

    try {
      final saved = await chat_api.sendMatchMessage(
        profileId: match.profile.id,
        id: id,
        message: trimmed,
      );
      _upsertMatchMessage(saved.copyWith(pending: false, failed: false));
      _bumpMatchLastMessage(saved);
    } catch (e) {
      // Response can fail after the server already saved (or WS confirmed).
      if (!_isMatchMessageConfirmed(match.id, id) &&
          !await _confirmMatchMessageOnServer(match.profile.id, id)) {
        _upsertMatchMessage(optimistic.copyWith(pending: false, failed: true));
        _threadError = serverErrorText(e);
      }
    }
    notifyListeners();
  }

  Future<void> sendActivityMessage(String text) async {
    final chat = _currentActivity;
    final userId = _currentUserId;
    if (chat == null || userId == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final id = uuidV4();
    final optimistic = ActivityChatMessageDto(
      id: id,
      activityChatId: chat.id,
      userId: userId,
      message: trimmed,
      createdAt: DateTime.now(),
      seenByMe: true,
      pending: true,
    );
    _upsertActivityMessage(optimistic);
    _bumpActivityLastMessage(optimistic);
    notifyListeners();

    try {
      final saved = await chat_api.sendActivityMessage(
        activityId: chat.activity.id,
        id: id,
        message: trimmed,
      );
      _upsertActivityMessage(saved.copyWith(pending: false, failed: false));
      _bumpActivityLastMessage(saved);
    } catch (e) {
      // Response can fail after the server already saved (or WS confirmed).
      if (!_isActivityMessageConfirmed(chat.id, id) &&
          !await _confirmActivityMessageOnServer(chat.activity.id, id)) {
        _upsertActivityMessage(
          optimistic.copyWith(pending: false, failed: true),
        );
        _threadError = serverErrorText(e);
      }
    }
    notifyListeners();
  }

  // ── Unmatch / leave / join ────────────────────────────────────────

  Future<void> unmatch(int profileId) async {
    await chat_api.unmatchProfile(profileId: profileId);
    _matches.removeWhere((m) => m.profile.id == profileId);
    if (_currentMatch?.profile.id == profileId) {
      closeThread();
    }
    await _persistInboxLists();
    notifyListeners();
  }

  Future<void> leaveActivity(int activityId) async {
    await chat_api.leaveActivityChat(activityId: activityId);
    _activityChats.removeWhere((c) => c.activity.id == activityId);
    if (_currentActivity?.activity.id == activityId) {
      closeThread();
    }
    await _persistInboxLists();
    notifyListeners();
  }

  Future<void> leaveMeetupChat(int meetupId) async {
    try {
      await meetup_api.leaveMeetup(meetupId);
    } catch (_) {
      // Creator can't leave — still hide locally after report.
    }
    removeMeetupChat(meetupId);
  }

  void removeMeetupChat(int meetupId) {
    _meetupChats.removeWhere((c) => c.meetup.id == meetupId);
    _unreadCount = _countUnreadFromMatches() + _countUnreadFromMeetups();
    unawaited(_persistInboxLists());
    notifyListeners();
  }

  /// Join (or reuse) an activity chat. Does not load messages — open the
  /// chat screen first, then call [openActivity].
  Future<ActivityChatDto> joinActivity(int activityId) async {
    for (final c in _activityChats) {
      if (c.activity.id == activityId) return c;
    }
    final chat = await chat_api.joinActivityChat(activityId: activityId);
    final idx = _activityChats.indexWhere((c) => c.id == chat.id);
    if (idx >= 0) {
      _activityChats[idx] = chat;
    } else {
      _activityChats.insert(0, chat);
    }
    await _persistInboxLists();
    notifyListeners();
    return chat;
  }

  MatchDto? findMatchByProfileId(int profileId) {
    for (final m in _matches) {
      if (m.profile.id == profileId) return m;
    }
    return null;
  }

  /// Resolve a match by the other user's profile id, refreshing inbox if needed.
  /// Retries once after a short delay for the race right after a new match.
  Future<MatchDto?> ensureMatchByProfileId(int profileId) async {
    var match = findMatchByProfileId(profileId);
    if (match != null) return match;

    await loadInbox(silent: true);
    match = findMatchByProfileId(profileId);
    if (match != null) return match;

    await Future<void>.delayed(const Duration(milliseconds: 500));
    await loadInbox(silent: true);
    return findMatchByProfileId(profileId);
  }

  /// After opening chat with a provisional match, refresh inbox and swap in
  /// the real [MatchDto] without blocking the UI.
  Future<void> syncMatchAfterOpen(int profileId) async {
    await loadInbox(silent: true);
    final real = findMatchByProfileId(profileId);
    if (real == null) return;
    if (_currentMatch?.profile.id != profileId) return;
    final oldId = _currentMatch!.id;
    if (oldId != real.id) {
      final pending = _matchMessages.remove(oldId);
      if (pending != null && pending.isNotEmpty) {
        final existing = _matchMessages[real.id] ?? const <ChatMessageDto>[];
        final seen = <String>{for (final m in existing) m.id};
        _matchMessages[real.id] = [
          ...existing,
          for (final m in pending)
            if (seen.add(m.id)) m,
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
    }
    _currentMatch = real;
    notifyListeners();
  }

  // ── WebSocket handlers ────────────────────────────────────────────

  void _onWsNewMessage(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);

    if (map.containsKey('matchId') && map.containsKey('seenByOther')) {
      final msg = ChatMessageDto.fromJson(map);
      final isOpen = _currentMatch?.id == msg.matchId;
      final forMe = msg.userId != _currentUserId;
      final local = msg.copyWith(seenByMe: isOpen || !forMe);
      _upsertMatchMessage(local);
      _bumpMatchLastMessage(local);
      if (isOpen && forMe) {
        final match = _currentMatch;
        if (match != null) {
          chat_api.markMatchSeen(profileId: match.profile.id).then((_) {
            refreshUnread();
          });
        }
      } else if (forMe) {
        _unreadCount += 1;
        _onNewMessageToast?.call();
      }
      notifyListeners();
      return;
    }

    if (map.containsKey('activityChatId')) {
      final msg = ActivityChatMessageDto.fromJson(map);
      final isOpen = _currentActivity?.id == msg.activityChatId;
      final forMe = msg.userId != _currentUserId;
      final local = msg.copyWith(seenByMe: isOpen || !forMe);
      _upsertActivityMessage(local);
      _bumpActivityLastMessage(local);
      if (isOpen && forMe) {
        final chat = _currentActivity;
        if (chat != null) {
          chat_api.markActivitySeen(activityId: chat.activity.id).then((_) {
            refreshUnread();
          });
        }
      } else if (forMe) {
        _unreadCount += 1;
        _onNewMessageToast?.call();
      }
      notifyListeners();
    }
  }

  void _onWsNewMatch(dynamic _) {
    unawaited(LocalStorage.instance.markHasMatch());
    loadInbox(silent: true);
    _onNewMatchToast?.call();
  }

  void _onWsNewPostcard(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final raw = map['postcardId'] ?? map['id'];
    final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (id == null || id <= 0) return;
    _onNewPostcard?.call(id);
  }

  void _onWsProfileStatusUpdate(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final oldStatus = map['oldStatus']?.toString() ?? '';
    final newStatus = map['newStatus']?.toString() ?? '';
    if (newStatus.isEmpty) return;
    final wasFraud = _viewerProfileStatus == ProfileStatus.fraud;
    _viewerProfileStatus = newStatus;
    _onProfileStatusUpdate?.call(oldStatus, newStatus);
    // Fraud viewers need a full re-sync — previously dropped fraud matches return.
    if (!wasFraud && newStatus == ProfileStatus.fraud && _inboxStarted) {
      unawaited(_fullResyncMatchesForFraudViewer());
    }
  }

  Future<void> _fullResyncMatchesForFraudViewer() async {
    _matches.clear();
    await LocalStorage.instance.clearMatchList();
    await LocalStorage.instance.clearLastMatchesSyncTimestamp();
    await loadInbox(silent: true, fullMatchesSync: true);
  }

  // ── Local helpers ─────────────────────────────────────────────────

  bool _isMatchMessageConfirmed(int matchId, String id) {
    final list = _matchMessages[matchId];
    if (list == null) return false;
    for (final m in list) {
      if (m.id == id) return !m.pending;
    }
    return false;
  }

  bool _isActivityMessageConfirmed(int activityChatId, String id) {
    final list = _activityMessages[activityChatId];
    if (list == null) return false;
    for (final m in list) {
      if (m.id == id) return !m.pending;
    }
    return false;
  }

  Future<bool> _confirmMatchMessageOnServer(int profileId, String id) async {
    try {
      final messages = await chat_api.fetchMatchMessages(profileId: profileId);
      for (final m in messages) {
        if (m.id == id) {
          _upsertMatchMessage(m.copyWith(pending: false, failed: false));
          _bumpMatchLastMessage(m);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _confirmActivityMessageOnServer(
    int activityId,
    String id,
  ) async {
    try {
      final page = await chat_api.fetchActivityMessages(activityId: activityId);
      for (final m in page.messages) {
        if (m.id == id) {
          _upsertActivityMessage(m.copyWith(pending: false, failed: false));
          _bumpActivityLastMessage(m);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  void _upsertMatchMessage(ChatMessageDto msg) {
    final list = List<ChatMessageDto>.from(_matchMessages[msg.matchId] ?? []);
    final idx = list.indexWhere((m) => m.id == msg.id);
    if (idx >= 0) {
      final prev = list[idx];
      // Don't let a late "failed" overwrite a confirmed (WS/HTTP) message.
      if (!prev.pending && msg.failed) return;
      list[idx] = msg;
    } else {
      list.add(msg);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    _matchMessages[msg.matchId] = list;
  }

  void _upsertActivityMessage(ActivityChatMessageDto msg) {
    final list = List<ActivityChatMessageDto>.from(
      _activityMessages[msg.activityChatId] ?? [],
    );
    final idx = list.indexWhere((m) => m.id == msg.id);
    if (idx >= 0) {
      final prev = list[idx];
      // Don't let a late "failed" overwrite a confirmed (WS/HTTP) message.
      if (!prev.pending && msg.failed) return;
      list[idx] = msg;
    } else {
      list.add(msg);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    _activityMessages[msg.activityChatId] = list;
  }

  void _bumpMatchLastMessage(ChatMessageDto msg) {
    final idx = _matches.indexWhere((m) => m.id == msg.matchId);
    if (idx < 0) {
      // Unknown match — refresh inbox.
      loadInbox(silent: true);
      return;
    }
    _matches[idx] = _matches[idx].copyWith(lastMessage: msg);
    unawaited(_persistInboxLists());
  }

  void _bumpActivityLastMessage(ActivityChatMessageDto msg) {
    final idx = _activityChats.indexWhere((c) => c.id == msg.activityChatId);
    if (idx < 0) {
      loadInbox(silent: true);
      return;
    }
    _activityChats[idx] = _activityChats[idx].copyWith(lastMessage: msg);
    unawaited(_persistInboxLists());
  }

  void _markMatchSeenLocal(int matchId) {
    final msgs = _matchMessages[matchId];
    if (msgs != null) {
      _matchMessages[matchId] = [
        for (final m in msgs) m.copyWith(seenByMe: true),
      ];
    }
    final idx = _matches.indexWhere((m) => m.id == matchId);
    if (idx >= 0) {
      final last = _matches[idx].lastMessage;
      if (last != null) {
        _matches[idx] = _matches[idx].copyWith(
          lastMessage: last.copyWith(seenByMe: true),
        );
        unawaited(_persistInboxLists());
      }
    }
  }

  void _markActivitySeenLocal(int activityChatId) {
    final msgs = _activityMessages[activityChatId];
    if (msgs != null) {
      _activityMessages[activityChatId] = [
        for (final m in msgs) m.copyWith(seenByMe: true),
      ];
    }
    final idx = _activityChats.indexWhere((c) => c.id == activityChatId);
    if (idx >= 0) {
      final last = _activityChats[idx].lastMessage;
      if (last != null) {
        _activityChats[idx] = _activityChats[idx].copyWith(
          lastMessage: last.copyWith(seenByMe: true),
        );
        unawaited(_persistInboxLists());
      }
    }
  }

  @override
  void dispose() {
    _stopInboxPoll();
    _ws?.disconnect();
    super.dispose();
  }
}

class MessagesScope extends InheritedNotifier<MessagesController> {
  const MessagesScope({
    super.key,
    required MessagesController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Set by [MainShell] so pushed routes above this scope can still Message.
  static MessagesController? active;

  static MessagesController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MessagesScope>();
    assert(scope != null || active != null, 'MessagesScope not found');
    return scope?.notifier ?? active!;
  }

  static MessagesController? maybeOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<MessagesScope>()
            ?.notifier ??
        active;
  }
}
