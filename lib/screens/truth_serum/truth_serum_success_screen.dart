import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Success notice after Truth Serum purchase (RN `truthserum/purchase-success`).
class TruthSerumSuccessScreen extends StatelessWidget {
  const TruthSerumSuccessScreen({super.key});

  void _continue(BuildContext context) {
    HapticsService.selection();
    AnalyticsService.instance.logEvent('paid_truth_serum');
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final primary = AppColors.textPrimaryOf(context);
    final secondary = AppColors.textSecondaryOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: bg,
      body: AppSafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Image.asset(
                      'assets/profile/potion.png',
                      width: 112,
                      height: 112,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 30),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        children: [
                          AppText(
                            'You drank the truth serum!',
                            variant: AppTextVariant.display,
                            textAlign: TextAlign.center,
                            color: primary,
                          ),
                          const SizedBox(height: 20),
                          AppText(
                            'You now know your aura',
                            variant: AppTextVariant.body,
                            textAlign: TextAlign.center,
                            color: secondary,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + bottom),
              child: AppButton(
                label: 'Continue',
                onPressed: () => _continue(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
