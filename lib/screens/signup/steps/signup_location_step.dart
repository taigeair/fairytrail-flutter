import 'dart:async';

import 'package:fairytrail/location/location_service.dart';
import 'package:fairytrail/screens/signup/signup_step_scaffold.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Step 9 — location permission (required, with privacy details).
class SignupLocationStep extends StatefulWidget {
  const SignupLocationStep({
    super.key,
    required this.onContinue,
    this.isLoading = false,
  });

  /// Called after location is shared successfully. Awaited so Continue stays
  /// loading while the parent finishes (mark location, remote config, nav).
  final Future<void> Function() onContinue;
  final bool isLoading;

  @override
  State<SignupLocationStep> createState() => _SignupLocationStepState();
}

class _SignupLocationStepState extends State<SignupLocationStep>
    with WidgetsBindingObserver {
  bool _loading = false;
  bool _needsSettings = false;
  String? _error;
  bool _returningFromSettings = false;

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
    if (state == AppLifecycleState.resumed && _returningFromSettings) {
      _returningFromSettings = false;
      _needsSettings = false;
      unawaited(_onShare());
    }
  }

  Future<void> _onShare() async {
    if (_loading || widget.isLoading) return;

    if (_needsSettings) {
      _returningFromSettings = true;
      final opened = await LocationService.openAppSettings();
      if (!opened) _returningFromSettings = false;
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final outcome = await LocationService.shareCurrentLocation();
    if (!mounted) return;

    if (outcome.isSuccess) {
      try {
        await widget.onContinue();
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    final needsSettings =
        outcome.result == LocationShareResult.permissionPermanentlyDenied ||
        outcome.result == LocationShareResult.serviceDisabled ||
        outcome.result == LocationShareResult.permissionDenied;

    setState(() {
      _loading = false;
      _needsSettings = needsSettings;
      _error = outcome.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.58);

    return SignupStepScaffold(
      step: 9,
      title: 'Location',
      continueLabel: _needsSettings ? 'Open Settings' : 'Continue',
      canContinue: true,
      isLoading: _loading || widget.isLoading,
      onContinue: _onShare,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: AppColors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            const AppText(
              'Connect with nearby travelers',
              variant: AppTextVariant.headline,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
            const SizedBox(height: 10),
            AppText(
              'Enable location to discover people and activities based on location',
              variant: AppTextVariant.body,
              textAlign: TextAlign.center,
              color: muted,
            ),
            const SizedBox(height: 32),
            const _FeatureRow(
              icon: Icons.place_outlined,
              title: 'Explore who\'s nearby',
              body: 'Find people and meetups based on location',
            ),
            const SizedBox(height: 22),
            const _FeatureRow(
              icon: Icons.people_outline_rounded,
              title: 'Receive connect requests',
              body: 'People can find you and send connect requests',
            ),
            const SizedBox(height: 22),
            const _FeatureRow(
              icon: Icons.verified_user_outlined,
              title: 'Privacy is our priority',
              body: 'Your location is never shown to other travelers',
            ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
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
            const SizedBox(height: 24),
            AppText(
              'You can revoke access anytime in Settings.',
              variant: AppTextVariant.caption,
              textAlign: TextAlign.center,
              color: muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                variant: AppTextVariant.label,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 4),
              AppText(body, variant: AppTextVariant.caption, color: muted),
            ],
          ),
        ),
      ],
    );
  }
}
