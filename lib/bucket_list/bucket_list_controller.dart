import 'package:fairytrail/api/activities.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:flutter/foundation.dart';

/// Own bucket list grouped by tag.
class BucketListController extends ChangeNotifier {
  BucketListController({required this.profileId});

  final int profileId;

  /// Set when Explore (or elsewhere) saves/unsaves so the tab can catch up
  /// without reloading on every switch.
  static bool stale = false;

  static void markStale() => stale = true;

  List<ActivityDto> _activities = [];
  bool _loading = false;
  bool _refreshing = false;
  String? _error;

  List<ActivityDto> get activities => List.unmodifiable(_activities);
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  String? get error => _error;
  bool get isEmpty => !_loading && _activities.isEmpty;
  bool get hasData => _activities.isNotEmpty;

  List<ActivityDto> get currentYear => _byTag(BucketListActivityTag.currentYear);

  List<ActivityDto> get upcoming => _byTag(BucketListActivityTag.upcoming);

  List<ActivityDto> get completed => _byTag(BucketListActivityTag.completed);

  List<ActivityDto> _byTag(BucketListActivityTag tag) =>
      _activities.where((a) => a.tag == tag).toList();

  /// Loads the list. Use [silent] (or when data is already shown) to avoid
  /// replacing the list with a full-screen spinner.
  Future<void> load({bool silent = false}) async {
    if (profileId <= 0) {
      _error = 'Profile not ready';
      notifyListeners();
      return;
    }

    final showSpinner = !silent && _activities.isEmpty;
    if (showSpinner) {
      _loading = true;
    } else {
      _refreshing = true;
    }
    _error = null;
    notifyListeners();

    try {
      final items = await getProfileActivities(profileId);
      _activities = items.map((a) => a.copyWith(tag: a.tag)).toList();
      stale = false;
    } catch (e) {
      _error = serverErrorText(e);
    } finally {
      _loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh / post-save reload without blanking the UI.
  Future<void> refresh() => load(silent: true);

  /// Reorder within a single section (local only — matches RN).
  void reorderWithinTag({
    required BucketListActivityTag tag,
    required int fromIndex,
    required int toIndex,
  }) {
    if (tag == BucketListActivityTag.completed) return;
    if (fromIndex == toIndex) return;

    final section = _byTag(tag);
    if (fromIndex < 0 ||
        fromIndex >= section.length ||
        toIndex < 0 ||
        toIndex >= section.length) {
      return;
    }

    final next = List<ActivityDto>.from(section);
    final item = next.removeAt(fromIndex);
    next.insert(toIndex, item);
    _setSections(
      currentYear: tag == BucketListActivityTag.currentYear
          ? next
          : currentYear,
      upcoming:
          tag == BucketListActivityTag.upcoming ? next : upcoming,
    );
    notifyListeners();
  }

  /// Move [activity] into [tag], optionally inserting at [toIndex].
  ///
  /// Same-tag moves are local reorders. Cross-tag moves PATCH the API.
  Future<void> moveToTag(
    ActivityDto activity,
    BucketListActivityTag tag, {
    int? toIndex,
  }) async {
    if (tag == BucketListActivityTag.completed) return;

    final previous = List<ActivityDto>.from(_activities);
    final fromTag = activity.tag;
    final without = _activities.where((a) => a.id != activity.id).toList();
    final updated = activity.copyWith(tag: tag);

    List<ActivityDto> targetSection =
        without.where((a) => a.tag == tag).toList();
    final insertAt = (toIndex ?? targetSection.length)
        .clamp(0, targetSection.length);
    targetSection = [...targetSection]..insert(insertAt, updated);

    final otherTag = tag == BucketListActivityTag.currentYear
        ? BucketListActivityTag.upcoming
        : BucketListActivityTag.currentYear;
    final otherSection =
        without.where((a) => a.tag == otherTag).toList();

    _setSections(
      currentYear: tag == BucketListActivityTag.currentYear
          ? targetSection
          : otherSection,
      upcoming: tag == BucketListActivityTag.upcoming
          ? targetSection
          : otherSection,
    );
    notifyListeners();

    if (fromTag == tag) return;

    try {
      final remote = await patchBucketListTag(
        activityId: activity.id,
        tag: tag,
      );
      if (remote.isNotEmpty) {
        _mergeRemoteTags(remote);
      }
      notifyListeners();
    } catch (e) {
      _activities = previous;
      notifyListeners();
      rethrow;
    }
  }

  void _setSections({
    required List<ActivityDto> currentYear,
    required List<ActivityDto> upcoming,
  }) {
    _activities = [
      ...currentYear,
      ...upcoming,
      ..._byTag(BucketListActivityTag.completed),
    ];
  }

  void _mergeRemoteTags(List<ActivityDto> remote) {
    final byId = {for (final a in remote) a.id: a};
    _activities = _activities.map((local) {
      final r = byId[local.id];
      if (r == null) return local;
      return local.copyWith(tag: r.tag);
    }).toList();

    for (final r in remote) {
      if (_activities.every((a) => a.id != r.id)) {
        _activities = [..._activities, r];
      }
    }
  }

  void replaceActivity(ActivityDto activity) {
    final index = _activities.indexWhere((a) => a.id == activity.id);
    if (index < 0) {
      _activities = [..._activities, activity];
    } else {
      _activities = [..._activities]..[index] = activity;
    }
    notifyListeners();
  }

  void removeActivity(int id) {
    _activities = _activities.where((a) => a.id != id).toList();
    notifyListeners();
  }
}
