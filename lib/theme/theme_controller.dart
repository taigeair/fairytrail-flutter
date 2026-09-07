import 'package:flutter/material.dart';

/// Holds the current [ThemeMode] and notifies listeners on change.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initial = ThemeMode.light}) : _mode = initial;

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  bool get isDark {
    if (_mode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggleDark(bool enabled) {
    setMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }
}

/// Provides [ThemeController] down the tree.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in widget tree');
    return scope!.notifier!;
  }
}
