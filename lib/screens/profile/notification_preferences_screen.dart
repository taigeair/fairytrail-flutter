import 'package:fairytrail/api/push_tokens.dart' as push_api;
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/push/notification_prompt_store.dart';
import 'package:fairytrail/push/push_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationPreferencesScreen(),
      ),
    );
  }

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _hasPermission = false;
  bool _messagesEnabled = false;
  bool _meetupEnabled = false;
  bool _includeConnections = false;
  bool _matchInCountryEnabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  bool get _allEnabled =>
      _messagesEnabled &&
      _meetupEnabled &&
      _includeConnections &&
      _matchInCountryEnabled;

  String get _notificationType {
    if (!_messagesEnabled && !_meetupEnabled) return 'none';
    if (_messagesEnabled && _meetupEnabled && _includeConnections) {
      return 'all';
    }
    if (_messagesEnabled && _meetupEnabled) return 'messages_meetups';
    if (_messagesEnabled) return 'messages';
    return 'meetups';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final permitted = await PushService.instance.hasPermission();
      final config = await push_api.fetchNotificationConfig();
      if (!mounted) return;
      setState(() {
        _hasPermission = permitted;
        if (permitted) {
          // Prefer canonical type so legacy flag combos can't show
          // "messages only" while connects are still enabled.
          _applyType(config.type);
          _matchInCountryEnabled = config.matchInCountryNotificationsEnabled;
        } else {
          _applyType('none');
          _matchInCountryEnabled = false;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  void _applyType(String type) {
    switch (type) {
      case 'all':
        _messagesEnabled = true;
        _meetupEnabled = true;
        _includeConnections = true;
      case 'messages_meetups':
        _messagesEnabled = true;
        _meetupEnabled = true;
        _includeConnections = false;
      case 'messages':
        _messagesEnabled = true;
        _meetupEnabled = false;
        _includeConnections = false;
      case 'meetups':
        _messagesEnabled = false;
        _meetupEnabled = true;
        _includeConnections = false;
      default:
        _messagesEnabled = false;
        _meetupEnabled = false;
        _includeConnections = false;
    }
  }

  Future<void> _save({bool? matchInCountryEnabled}) async {
    final type = _notificationType;
    await push_api.updateNotificationConfig(
      type: type,
      matchInCountryNotificationsEnabled:
          matchInCountryEnabled ?? _matchInCountryEnabled,
    );
    if (!mounted) return;
    setState(() {
      _applyType(type);
      if (matchInCountryEnabled != null) {
        _matchInCountryEnabled = matchInCountryEnabled;
      }
    });
    if (type != 'none') {
      NotificationPromptStore.markPrompted(
        userId: AuthScope.of(context).user?.id,
      );
    }
    AppToast.show(context, message: 'Notification preferences updated');
  }

  Future<bool> _ensurePushPermission() async {
    final token = await PushService.instance.enableAndRegister(
      from: 'notifications',
    );
    if (token != null) {
      if (mounted) setState(() => _hasPermission = true);
      return true;
    }
    if (!mounted) return false;
    AppToast.show(
      context,
      message: 'Enable notifications in system Settings first.',
    );
    return false;
  }

  Future<void> _openSystemSettings() async {
    HapticsService.selection();
    final opened = await Geolocator.openAppSettings();
    if (!opened && mounted) {
      AppToast.show(context, message: 'Could not open system Settings.');
    }
  }

  Future<void> _setPushEnabled(bool enabled) async {
    if (_saving || _allEnabled == enabled) return;
    HapticsService.selection();

    final prevMessages = _messagesEnabled;
    final prevMeetup = _meetupEnabled;
    final prevConnections = _includeConnections;
    final prevMatchInCountry = _matchInCountryEnabled;
    setState(() {
      if (enabled) {
        _messagesEnabled = true;
        _meetupEnabled = true;
        _includeConnections = true;
        _matchInCountryEnabled = true;
      } else {
        _messagesEnabled = false;
        _meetupEnabled = false;
        _includeConnections = false;
        _matchInCountryEnabled = false;
      }
      _saving = true;
    });

    try {
      if (enabled && !await _ensurePushPermission()) {
        if (!mounted) return;
        setState(() {
          _messagesEnabled = prevMessages;
          _meetupEnabled = prevMeetup;
          _includeConnections = prevConnections;
          _matchInCountryEnabled = prevMatchInCountry;
        });
        return;
      }
      await _save();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messagesEnabled = prevMessages;
        _meetupEnabled = prevMeetup;
        _includeConnections = prevConnections;
        _matchInCountryEnabled = prevMatchInCountry;
      });
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setMessagesEnabled(bool enabled) async {
    if (_saving || _messagesEnabled == enabled) return;
    HapticsService.selection();

    final prevMessages = _messagesEnabled;
    final prevMeetup = _meetupEnabled;
    final prevConnections = _includeConnections;
    final prevMatchInCountry = _matchInCountryEnabled;
    setState(() {
      _messagesEnabled = enabled;
      // Messages-only must not leave connects/matches enabled in local state.
      if (!enabled || !_meetupEnabled) {
        _includeConnections = false;
      }
      // The backend requires Messages or general notifications for Arrivals.
      if (!enabled) {
        _matchInCountryEnabled = false;
      }
      _saving = true;
    });

    try {
      final wasOff = !prevMessages && !prevMeetup;
      if (enabled && wasOff) {
        if (!await _ensurePushPermission()) {
          if (!mounted) return;
          setState(() => _messagesEnabled = prevMessages);
          return;
        }
      }
      await _save();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messagesEnabled = prevMessages;
        _meetupEnabled = prevMeetup;
        _includeConnections = prevConnections;
        _matchInCountryEnabled = prevMatchInCountry;
      });
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setMeetupEnabled(bool enabled) async {
    if (_saving || _meetupEnabled == enabled) return;
    HapticsService.selection();

    final prevMessages = _messagesEnabled;
    final prevMeetup = _meetupEnabled;
    final prevConnections = _includeConnections;
    setState(() {
      _meetupEnabled = enabled;
      if (enabled && _messagesEnabled) {
        // Adding meetups to messages-only → messages & meetups (no connects).
        _includeConnections = false;
      } else if (!enabled) {
        _includeConnections = false;
      }
      _saving = true;
    });

    try {
      final wasOff = !prevMessages && !prevMeetup;
      if (enabled && wasOff) {
        if (!await _ensurePushPermission()) {
          if (!mounted) return;
          setState(() => _meetupEnabled = prevMeetup);
          return;
        }
      }
      await _save();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messagesEnabled = prevMessages;
        _meetupEnabled = prevMeetup;
        _includeConnections = prevConnections;
      });
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setMatchInCountryEnabled(bool enabled) async {
    if (_saving || _matchInCountryEnabled == enabled) return;
    HapticsService.selection();

    final prevMatchInCountry = _matchInCountryEnabled;
    final prevMessages = _messagesEnabled;
    setState(() {
      _matchInCountryEnabled = enabled;
      _saving = true;
    });

    try {
      if (enabled && !_messagesEnabled && !_includeConnections) {
        if (!await _ensurePushPermission()) {
          if (!mounted) return;
          setState(() => _matchInCountryEnabled = prevMatchInCountry);
          return;
        }
        setState(() {
          _messagesEnabled = true;
        });
      }
      await _save(matchInCountryEnabled: enabled);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _matchInCountryEnabled = prevMatchInCountry;
        _messagesEnabled = prevMessages;
      });
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.07);

    return AppScaffold(
      title: 'Push notifications',
      body: _loading
          ? const Center(child: AppLoading())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _SwitchRow(
                              title: 'All notifications',
                              subtitle:
                                  'Connect requests, new connections, messages, bucket list, meetups, and more',
                              value: _allEnabled,
                              onChanged: _saving ? null : _setPushEnabled,
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: dividerColor,
                            ),
                            _SwitchRow(
                              title: 'Messages',
                              subtitle: 'Direct messages',
                              value: _messagesEnabled,
                              onChanged: _saving ? null : _setMessagesEnabled,
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: dividerColor,
                            ),
                            _SwitchRow(
                              title: 'Meetups',
                              subtitle:
                                  'Meetups and meetup group chat messages',
                              value: _meetupEnabled,
                              onChanged: _saving ? null : _setMeetupEnabled,
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: dividerColor,
                            ),
                            _SwitchRow(
                              title: 'Arrivals',
                              subtitle:
                                  'Your connection lands in your city or country',
                              value: _matchInCountryEnabled,
                              onChanged: _saving
                                  ? null
                                  : _setMatchInCountryEnabled,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_hasPermission)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppText(
                          'Turn on notifications in your device settings to manage your notification preferences',
                          variant: AppTextVariant.bodySmall,
                          textAlign: TextAlign.center,
                          color: AppColors.textSecondaryOf(context),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Open system settings',
                          onPressed: _openSystemSettings,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
