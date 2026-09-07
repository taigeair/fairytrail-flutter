import 'dart:async';
import 'dart:io' show Platform;

import 'package:fairytrail/config/app_version.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Force-update gate when remote `acceptableBuild` is above this app's build.
class AppOutdatedScreen extends StatefulWidget {
  const AppOutdatedScreen({super.key, this.acceptableBuild, this.onRecheck});

  /// Remote config value that triggered this screen (for Mixpanel).
  final String? acceptableBuild;

  /// Optional re-check after returning from the store.
  final VoidCallback? onRecheck;

  static const appStoreUrl =
      'https://apps.apple.com/app/apple-store/id1442011999';
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=app.fairytrail.release';

  @override
  State<AppOutdatedScreen> createState() => _AppOutdatedScreenState();
}

class _AppOutdatedScreenState extends State<AppOutdatedScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      track('view_app_outdated_screen', {
        'acceptableBuild': widget.acceptableBuild,
        'currentBuild': AppVersionInfo.build,
      }),
    );
  }

  Future<void> _openStore() async {
    final storeUrl = !kIsWeb && Platform.isIOS
        ? AppOutdatedScreen.appStoreUrl
        : AppOutdatedScreen.playStoreUrl;
    unawaited(track('click_update_app', {'storeUrl': storeUrl}));
    await launchUrl(
      Uri.parse(storeUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              const Align(
                alignment: Alignment.centerLeft,
                child: AppText(
                  'App Outdated',
                  variant: AppTextVariant.title,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: AppText(
                  'Please update your app to continue.',
                  variant: AppTextVariant.body,
                  fontSize: 22,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 28),
              Image.asset(
                'assets/explore/trees.png',
                width: 260,
                height: 260,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              AppButton(
                label: 'Update',
                onPressed: () async {
                  await _openStore();
                  widget.onRecheck?.call();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft block while remote `isMaintenence` is true.
class AppMaintenanceScreen extends StatelessWidget {
  const AppMaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              const Align(
                alignment: Alignment.centerLeft,
                child: AppText(
                  "We're updating the app right now.",
                  variant: AppTextVariant.title,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: AppText(
                  'Please come back soon!',
                  variant: AppTextVariant.body,
                  fontSize: 22,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 28),
              Image.asset(
                'assets/explore/trees.png',
                width: 260,
                height: 260,
                fit: BoxFit.contain,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
