import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';

enum ConnectivityBannerPhase { hidden, offline, backOnline }

/// App-wide connectivity state. Banner UI is rendered under each screen header.
class ConnectivityController extends ChangeNotifier
    with WidgetsBindingObserver {
  ConnectivityController() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasConnectivity(results);
      _debounce?.cancel();
      if (!online) {
        // Show "No internet" immediately.
        _applyOnline(false);
      } else {
        // Confirm online briefly — iOS often blips wifi after none.
        _debounce = Timer(
          _debounceDuration,
          () => _applyOnline(true),
        );
      }
    });
  }

  static const animDuration = Duration(milliseconds: 320);
  static const greenHold = Duration(milliseconds: 1400);
  static const _debounceDuration = Duration(milliseconds: 350);
  /// Ignore brief offline blips (common on iOS at launch) for "Back online".
  static const _minOfflineForBackOnline = Duration(milliseconds: 1000);

  /// Compact strip height (text + vertical padding).
  static const stripHeight = 28.0;

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _hideTimer;
  Timer? _debounce;

  ConnectivityBannerPhase phase = ConnectivityBannerPhase.hidden;
  bool? _online;
  DateTime? _offlineSince;
  bool _initialized = false;

  bool get visible => phase != ConnectivityBannerPhase.hidden;

  double get extent => visible ? stripHeight : 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> refresh() async {
    try {
      _debounce?.cancel();
      _applyOnline(_hasConnectivity(await _connectivity.checkConnectivity()));
    } catch (_) {
      // First launch: treat failed check as initialized online (no banner).
      if (!_initialized) {
        _initialized = true;
        _online = true;
      }
    }
  }

  void _applyOnline(bool online) {
    // First reading only sets baseline — never flash "Back online" on open.
    if (!_initialized) {
      _initialized = true;
      _online = online;
      if (!online) {
        _offlineSince = DateTime.now();
        phase = ConnectivityBannerPhase.offline;
        notifyListeners();
      }
      return;
    }

    if (_online == online) return;
    _online = online;

    if (!online) {
      _hideTimer?.cancel();
      _offlineSince = DateTime.now();
      phase = ConnectivityBannerPhase.offline;
      notifyListeners();
      return;
    }

    // Back online — green only after a real offline period (not a launch blip).
    if (phase == ConnectivityBannerPhase.offline) {
      final offlineFor = _offlineSince == null
          ? Duration.zero
          : DateTime.now().difference(_offlineSince!);
      _offlineSince = null;
      _hideTimer?.cancel();

      if (offlineFor >= _minOfflineForBackOnline) {
        phase = ConnectivityBannerPhase.backOnline;
        notifyListeners();
        _hideTimer = Timer(greenHold, () {
          if (phase != ConnectivityBannerPhase.backOnline) return;
          phase = ConnectivityBannerPhase.hidden;
          notifyListeners();
        });
      } else {
        // Brief blip — collapse quietly, no green.
        phase = ConnectivityBannerPhase.hidden;
        notifyListeners();
      }
      return;
    }

    if (phase != ConnectivityBannerPhase.hidden) {
      _hideTimer?.cancel();
      phase = ConnectivityBannerPhase.hidden;
      notifyListeners();
    }
  }

  bool _hasConnectivity(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

class ConnectivityScope extends InheritedNotifier<ConnectivityController> {
  const ConnectivityScope({
    super.key,
    required ConnectivityController controller,
    required super.child,
  }) : super(notifier: controller);

  static ConnectivityController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ConnectivityScope>();
    assert(scope != null, 'ConnectivityScope not found');
    return scope!.notifier!;
  }

  static ConnectivityController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ConnectivityScope>()
        ?.notifier;
  }
}

/// Provides [ConnectivityController] without changing layout / status bar.
class ConnectivityRoot extends StatefulWidget {
  const ConnectivityRoot({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityRoot> createState() => _ConnectivityRootState();
}

class _ConnectivityRootState extends State<ConnectivityRoot> {
  late final ConnectivityController _controller = ConnectivityController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConnectivityScope(controller: _controller, child: widget.child);
  }
}

/// Compact in-flow strip for under a themed header (not floating, not status bar).
class ConnectivityBannerStrip extends StatelessWidget {
  const ConnectivityBannerStrip({super.key});

  static const _offlineColor = Color(0xFFD32F2F);
  static const _onlineColor = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final controller = ConnectivityScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final phase = controller.phase;
        final visible = phase != ConnectivityBannerPhase.hidden;
        final offline = phase == ConnectivityBannerPhase.offline;
        final color = offline ? _offlineColor : _onlineColor;
        final label =
            offline ? 'No internet connection' : 'Back online';

        return AnimatedSize(
          duration: ConnectivityController.animDuration,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: visible
              ? AnimatedContainer(
                  duration: ConnectivityController.animDuration,
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  height: ConnectivityController.stripHeight,
                  color: color,
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: ConnectivityController.animDuration,
                    child: AppText(
                      label,
                      key: ValueKey(label),
                      variant: AppTextVariant.label,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }
}

/// Use as [AppBar.bottom] so the strip extends the themed app bar.
class ConnectivityAppBarBottom extends StatelessWidget
    implements PreferredSizeWidget {
  const ConnectivityAppBarBottom({super.key, required this.height});

  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) => const ConnectivityBannerStrip();
}
