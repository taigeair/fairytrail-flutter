import 'dart:async';

import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';

/// Global toast on the root overlay — appears above bottom sheets & dialogs.
///
/// ```dart
/// AppToast.show(context, message: 'Saved');
/// ```
abstract final class AppToast {
  static OverlayEntry? _entry;
  static Timer? _hideTimer;

  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    hide();

    final entry = OverlayEntry(
      builder: (_) => _AppToastBanner(message: message),
    );

    _entry = entry;
    overlay.insert(entry);

    _hideTimer = Timer(duration, () {
      hide();
    });
  }

  static void hide() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _AppToastBanner extends StatefulWidget {
  const _AppToastBanner({required this.message});

  final String message;

  @override
  State<_AppToastBanner> createState() => _AppToastBannerState();
}

class _AppToastBannerState extends State<_AppToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;

    return Positioned(
      left: 20,
      right: 20,
      top: top + 12,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    child: AppText(
                      widget.message,
                      variant: AppTextVariant.label,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
