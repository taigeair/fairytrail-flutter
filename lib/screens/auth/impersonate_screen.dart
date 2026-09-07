import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Admin impersonation confirm screen (RN `/dl/impersonate/[apiToken]`).
class ImpersonateScreen extends StatefulWidget {
  const ImpersonateScreen({super.key});

  @override
  State<ImpersonateScreen> createState() => _ImpersonateScreenState();
}

class _ImpersonateScreenState extends State<ImpersonateScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryImpersonate());
  }

  Future<void> _tryImpersonate() async {
    final auth = AuthScope.of(context);
    if (auth.pendingImpersonateToken == null) {
      setState(() {
        _loading = false;
        _error = 'Missing impersonation token';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await auth.executeImpersonation();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = serverErrorText(e);
      });
    }
  }

  void _onContinue() {
    AuthScope.of(context).confirmImpersonation();
  }

  Future<void> _onGoToLogin() async {
    await AuthScope.of(context).cancelImpersonation();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.user;
    final theme = Theme.of(context);
    final ready = !_loading && _error == null && user != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                auth.pendingImpersonateToken ?? '',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                )
              else if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Retry',
                  onPressed: _tryImpersonate,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Go to login',
                  variant: AppButtonVariant.secondary,
                  onPressed: _onGoToLogin,
                ),
              ] else ...[
                Text(
                  user?.name ?? '',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  user?.email ?? '',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (_error == null) ...[
                const SizedBox(height: 20),
                AppButton(
                  label: 'Continue',
                  onPressed: ready ? _onContinue : null,
                  isLoading: _loading,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
