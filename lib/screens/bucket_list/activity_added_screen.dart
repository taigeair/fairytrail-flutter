import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/api/push_tokens.dart' as push_api;
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/push/notification_prompt_store.dart';
import 'package:fairytrail/push/push_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class ActivityAddedScreen extends StatefulWidget {
  const ActivityAddedScreen({super.key, required this.activity});

  final ActivityDto activity;

  @override
  State<ActivityAddedScreen> createState() => _ActivityAddedScreenState();
}

class _ActivityAddedScreenState extends State<ActivityAddedScreen>
    with WidgetsBindingObserver {
  late final ConfettiController _confetti;
  bool? _activityNotificationsEnabled;
  bool _openingNotifications = false;
  bool _waitingForSystemSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confetti.play();
      _checkNotificationSettings();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confetti.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSystemSettings) {
      unawaited(_resumeFromSystemSettings());
    }
  }

  Future<void> _checkNotificationSettings() async {
    try {
      final permitted = await PushService.instance.hasPermission();
      if (!permitted) {
        if (mounted) setState(() => _activityNotificationsEnabled = false);
        return;
      }
      final config = await push_api.fetchNotificationConfig();
      if (!mounted) return;
      setState(() {
        _activityNotificationsEnabled = config.notificationsEnabled;
      });
    } catch (_) {
      // Leave the button hidden when the server preference cannot be checked.
    }
  }

  Future<void> _enableNotifications() async {
    if (_openingNotifications) return;
    setState(() => _openingNotifications = true);
    try {
      final token = await PushService.instance.enableAndRegister(
        from: 'activity_added',
      );
      if (!mounted) return;
      if (token == null) {
        _waitingForSystemSettings = true;
        final opened = await Geolocator.openAppSettings();
        if (!opened) {
          _waitingForSystemSettings = false;
          if (mounted) {
            AppToast.show(context, message: 'Could not open system Settings.');
          }
        }
        return;
      }

      await _turnOnAllAndContinue();
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'Could not turn on notifications. Try again.',
      );
    } finally {
      if (mounted) setState(() => _openingNotifications = false);
    }
  }

  Future<void> _resumeFromSystemSettings() async {
    _waitingForSystemSettings = false;
    if (!await PushService.instance.hasPermission() || !mounted) return;

    setState(() => _openingNotifications = true);
    try {
      final token = await PushService.instance.enableAndRegister(
        from: 'activity_added',
      );
      if (token == null || !mounted) return;
      await _turnOnAllAndContinue();
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Could not turn on notifications. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingNotifications = false);
    }
  }

  Future<void> _turnOnAllAndContinue() async {
    await push_api.updateNotificationConfigType('all');
    if (!mounted) return;
    NotificationPromptStore.markPrompted(
      userId: AuthScope.of(context).user?.id,
    );
    AppToast.show(context, message: 'Notifications turned on');
    _continue();
  }

  void _continue() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final imageDimension = screenSize.shortestSide >= 600
        ? screenSize.width * 0.66
        : 280.0;

    return Stack(
      children: [
        AppScaffold(
          title: 'Activity added!',
          showAppBar: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: SizedBox.square(
                  dimension: imageDimension,
                  child: AppCachedImage(
                    url: widget.activity.photo.url,
                    borderRadius: 12,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 20),
                child: FractionallySizedBox(
                  widthFactor: 0.1,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      color: AppColors.borderOf(context),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
              AppText(
                'This activity will appear on your profile and perhaps in Explore → Activities. Turn on notifications to find out when someone joins and start planning together.',
                variant: AppTextVariant.body,
                textAlign: TextAlign.center,
                color: AppColors.textSecondaryOf(context),
              ),
              const Spacer(),
              const SizedBox(height: 24),
              AppButton(label: 'Continue', onPressed: _continue),
              if (_activityNotificationsEnabled == false) ...[
                const SizedBox(height: 8),
                AppButton(
                  label: 'Turn on notifications',
                  variant: AppButtonVariant.secondary,
                  isLoading: _openingNotifications,
                  onPressed: _enableNotifications,
                ),
              ],
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 28,
            maxBlastForce: 20,
            minBlastForce: 8,
            emissionFrequency: 0.05,
          ),
        ),
      ],
    );
  }
}
