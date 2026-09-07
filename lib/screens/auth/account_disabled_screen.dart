import 'dart:async';

import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:fairytrail/widgets/widgets.dart';

/// RN `/account-disabled` — shown when admin sets profile status to disabled.
///
/// Logs the user out on mount (session is no longer usable).
class AccountDisabledScreen extends StatefulWidget {
  const AccountDisabledScreen({super.key});

  @override
  State<AccountDisabledScreen> createState() => _AccountDisabledScreenState();
}

class _AccountDisabledScreenState extends State<AccountDisabledScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // RN: logoutUser + authService.resetAuth on mount.
      final auth = AuthScope.of(context);
      unawaited(auth.clearSessionForDisabledAccount());
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondaryOf(context);
    return Scaffold(
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const AppText(
                'Your account has been disabled.',
                variant: AppTextVariant.headline,
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
              const SizedBox(height: 16),
              AppText(
                'If you believe this is a mistake, please contact us.',
                variant: AppTextVariant.body,
                fontSize: 22,
                color: muted,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
