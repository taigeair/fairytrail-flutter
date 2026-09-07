import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class VerifiedScreen extends StatelessWidget {
  const VerifiedScreen({super.key});

  Future<void> _continue(BuildContext context) async {
    try {
      await AuthScope.of(context).refreshMe();
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryOf(context);

    return AppScaffold(
      showAppBar: false,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const AppText(
              'Verified',
              variant: AppTextVariant.display,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.w800,
            ),
            const SizedBox(height: 10),
            AppText(
              'Thank you for making our world safer!',
              variant: AppTextVariant.body,
              textAlign: TextAlign.center,
              color: textSecondary,
            ),
            const Spacer(),
            AppButton(
              label: 'Continue',
              onPressed: () => _continue(context),
            ),
          ],
        ),
      ),
    );
  }
}
