import 'dart:async';

import 'package:fairytrail/location/location_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/theme/app_shadows.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Polished "Where are you?" prompt for Explore / post-signup.
class LocationPromptView extends StatefulWidget {
  const LocationPromptView({
    super.key,
    required this.onSuccess,
    this.onSkip,
    this.autoAsk = false,
    this.compact = false,
    this.initialError,
    this.initialNeedsSettings = false,
  });

  final VoidCallback onSuccess;
  final VoidCallback? onSkip;
  final bool autoAsk;

  /// When true, fits inside Explore without full-screen hero spacing.
  final bool compact;

  /// Prefill error (e.g. failed app-open location check).
  final String? initialError;

  /// The permission check that opened this prompt already established that
  /// the user must leave the app to enable location.
  final bool initialNeedsSettings;

  @override
  State<LocationPromptView> createState() => _LocationPromptViewState();
}

class _LocationPromptViewState extends State<LocationPromptView>
    with WidgetsBindingObserver {
  bool _loading = false;
  bool _needsSettings = false;
  String? _error;
  bool _didAutoAsk = false;
  bool _returningFromSettings = false;
  bool _didReconcile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _error = widget.initialError;
    _needsSettings = widget.initialNeedsSettings;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    // If we were told to open Settings but permission is already granted
    // (common after the user enables it outside this button), fetch instead.
    final alreadyTried = await _reconcilePermissionState();
    if (!mounted) return;
    if (widget.autoAsk && !_didAutoAsk && !alreadyTried) {
      _didAutoAsk = true;
      await _onShare();
    }
  }

  /// Clears a stale "Open Settings" state when access is already available.
  /// Returns true when a fetch was attempted.
  Future<bool> _reconcilePermissionState() async {
    if (_didReconcile) return false;
    _didReconcile = true;
    final serviceEnabled = await LocationService.isServiceEnabled();
    final permissionGranted = await LocationService.hasLocationPermission();
    if (!mounted) return false;
    if (serviceEnabled && permissionGranted) {
      if (_needsSettings || widget.initialNeedsSettings) {
        setState(() {
          _needsSettings = false;
          _error = null;
        });
        await _onShare();
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _returningFromSettings) {
      _returningFromSettings = false;
      unawaited(_continueAfterSettings());
    }
  }

  Future<void> _continueAfterSettings() async {
    final serviceEnabled = await LocationService.isServiceEnabled();
    final permissionGranted = await LocationService.hasLocationPermission();
    if (!mounted) return;
    if (serviceEnabled && permissionGranted) {
      setState(() {
        _needsSettings = false;
        _error = null;
      });
      await _onShare();
      return;
    }
    setState(() {
      _needsSettings = true;
      _error = serviceEnabled
          ? LocationService.appLocationSettingsMessage
          : 'Turn on Location Services to continue.';
    });
  }

  Future<void> _openSettingsForCurrentBlocker() async {
    _returningFromSettings = true;
    final serviceEnabled = await LocationService.isServiceEnabled();
    final opened = serviceEnabled
        ? await LocationService.openAppSettings()
        : await LocationService.openLocationSettings();
    if (!opened) _returningFromSettings = false;
  }

  /// Primary CTA: share / retry fetch. Never trap on Settings when permission
  /// is already granted.
  Future<void> _onShare() async {
    if (_loading) return;

    final serviceEnabled = await LocationService.isServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _needsSettings = true;
        _error = 'Turn on Location Services to continue.';
      });
      await _openSettingsForCurrentBlocker();
      return;
    }

    final permission = await LocationService.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _needsSettings = true;
        _error = LocationService.appLocationSettingsMessage;
      });
      await _openSettingsForCurrentBlocker();
      return;
    }

    // Permission denied (but not forever) or already granted → request / fetch.
    setState(() {
      _loading = true;
      _error = null;
      _needsSettings = false;
    });

    final outcome = await LocationService.shareCurrentLocation();
    if (!mounted) return;

    if (outcome.isSuccess) {
      // Keep showing the loading view while the parent persists its location
      // state and replaces this gate. Clearing it here briefly flashes the
      // "Where are you?" prompt again before Explore is ready.
      widget.onSuccess();
      return;
    }

    final needsSettings =
        outcome.result == LocationShareResult.permissionPermanentlyDenied ||
        outcome.result == LocationShareResult.serviceDisabled;

    setState(() {
      _loading = false;
      _needsSettings = needsSettings;
      _error = outcome.errorMessage;
    });
  }

  /// Explicit manual refetch — same path as share, always attempts GPS again.
  Future<void> _onUpdateLocation() async {
    if (_loading) return;
    setState(() {
      _needsSettings = false;
      _error = null;
    });
    await _onShare();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoading(message: 'Getting location ...');
    }

    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, widget.compact ? 24 : 16, 24, 24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.9),
                            AppColors.primary.withValues(alpha: 0.85),
                          ],
                        ),
                        boxShadow: AppShadows.of(context),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const AppText(
                      'Where are you?',
                      variant: AppTextVariant.headline,
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 10),
                    AppText(
                      'Share your location to meet travelers nearby. You can change this anytime.',
                      variant: AppTextVariant.body,
                      textAlign: TextAlign.center,
                      color: muted,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AppText(
                          _error!,
                          variant: AppTextVariant.bodySmall,
                          textAlign: TextAlign.center,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          AppButton(
            label: _needsSettings ? 'Open Settings' : 'Share location',
            isLoading: _loading,
            onPressed: _needsSettings
                ? _openSettingsForCurrentBlocker
                : _onShare,
          ),
          if (_needsSettings) ...[
            const SizedBox(height: 10),
            AppButton(
              label: 'Update location',
              variant: AppButtonVariant.text,
              isExpanded: false,
              onPressed: _loading ? null : _onUpdateLocation,
            ),
          ],
          if (widget.onSkip != null) ...[
            const SizedBox(height: 6),
            AppButton(
              label: 'Not now',
              variant: AppButtonVariant.text,
              isExpanded: false,
              onPressed: _loading ? null : widget.onSkip,
            ),
          ],
        ],
      ),
    );
  }
}
