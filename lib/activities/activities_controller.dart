import 'package:fairytrail/api/activities.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/activities/activities_warm_prefetch.dart';
import 'package:fairytrail/bucket_list/bucket_list_controller.dart';
import 'package:fairytrail/moderation/local_moderation.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:flutter/foundation.dart';

enum ActivitiesSortBy { trending, newest }

/// Explore → Activities feed (paginated, bookmarkable).
class ActivitiesController extends ChangeNotifier {
  ActivitiesController({this.currentUserAvatarUrl});

  /// Thumbnail used when optimistically prepending the saver avatar.
  String? currentUserAvatarUrl;

  final List<ActivityDto> _activities = [];
  ActivitiesSortBy _sortBy = ActivitiesSortBy.trending;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int? _lastExplorerCount;
  int? _lastId;
  String? _error;
  bool _fetchInProgress = false;

  List<ActivityDto> get activities => List.unmodifiable(_activities);
  ActivitiesSortBy get sortBy => _sortBy;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get isEmpty => !_loading && _activities.isEmpty;

  Future<void> bootstrap() async {
    if (_activities.isNotEmpty) return;

    final warmed = await ActivitiesWarmPrefetch.instance.take();
    if (warmed != null) {
      await _applyPage(warmed, reset: true);
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    _lastExplorerCount = null;
    _lastId = null;
    _hasMore = true;
    await _fetch(reset: true);
  }

  Future<void> setSortBy(ActivitiesSortBy value) async {
    if (value == _sortBy) return;
    _sortBy = value;
    _activities.clear();
    _lastExplorerCount = null;
    _lastId = null;
    _hasMore = true;
    notifyListeners();
    await _fetch(reset: true);
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_lastId == null || _lastExplorerCount == null) return;
    await _fetch(reset: false);
  }

  Future<void> toggleSave(int activityId) async {
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index < 0) return;
    final activity = _activities[index];
    final nextSaved = !activity.isSaved;
    _applySavedOptimistic(index, nextSaved);
    notifyListeners();

    try {
      if (nextSaved) {
        await saveActivity(activityId);
      } else {
        await unsaveActivity(activityId);
      }
      BucketListController.markStale();
    } catch (e) {
      _applySavedOptimistic(index, activity.isSaved);
      notifyListeners();
      rethrow;
    }
  }

  /// Sync feed card state after a save/unsave that happened outside the feed.
  void syncLocalSave(int activityId, bool saved) {
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index < 0) return;
    if (_activities[index].isSaved == saved) return;
    _applySavedOptimistic(index, saved);
    notifyListeners();
  }

  /// Hide a reported activity from the feed (client-side; API has no filter).
  Future<void> dismissReported(int activityId) async {
    await LocalModeration.instance.reportActivity(activityId);
    final before = _activities.length;
    _activities.removeWhere((a) => a.id == activityId);
    if (_activities.length != before) notifyListeners();
  }

  void _applySavedOptimistic(int index, bool saved) {
    final activity = _activities[index];
    final avatar = currentUserAvatarUrl;
    final avatars = List<String>.from(activity.avatars);
    if (saved) {
      if (avatar != null && avatar.isNotEmpty) {
        avatars.insert(0, avatar);
      }
      _activities[index] = activity.copyWith(
        isSaved: true,
        explorerCount: activity.explorerCount + 1,
        avatars: avatars,
      );
    } else {
      if (avatars.isNotEmpty) avatars.removeAt(0);
      _activities[index] = activity.copyWith(
        isSaved: false,
        explorerCount: (activity.explorerCount - 1).clamp(0, 1 << 30),
        avatars: avatars,
      );
    }
  }

  Future<void> _fetch({required bool reset}) async {
    if (_fetchInProgress) return;
    _fetchInProgress = true;
    _error = null;
    if (reset) {
      _loading = true;
    } else {
      _loadingMore = true;
    }
    notifyListeners();

    try {
      final page = await getActivities(
        sortBy: _sortBy == ActivitiesSortBy.trending ? 'trending' : 'newest',
        lastExplorerCount: reset ? null : _lastExplorerCount,
        lastId: reset ? null : _lastId,
      );
      await _applyPage(page, reset: reset);
    } catch (e) {
      _error = serverErrorText(e);
      if (reset && _activities.isEmpty) {
        // keep empty + error for UI
      }
    } finally {
      _loading = false;
      _loadingMore = false;
      _fetchInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _applyPage(ActivitiesPageResponse page, {required bool reset}) async {
    final reported = await LocalModeration.instance.reportedActivityIds();
    final avatar = currentUserAvatarUrl;
    final processed = page.activities
        .where((a) => !reported.contains(a.id))
        .map((a) {
          if (!a.isSaved || avatar == null || avatar.isEmpty) return a;
          return a.copyWith(avatars: [avatar, ...a.avatars]);
        })
        .toList();

    if (reset) {
      _activities
        ..clear()
        ..addAll(processed);
    } else {
      final existing = {for (final a in _activities) a.id};
      for (final a in processed) {
        if (!existing.contains(a.id)) _activities.add(a);
      }
    }

    _hasMore = page.hasMore;
    _lastExplorerCount = page.lastExplorerCount;
    _lastId = page.lastId;
    _error = null;
    _loading = false;
    _loadingMore = false;
    _fetchInProgress = false;
    notifyListeners();
  }
}
