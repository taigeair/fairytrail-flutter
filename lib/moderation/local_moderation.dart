import 'dart:convert';

import 'package:fairytrail/utils/storage/local_storage.dart';

/// Client-side block/report memory (RN has no server filter for these surfaces).
///
/// Profile report = block. Persists so group-chat hides and reported activities
/// stay gone after reopen without relying on backend feed filtering.
class LocalModeration {
  LocalModeration._();

  static final LocalModeration instance = LocalModeration._();

  Future<Set<int>> blockedProfileIds() =>
      _loadIds(StorageKeys.blockedProfileIds);

  Future<bool> isProfileBlocked(int profileId) async {
    if (profileId <= 0) return false;
    return (await blockedProfileIds()).contains(profileId);
  }

  Future<void> blockProfile(int profileId) async {
    if (profileId <= 0) return;
    final set = await blockedProfileIds();
    if (!set.add(profileId)) return;
    await _saveIds(StorageKeys.blockedProfileIds, set);
  }

  Future<Set<int>> reportedActivityIds() =>
      _loadIds(StorageKeys.reportedActivityIds);

  Future<bool> isActivityReported(int activityId) async {
    if (activityId <= 0) return false;
    return (await reportedActivityIds()).contains(activityId);
  }

  Future<void> reportActivity(int activityId) async {
    if (activityId <= 0) return;
    final set = await reportedActivityIds();
    if (!set.add(activityId)) return;
    await _saveIds(StorageKeys.reportedActivityIds, set);
  }

  Future<Set<int>> reportedMeetupIds() =>
      _loadIds(StorageKeys.reportedMeetupIds);

  Future<bool> isMeetupReported(int meetupId) async {
    if (meetupId <= 0) return false;
    return (await reportedMeetupIds()).contains(meetupId);
  }

  Future<void> reportMeetup(int meetupId) async {
    if (meetupId <= 0) return;
    final set = await reportedMeetupIds();
    if (!set.add(meetupId)) return;
    await _saveIds(StorageKeys.reportedMeetupIds, set);
  }

  Future<void> clear() async {
    await Future.wait([
      LocalStorage.instance.remove(StorageKeys.blockedProfileIds),
      LocalStorage.instance.remove(StorageKeys.reportedActivityIds),
      LocalStorage.instance.remove(StorageKeys.reportedMeetupIds),
    ]);
  }

  Future<Set<int>> _loadIds(String key) async {
    final raw = await LocalStorage.instance.getString(key);
    if (raw == null || raw.isEmpty) return <int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <int>{};
      return decoded.whereType<num>().map((n) => n.toInt()).toSet();
    } catch (_) {
      return <int>{};
    }
  }

  Future<void> _saveIds(String key, Set<int> ids) async {
    final sorted = ids.toList()..sort();
    await LocalStorage.instance.setString(key, jsonEncode(sorted));
  }
}
