import 'dart:async';
import 'dart:io';

import 'package:fairytrail/api/push_tokens.dart' as push_api;
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/push/notification_prompt_store.dart';
import 'package:fairytrail/push/push_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Soft prompt once per user. Check is sync via [NotificationPromptStore].
class EnableNotificationsScreen extends StatefulWidget {
  const EnableNotificationsScreen({
    super.key,
    this.from = 'profile',
    this.onDone,
  });

  final String from;
  final VoidCallback? onDone;

  static bool _opening = false;

  static Future<void> open(
    BuildContext context, {
    String from = 'first_connect',
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EnableNotificationsScreen(from: from),
      ),
    );
  }

  /// Instant local-cache check — never blocks connect. Opens UI asynchronously.
  static void openIfNeeded(
    BuildContext context, {
    String from = 'first_connect',
  }) {
    if (_opening) return;
    if (NotificationPromptStore.wasPrompted) {
      debugPrint('[Notifications] skip — already prompted (memory)');
      return;
    }

    String? userId;
    try {
      userId = AuthScope.of(context).user?.id;
    } catch (_) {}

    // Sync mark so a second connect/send in the same frame won't re-open.
    NotificationPromptStore.markPrompted(userId: userId);
    if (!context.mounted) return;

    _opening = true;
    debugPrint('[Notifications] showing soft prompt ($from)');
    open(context, from: from).whenComplete(() {
      _opening = false;
    });
  }

  @override
  State<EnableNotificationsScreen> createState() =>
      _EnableNotificationsScreenState();
}

class _EnableNotificationsScreenState extends State<EnableNotificationsScreen>
    with WidgetsBindingObserver {
  bool _loading = false;
  /// True after OS permission fails — CTA becomes Open Settings + how-to copy.
  bool _needsOpenSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_onResumedFromSettings());
  }

  /// Returning from Settings: restore the original CTA; finish if now granted.
  Future<void> _onResumedFromSettings() async {
    if (!_needsOpenSettings || !mounted) return;

    setState(() => _needsOpenSettings = false);

    final permitted = await PushService.instance.hasPermission();
    if (!permitted || !mounted) return;

    await _completeWithPermission();
  }

  Future<void> _enable() async {
    if (_needsOpenSettings) {
      await _openAppSettings();
      return;
    }

    setState(() => _loading = true);
    final userId = AuthScope.of(context).user?.id;
    try {
      final token = await PushService.instance.enableAndRegister(
        from: 'notifications',
      );
      if (!mounted) return;

      if (token == null) {
        unawaited(
          track('enable_notifications_error', {
            'from': widget.from,
            'error': 'permission_denied',
          }),
        );
        // Stay on screen — switch CTA to Open Settings (common after a
        // welcome-screen denial where the OS will not show the dialog again).
        setState(() => _needsOpenSettings = true);
        NotificationPromptStore.markPrompted(userId: userId);
        return;
      }

      await _finishEnabled(userId: userId);
    } catch (e) {
      unawaited(
        track('enable_notifications_error', {
          'from': widget.from,
          'error': e.toString(),
        }),
      );
      if (mounted) {
        AppToast.show(context, message: serverErrorText(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeWithPermission() async {
    setState(() => _loading = true);
    final userId = AuthScope.of(context).user?.id;
    try {
      final token = await PushService.instance.enableAndRegister(
        from: 'notifications',
      );
      if (!mounted) return;
      if (token == null) return;
      await _finishEnabled(userId: userId);
    } catch (e) {
      debugPrint('[Notifications] resume enable failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finishEnabled({required String? userId}) async {
    try {
      // Don't wipe an existing choice (e.g. messages-only). Soft prompt only
      // bootstraps when the user still has no notification prefs.
      final existing = await push_api.fetchNotificationConfig();
      if (existing.type == 'none') {
        await push_api.updateNotificationConfigType('all');
      }
    } catch (e) {
      debugPrint('[Notifications] update config failed: $e');
    }
    if (!mounted) return;
    AppToast.show(context, message: 'Notifications enabled');
    NotificationPromptStore.markPrompted(userId: userId);
    widget.onDone?.call();
    Navigator.of(context).pop();
  }

  Future<void> _openAppSettings() async {
    final opened = await Geolocator.openAppSettings();
    if (!opened) {
      debugPrint('[Notifications] open settings failed');
    }
  }

  void _skip() {
    NotificationPromptStore.markPrompted(
      userId: AuthScope.of(context).user?.id,
    );
    widget.onDone?.call();
    Navigator.of(context).pop();
  }

  String get _bodyCopy {
    if (_needsOpenSettings) {
      if (Platform.isIOS) {
        return 'Notifications are off for Fairytrail. Open Settings → Notifications, then turn Allow Notifications on.';
      }
      return 'Notifications are off for Fairytrail. Open Settings → Apps → Fairytrail → Notifications, then turn them on.';
    }
    return 'Set up notifications to know when you get a new connection or message.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _skip,
        ),
      ),
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                _needsOpenSettings
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_active_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              AppText(
                _needsOpenSettings
                    ? 'Enable notifications in Settings'
                    : 'Don’t miss a beat',
                variant: AppTextVariant.headline,
                fontWeight: FontWeight.w700,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              AppText(
                _bodyCopy,
                variant: AppTextVariant.body,
                textAlign: TextAlign.center,
                color: AppColors.textSecondaryOf(context),
              ),
              if (!_needsOpenSettings) ...[
                const SizedBox(height: 8),
                AppText(
                  '93% of active users have notifications.',
                  variant: AppTextVariant.bodySmall,
                  textAlign: TextAlign.center,
                  color: AppColors.textSecondaryOf(context),
                ),
              ],
              const Spacer(),
              AppButton(
                label: _needsOpenSettings
                    ? 'Open Settings'
                    : 'Turn on notifications',
                isLoading: _loading,
                onPressed: _enable,
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Maybe later',
                variant: AppButtonVariant.text,
                onPressed: _skip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
