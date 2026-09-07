import 'package:fairytrail/screens/shell/floating_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Controls visibility of shell chrome (bottom nav) while Explore scrolls.
class ShellChromeController extends ChangeNotifier {
  ShellChromeController({this.onSelectTab});

  /// Switch shell tab (e.g. Explore → Messages after a match).
  final ValueChanged<AppTab>? onSelectTab;
  VoidCallback? onBrowseActivityIdeas;

  bool _visible = true;
  double _hideProgress = 0;
  double _bottomNavHeight = 0;

  bool get visible => _visible;

  /// 0 = fully visible, 1 = fully hidden (scroll-linked).
  double get hideProgress => _hideProgress;

  /// Laid-out height of the floating bottom nav (includes safe-area inset).
  ///
  /// `0` until [MeasureSize] reports a real height — treat that as unset.
  double get bottomNavHeight => _bottomNavHeight;

  /// [bottomNavHeight] when measured, otherwise [fallback].
  double bottomNavHeightOr(double fallback) =>
      _bottomNavHeight > 0 ? _bottomNavHeight : fallback;

  void selectTab(AppTab tab) => onSelectTab?.call(tab);

  void browseActivityIdeas() {
    show();
    selectTab(AppTab.explore);
    onBrowseActivityIdeas?.call();
  }

  void setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    _hideProgress = value ? 0 : 1;
    notifyListeners();
  }

  void setHideProgress(double value) {
    final p = value.clamp(0.0, 1.0);
    if ((p - _hideProgress).abs() < 0.001) return;
    _hideProgress = p;
    final nextVisible = p < 0.85;
    if (_visible != nextVisible) _visible = nextVisible;
    notifyListeners();
  }

  void setBottomNavHeight(double height) {
    if ((height - _bottomNavHeight).abs() < 0.5) return;
    _bottomNavHeight = height;
    notifyListeners();
  }

  void show() => setVisible(true);

  void hide() => setVisible(false);
}

class ShellChromeScope extends InheritedNotifier<ShellChromeController> {
  const ShellChromeScope({
    super.key,
    required ShellChromeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Set by [MainShell] so pushed routes above this scope can still switch tabs.
  static ShellChromeController? active;

  static ShellChromeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellChromeScope>();
    assert(scope != null || active != null, 'ShellChromeScope not found');
    return scope?.notifier ?? active!;
  }

  static ShellChromeController? maybeOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ShellChromeScope>()
            ?.notifier ??
        active;
  }
}

/// Reports child size after layout (for bottom-nav clearance).
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({
    super.key,
    required this.onChange,
    required Widget super.child,
  });

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasureSize(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) {
    (renderObject as _RenderMeasureSize).onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final size = this.size;
    if (_oldSize == size) return;
    _oldSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(size);
    });
  }
}
