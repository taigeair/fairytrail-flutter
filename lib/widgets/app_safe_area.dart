import 'package:flutter/material.dart';

/// [SafeArea] that does not keep a blank strip above the keyboard.
///
/// The IME already covers the system navigation area. Keeping
/// [MediaQueryData.viewPadding] as a bottom inset while typing leaves a white
/// bar on every text field. Nested Scaffolds can also zero
/// [MediaQuery.padding.bottom]; when the keyboard is closed we still clear the
/// home indicator via viewPadding.
class AppSafeArea extends StatelessWidget {
  const AppSafeArea({
    super.key,
    required this.child,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
    this.minimum = EdgeInsets.zero,
  });

  final Widget child;
  final bool left;
  final bool top;
  final bool right;
  final bool bottom;
  final EdgeInsets minimum;

  @override
  Widget build(BuildContext context) {
    // Subscribe to MediaQuery so we rebuild when the IME opens or the
    // scaffold resizes. Scaffold may zero viewInsets for its body, so also
    // read the raw view metrics.
    final media = MediaQuery.of(context);
    final viewMq = MediaQueryData.fromView(View.of(context));
    final keyboardOpen =
        media.viewInsets.bottom > 0 || viewMq.viewInsets.bottom > 0;
    final applyBottom = bottom && !keyboardOpen;
    final minBottom = applyBottom
        ? (minimum.bottom > viewMq.viewPadding.bottom
              ? minimum.bottom
              : viewMq.viewPadding.bottom)
        : minimum.bottom;

    return SafeArea(
      left: left,
      top: top,
      right: right,
      bottom: applyBottom,
      minimum: minimum.copyWith(bottom: minBottom),
      child: child,
    );
  }
}
