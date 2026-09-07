import 'package:fairytrail/api/account.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/screens/profile/account_pause_confirm_screen.dart';
import 'package:fairytrail/screens/profile/delete_account_screen.dart';
import 'package:fairytrail/screens/profile/silver_free_trial_screen.dart';
import 'package:fairytrail/screens/profile/unpause_success_screen.dart';
import 'package:fairytrail/screens/profile/web_login_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));
  }

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _unpausing = false;
  bool _loggingOut = false;

  bool get _isPaused => AuthScope.of(context).user?.accountStatus == 'paused';

  Future<void> _unpause() async {
    if (_unpausing) return;
    setState(() => _unpausing = true);
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
      if (mounted) setState(() => _unpausing = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Heads up!',
      message:
          'Be sure you know your email and sign-in method before logging out',
      confirmLabel: 'Log out',
    );
    if (!confirmed || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await AuthScope.of(context).logout();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondaryOf(context);

    return AppScaffold(
      title: 'Account',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          if (_isPaused) ...[
            AppCard(
              child: Row(
                children: [
                  Icon(Icons.pause_circle_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppText(
                      'Your profile is paused and hidden from Search.',
                      variant: AppTextVariant.bodySmall,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          AppCard(
            onTap: _isPaused
                ? (_unpausing ? null : _unpause)
                : () => AccountPauseConfirmScreen.open(context),
            child: Row(
              children: [
                Icon(
                  _isPaused
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppText(
                    _unpausing
                        ? 'Unpausing…'
                        : (_isPaused ? 'Unpause profile' : 'Pause profile'),
                    variant: AppTextVariant.title,
                  ),
                ),
                if (_unpausing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => WebLoginScreen.open(context),
            child: const Row(
              children: [
                Icon(Icons.computer_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: AppText(
                    'Login on desktop',
                    variant: AppTextVariant.title,
                  ),
                ),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // AppCard(
          //   onTap: () => SilverFreeTrialScreen.open(context),
          //   child: const Row(
          //     children: [
          //       Icon(Icons.card_giftcard_outlined),
          //       SizedBox(width: 12),
          //       Expanded(
          //         child: AppText(
          //           'Silver free trial',
          //           variant: AppTextVariant.title,
          //         ),
          //       ),
          //       Icon(Icons.chevron_right),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 12),
          AppCard(
            onTap: () => DeleteAccountScreen.open(context),
            child: const Row(
              children: [
                Icon(Icons.delete_outline, color: Color(0xFFD32F2F)),
                SizedBox(width: 12),
                Expanded(
                  child: AppText(
                    'Delete account',
                    variant: AppTextVariant.title,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Log out',
            variant: AppButtonVariant.secondary,
            isLoading: _loggingOut,
            onPressed: _loggingOut ? null : _logout,
          ),
        ],
      ),
    );
  }
}
