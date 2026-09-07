import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/screens/messages/reveal_screen.dart';
import 'package:fairytrail/screens/shell/floating_bottom_nav.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/screens/upgrade/upgrade_screen.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Soft upsell after free users tap Reveal (RN `premiumFeatureNotice`).
class RevealPremiumNoticeScreen extends StatelessWidget {
  const RevealPremiumNoticeScreen({super.key, required this.onKeepMatching});

  final VoidCallback onKeepMatching;

  static Future<void> open(
    BuildContext context, {
    required VoidCallback onKeepMatching,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            RevealPremiumNoticeScreen(onKeepMatching: onKeepMatching),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/reveal/hidden3.png',
                      width: 220,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 28),
                    const AppText(
                      'Reveal them now',
                      variant: AppTextVariant.title,
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      'Or send connects to match for free',
                      variant: AppTextVariant.body,
                      textAlign: TextAlign.center,
                      color: muted,
                      fontSize: 16,
                    ),
                  ],
                ),
              ),
              AppButton(
                label: 'See who wants to connect',
                onPressed: () {
                  HapticsService.selection();
                  Navigator.of(context).pop();
                  UpgradeScreen.open(
                    context,
                    reason: 'premium_feature',
                    from: 'messages',
                  );
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Keep matching for free',
                variant: AppButtonVariant.text,
                onPressed: () {
                  HapticsService.selection();
                  Navigator.of(context).pop();
                  onKeepMatching();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paid → [RevealScreen] list. Free → notice a few times, then upgrade paywall.
Future<void> openRevealFlow(BuildContext context) async {
  final isPaid = AuthScope.of(context).isPaid;
  if (isPaid) {
    await RevealScreen.open(context);
    return;
  }

  final count = await LocalStorage.instance.getRevealCount();
  if (!context.mounted) return;
  if (count < 9999) {
    await LocalStorage.instance.incrementRevealCount();
    if (!context.mounted) return;
    final chrome = ShellChromeScope.maybeOf(context);
    await RevealPremiumNoticeScreen.open(
      context,
      onKeepMatching: () => chrome?.selectTab(AppTab.explore),
    );
  } else {
    await UpgradeScreen.open(
      context,
      reason: 'incoming_connects',
      from: 'messages',
    );
  }
}
