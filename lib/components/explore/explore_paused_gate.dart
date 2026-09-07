import 'package:fairytrail/api/account.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/screens/profile/unpause_success_screen.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Blocks Explore while the current user's account is paused.
///
/// Existing conversations remain accessible from the Messages tab.
class ExplorePausedGate extends StatefulWidget {
  const ExplorePausedGate({super.key});

  @override
  State<ExplorePausedGate> createState() => _ExplorePausedGateState();
}

class _ExplorePausedGateState extends State<ExplorePausedGate> {
  bool _isLoading = false;

  Future<void> _unpause() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await postAccountStatus('active');
      if (!mounted) return;
      await AuthScope.of(context).refreshMe();
      if (!mounted) return;
      await UnpauseSuccessScreen.open(context);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavHeight =
        ShellChromeScope.maybeOf(context)?.bottomNavHeightOr(72) ?? 72;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: AppSafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 24, 28, bottomNavHeight + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const AppText(
                'Paused',
                variant: AppTextVariant.headline,
                fontWeight: FontWeight.w700,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AppText(
                'Your profile is hidden from Explore and group chats but '
                'you can still chat with existing connections',
                variant: AppTextVariant.body,
                color: AppColors.textSecondaryOf(context),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: 'Unpause to explore',
                isLoading: _isLoading,
                onPressed: _unpause,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
