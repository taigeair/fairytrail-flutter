import 'dart:async';

import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class UpgradeDelayedScreen extends StatefulWidget {
  const UpgradeDelayedScreen({super.key, this.from = 'explore'});

  final String from;

  @override
  State<UpgradeDelayedScreen> createState() => _UpgradeDelayedScreenState();
}

class _UpgradeDelayedScreenState extends State<UpgradeDelayedScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(track('view_upgrade_delayed_screen', {'source': widget.from}));
  }

  Future<void> _continue() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthScope.of(context).refreshMe();
    } catch (_) {
      // Still leave the flow.
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showAppBar: false,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const Spacer(),
            const AppText(
              'Subscription successful!',
              variant: AppTextVariant.display,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 16),
            const AppText(
              "But we're still waiting for payment confirmation, you'll get all benefits shortly.",
              variant: AppTextVariant.title,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            AppButton(
              label: 'Continue',
              isLoading: _loading,
              onPressed: _continue,
            ),
          ],
        ),
      ),
    );
  }
}
