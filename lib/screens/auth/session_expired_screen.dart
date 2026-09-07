import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Shown when `GET /me` returns 401 with a stored token.
class SessionExpiredScreen extends StatefulWidget {
  const SessionExpiredScreen({super.key});

  @override
  State<SessionExpiredScreen> createState() => _SessionExpiredScreenState();
}

class _SessionExpiredScreenState extends State<SessionExpiredScreen> {
  bool _retrying = false;
  bool _loggingOut = false;
  String? _error;

  Future<void> _retry() async {
    if (_retrying || _loggingOut) return;
    setState(() {
      _retrying = true;
      _error = null;
    });
    try {
      await AuthScope.of(context).retrySession();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = serverErrorText(e));
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _logout() async {
    if (_retrying || _loggingOut) return;
    setState(() {
      _loggingOut = true;
      _error = null;
    });
    try {
      await AuthScope.of(context).logout();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = serverErrorText(e));
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final busy = _retrying || _loggingOut;

    return AppScaffold(
      showAppBar: false,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: muted,
              ),
              const SizedBox(height: 16),
              const AppText(
                'Session expired',
                variant: AppTextVariant.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              AppText(
                'Your login is no longer valid. Retry, or log out and sign in again.',
                variant: AppTextVariant.caption,
                textAlign: TextAlign.center,
                color: muted,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppText(
                  _error!,
                  variant: AppTextVariant.bodySmall,
                  textAlign: TextAlign.center,
                  color: Theme.of(context).colorScheme.error,
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: 'Retry',
                isLoading: _retrying,
                onPressed: busy ? null : _retry,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Log out',
                variant: AppButtonVariant.secondary,
                isLoading: _loggingOut,
                onPressed: busy ? null : _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
