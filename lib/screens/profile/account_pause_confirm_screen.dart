import 'package:fairytrail/api/account.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AccountPauseConfirmScreen extends StatefulWidget {
  const AccountPauseConfirmScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AccountPauseConfirmScreen(),
      ),
    );
  }

  @override
  State<AccountPauseConfirmScreen> createState() =>
      _AccountPauseConfirmScreenState();
}

class _AccountPauseConfirmScreenState extends State<AccountPauseConfirmScreen> {
  bool _loading = false;

  Future<void> _pause() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await postAccountStatus('paused');
      if (!mounted) return;
      await AuthScope.of(context).refreshMe();
      if (!mounted) return;
      AppToast.show(context, message: 'Your profile has been paused.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondaryOf(context);

    return AppScaffold(
      title: 'Pause profile',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(
              'Pausing hides your profile from Explore and group chats. You can still chat with existing connections. If you sent connect requests, they can still be accepted.',
              variant: AppTextVariant.body,
              color: muted,
            ),
            const Spacer(),
            AppButton(
              label: 'Pause profile',
              isLoading: _loading,
              onPressed: _pause,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.text,
              // From Delete Account → Pause, a single pop lands back on
              // Delete. Always return to the profile tab (shell root).
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}
