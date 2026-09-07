import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_button.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:fairytrail/widgets/widgets.dart';

/// RN `/login/delete-goodbye` — shown after scheduling account deletion.
///
/// Explains the 30-day grace period. Signing in again with the same email
/// cancels deletion (server restores `accountStatus` to `active`).
class DeleteGoodbyeScreen extends StatelessWidget {
  const DeleteGoodbyeScreen({super.key, required this.onUnderstood});

  final VoidCallback onUnderstood;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textPrimaryOf(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 24, 40, 24),
          child: Column(
            children: [
              const Spacer(),
              const AppText(
                'Goodbye!',
                variant: AppTextVariant.headline,
                fontWeight: FontWeight.w700,
                fontSize: 28,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AppText(
                'After 30 days of your account deletion request, your account '
                'and all your information will be permanently deleted, and you '
                "won't be able to retrieve your information. During those 30 days "
                "the content remains subject to Fairytrail's Terms and is not "
                'fully accessible to other people using Fairytrail. Sign up or '
                'log in with the same email on Fairytrail to stop the deletion '
                'process.',
                variant: AppTextVariant.body,
                fontSize: 17,
                textAlign: TextAlign.center,
                color: muted,
              ),
              const Spacer(),
              AppButton(label: 'Understood', onPressed: onUnderstood),
            ],
          ),
        ),
      ),
    );
  }
}
