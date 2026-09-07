import 'dart:async';

import 'package:fairytrail/screens/upgrade/upgrade_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdScreen extends StatefulWidget {
  const BannerAdScreen({super.key, required this.ad});

  final BannerAd ad;

  static Future<void> open(BuildContext context, {required BannerAd ad}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => BannerAdScreen(ad: ad),
        ),
      );

  @override
  State<BannerAdScreen> createState() => _BannerAdScreenState();
}

class _BannerAdScreenState extends State<BannerAdScreen> {
  Timer? _countdownTimer;
  int _countdown = 5;
  bool _adReady = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    unawaited(_prepareAd());
  }

  /// [AdWidget] throws if [BannerAd.load] never registered a native ad id
  /// (unloaded or already disposed).
  Future<void> _prepareAd() async {
    try {
      await widget.ad.load();
      if (mounted) setState(() => _adReady = true);
    } catch (_) {}
  }

  Future<void> _startCountdown() async {
    if (await LocalStorage.instance.getSkipAdsCountdownFinished()) {
      if (mounted) setState(() => _countdown = 0);
    } else {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _countdown <= 0) return;
        setState(() => _countdown--);
        if (_countdown == 0) {
          _countdownTimer?.cancel();
          unawaited(LocalStorage.instance.setSkipAdsCountdownFinished());
        }
      });
    }
  }

  Future<void> _skip() async {
    await LocalStorage.instance.deleteBannerAdsScreenViewed();
    await LocalStorage.instance.deleteSkipAdsCountdownFinished();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _removeAds() async {
    await LocalStorage.instance.deleteBannerAdsScreenViewed();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => const UpgradeScreen(reason: 'ads_remove', from: 'ads'),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    widget.ad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              const Spacer(),
              AppText(
                'Your free plan is supported by the following ad',
                variant: AppTextVariant.headline,
                fontWeight: FontWeight.w700,
                fontSize: 25,
                textAlign: TextAlign.center,
                color: AppColors.isDark(context)
                    ? AppColors.darkTextSecondary
                    : AppColors.textPrimaryOf(context),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 300,
                height: 250,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _adReady
                        ? AdWidget(ad: widget.ad)
                        : const SizedBox.expand(),
                  ),
                ),
              ),
              const Spacer(),
              AppButton(
                label: _countdown > 0 ? 'Skip ad ($_countdown)' : 'Skip ad',
                onPressed: _countdown > 0 ? null : _skip,
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
