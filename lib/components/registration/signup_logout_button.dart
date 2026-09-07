import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/app_dialog.dart';
import 'package:flutter/material.dart';

/// Red logout icon for signup flow app bars.
class SignupLogoutButton extends StatelessWidget {
  const SignupLogoutButton({super.key, this.enabled = true});

  final bool enabled;

  static Future<void> handleLogout(BuildContext context) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Log out?',
      message: 'You can continue signup later with the same email',
      confirmLabel: 'Log out',
    );
    if (!confirmed || !context.mounted) return;

    await AuthScope.of(context).logout();
    if (!context.mounted) return;

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? () => handleLogout(context) : null,
      icon: const Icon(Icons.logout_rounded),
      color: AppColors.primary,
      tooltip: 'Log out',
    );
  }
}
