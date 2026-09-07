import 'dart:async';

import 'package:fairytrail/screens/upgrade/upgrade_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdGate extends StatefulWidget {
  const RewardedAdGate({super.key, required this.ad, required this.onClose});

  final RewardedAd ad;
  final VoidCallback onClose;

  @override
  State<RewardedAdGate> createState() => _RewardedAdGateState();
}

class _RewardedAdGateState extends State<RewardedAdGate> {
  late RewardedAd? _ad;

  @override
  void initState() {
    super.initState();
    _ad = widget.ad;
  }

  Future<void> _watch() async {
    final ad = _ad;
    if (ad == null) return;
    setState(() => _ad = null);
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (closedAd) {
        closedAd.dispose();
        widget.onClose();
      },
      onAdFailedToShowFullScreenContent: (failedAd, _) {
        failedAd.dispose();
        widget.onClose();
      },
    );
    await ad.show(
      onUserEarnedReward: (_, _) {
        unawaited(LocalStorage.instance.setRewardTaken());
      },
    );
  }

  void _removeAds() {
    unawaited(
      UpgradeScreen.open(
        context,
        reason: 'ads_remove',
        from: 'ads',
      ),
    );
    widget.onClose();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 68,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 28),
              const AppText(
                'Watch an ad to continue exploring or wait until tomorrow',
                variant: AppTextVariant.title,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: 'Watch ad',
                onPressed: _ad == null ? null : _watch,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Remove ads',
                variant: AppButtonVariant.secondary,
                onPressed: _removeAds,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
