import 'package:fairytrail/api/explore.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:flutter/material.dart';

/// Incoming connect requests shown on Messages (RN `useIncomingConnects`).
class IncomingConnectsController extends ChangeNotifier {
  bool _loading = false;
  bool _revealLoading = false;
  int _total = 0;
  FullProfileDto? _firstProfile;
  List<FullProfileDto> _profiles = const [];
  FullProfileDto? _lastSkipped;
  String? _error;
  final Set<int> _busyIds = {};

  bool get loading => _loading;
  bool get revealLoading => _revealLoading;
  int get total => _total;
  FullProfileDto? get firstProfile => _firstProfile;
  List<FullProfileDto> get profiles => _profiles;
  FullProfileDto? get lastSkipped => _lastSkipped;
  String? get error => _error;
  bool get hasIncoming => _total > 0 && _firstProfile != null;

  bool isBusy(int profileId) => _busyIds.contains(profileId);

  /// Banner only — original `/profiles/incoming` (first + total).
  Future<void> load({bool force = false}) async {
    if (!force && _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await fetchIncomingConnections();
      _total = res.total;
      _firstProfile = res.firstProfile;
    } catch (e) {
      _error = serverErrorText(e);
      debugPrint('[IncomingConnects] load failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Reveal screen — full list from `/profiles/incoming/list`.
  Future<void> loadRevealList({bool force = false}) async {
    if (!force && _revealLoading) return;
    _revealLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await fetchIncomingConnectionsList();
      _profiles = List<FullProfileDto>.from(res.profiles);
      _total = res.total;
      _firstProfile = _profiles.isEmpty ? null : _profiles.first;
    } catch (e) {
      _error = serverErrorText(e);
      debugPrint('[IncomingConnects] reveal list failed: $e');
    } finally {
      _revealLoading = false;
      notifyListeners();
    }
  }

  /// Drop a profile that was already matched elsewhere (explore / messages).
  void onMatched(int profileId) {
    _profiles = _profiles.where((p) => p.id != profileId).toList();
    if (_firstProfile?.id == profileId) {
      _firstProfile = _profiles.isEmpty ? null : _profiles.first;
    }
    if (_total > 0) _total = (_total - 1).clamp(0, 1 << 30);
    notifyListeners();
    load(force: true);
  }

  Future<ConnectProfileResponse?> accept(FullProfileDto profile) async {
    if (_busyIds.contains(profile.id)) return null;
    _busyIds.add(profile.id);
    notifyListeners();
    try {
      final result = await connectProfile(
        profileId: profile.id,
        source: 'incoming',
      );
      _lastSkipped = null;
      _removeLocal(profile.id);
      return result;
    } finally {
      _busyIds.remove(profile.id);
      notifyListeners();
    }
  }

  Future<void> ignore(FullProfileDto profile) async {
    if (_busyIds.contains(profile.id)) return;
    _busyIds.add(profile.id);
    notifyListeners();
    try {
      await skipProfile(profileId: profile.id, source: 'incoming');
      _lastSkipped = profile;
      _removeLocal(profile.id);
    } finally {
      _busyIds.remove(profile.id);
      notifyListeners();
    }
  }

  Future<void> undoLastSkip() async {
    final skipped = _lastSkipped;
    if (skipped == null) return;
    _busyIds.add(skipped.id);
    notifyListeners();
    try {
      await undoSkipProfile(profileId: skipped.id);
      _lastSkipped = null;
      await loadRevealList(force: true);
      await load(force: true);
    } finally {
      _busyIds.remove(skipped.id);
      notifyListeners();
    }
  }

  void _removeLocal(int profileId) {
    _profiles = _profiles.where((p) => p.id != profileId).toList();
    if (_firstProfile?.id == profileId) {
      _firstProfile = _profiles.isEmpty ? null : _profiles.first;
    }
    if (_total > 0) _total -= 1;
    if (_profiles.isEmpty && _total == 0) {
      _firstProfile = null;
    }
  }
}

class IncomingConnectsScope extends InheritedNotifier<IncomingConnectsController> {
  const IncomingConnectsScope({
    super.key,
    required IncomingConnectsController controller,
    required super.child,
  }) : super(notifier: controller);

  static IncomingConnectsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<IncomingConnectsScope>();
    assert(scope != null, 'IncomingConnectsScope not found');
    return scope!.notifier!;
  }

  static IncomingConnectsController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<IncomingConnectsScope>()
        ?.notifier;
  }
}
