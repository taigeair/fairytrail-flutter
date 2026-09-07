import 'package:fairytrail/auth/account_restored.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Set a new password after opening the email reset link (RN parity).
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    return password.length >= 6 && password == confirm && !_isLoading;
  }

  Future<void> _onSubmit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 6) {
      AppToast.show(context, message: 'Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      AppToast.show(context, message: 'Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthScope.of(
        context,
      ).resetPasswordWithToken(token: widget.token, password: password);
      // AuthScope notifies → MainShell shows account-restored alert if needed.
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: loginErrorText(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reset password'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppSafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth - 56,
                  minHeight: constraints.maxHeight - 36,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const AppText(
                              'Set New Password',
                              variant: AppTextVariant.headline,
                              textAlign: TextAlign.center,
                              fontWeight: FontWeight.w700,
                            ),
                            const SizedBox(height: 8),
                            AppText(
                              'Choose a new password for your account',
                              variant: AppTextVariant.bodySmall,
                              textAlign: TextAlign.center,
                              color: muted,
                            ),
                            const SizedBox(height: 28),
                            AppTextField(
                              controller: _passwordController,
                              hint: 'New Password',
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: _confirmController,
                              hint: 'Confirm New Password',
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) {
                                if (_canSubmit) _onSubmit();
                              },
                            ),
                            const SizedBox(height: 28),
                            AppButton(
                              label: 'Continue',
                              isLoading: _isLoading,
                              onPressed: _canSubmit ? _onSubmit : null,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
