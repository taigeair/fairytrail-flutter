import 'dart:async';

import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/billing/billing_plans.dart';
import 'package:fairytrail/screens/upgrade/upgrade_delayed_screen.dart';
import 'package:fairytrail/screens/upgrade/upgrade_success_screen.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

const _loadingMessages = [
  'Verifying payment',
  'Upgrading your tier',
  'Increasing limits',
  'Verifying your new profile',
];

class UpgradeProcessingScreen extends StatefulWidget {
  const UpgradeProcessingScreen({super.key, this.from = 'explore'});

  final String from;

  @override
  State<UpgradeProcessingScreen> createState() =>
      _UpgradeProcessingScreenState();
}

class _UpgradeProcessingScreenState extends State<UpgradeProcessingScreen> {
  int _msgIdx = 0;
  String _dots = '.';
  Timer? _msgTimer;
  Timer? _dotsTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _msgTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() => _msgIdx = (_msgIdx + 1) % _loadingMessages.length);
    });
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {
        _dots = _dots.length >= 4 ? '.' : '$_dots.';
      });
    });
    _pollTimer = Timer(const Duration(milliseconds: 2500), _checkTier);
  }

  Future<void> _checkTier() async {
    final auth = AuthScope.of(context);
    try {
      await auth.refreshMe();
      if (!mounted) return;
      final paid = isPaidTier(auth.profileMeta?.tier ?? 'gated');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => paid
              ? UpgradeSuccessScreen(from: widget.from)
              : UpgradeDelayedScreen(from: widget.from),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await AppDialog.show(
        context,
        title: 'Error',
        message:
            'Unable to verify your subscription, please check your internet connection',
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    _dotsTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showAppBar: false,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppText(
                'Processing your subscription',
                variant: AppTextVariant.display,
                textAlign: TextAlign.center,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 12),
              AppText(
                _loadingMessages[_msgIdx],
                variant: AppTextVariant.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              AppText(
                _dots,
                variant: AppTextVariant.title,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
