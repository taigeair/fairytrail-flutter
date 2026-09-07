import 'dart:async';

import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class UpgradeSuccessScreen extends StatefulWidget {
  const UpgradeSuccessScreen({super.key, this.from = 'explore'});

  final String from;

  @override
  State<UpgradeSuccessScreen> createState() => _UpgradeSuccessScreenState();
}

class _UpgradeSuccessScreenState extends State<UpgradeSuccessScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      track('view_upgrade_success_screen', {'source': widget.from}),
    );
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
              "Sun's out, trails out!",
              variant: AppTextVariant.display,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.bold,
            ),
            const Spacer(),
            AppButton(
              label: 'Continue',
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }
}
