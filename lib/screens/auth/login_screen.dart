import 'dart:async';

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/api/password_reset.dart';
import 'package:fairytrail/auth/account_restored.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/login/login_form.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _prefillEmail();
  }

  Future<void> _prefillEmail() async {
    final email = await LocalStorage.instance.getEmail();
    if (!mounted || email == null) return;
    _emailController.text = email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      AppToast.show(context, message: 'Please enter your email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthScope.of(
        context,
      ).loginWithEmail(email: email, password: password);
      unawaited(
        AnalyticsService.instance.logEvent('logged_in', {
          'userId': result.profileMeta.id,
        }),
      );
      // AuthScope notifies → MainShell shows account-restored alert if needed.
    } catch (e) {
      if (!mounted) return;
      final message = loginErrorText(e);
      AppToast.show(context, message: message);
      debugPrint(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppToast.show(context, message: 'Please enter your email first');
      return;
    }
    if (_isResetting || _isLoading) return;

    setState(() => _isResetting = true);
    try {
      await requestPasswordReset(email: email);
      if (!mounted) return;
      await AppDialog.show(
        context,
        title: 'Check your email',
        message: 'Please check your email for password reset instructions',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _isLoading || _isResetting;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Login'),
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
                        child: LoginForm(
                          emailController: _emailController,
                          passwordController: _passwordController,
                          isLoading: busy,
                          onSubmit: _onLogin,
                          onForgotPassword: _onForgotPassword,
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
