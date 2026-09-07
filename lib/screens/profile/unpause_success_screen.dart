import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class UnpauseSuccessScreen extends StatelessWidget {
  const UnpauseSuccessScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const UnpauseSuccessScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.check_circle_outline,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const AppText(
                'Congrats!',
                variant: AppTextVariant.headline,
                fontWeight: FontWeight.w700,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              AppText(
                'Your profile is now discoverable.',
                variant: AppTextVariant.body,
                textAlign: TextAlign.center,
                color: AppColors.textSecondaryOf(context),
              ),
              const Spacer(),
              AppButton(
                label: 'Awesome',
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
