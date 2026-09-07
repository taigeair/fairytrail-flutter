import 'dart:async';

import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/screens/verification/verified_screen.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

const _loadingMessages = [
  'Processing payment',
  'Verifying your profile',
  'Increasing limits',
  'Upgrading your tier',
];

class VerificationProcessingScreen extends StatefulWidget {
  const VerificationProcessingScreen({super.key});

  @override
  State<VerificationProcessingScreen> createState() =>
      _VerificationProcessingScreenState();
}

class _VerificationProcessingScreenState
    extends State<VerificationProcessingScreen> {
  int _msgIdx = 0;
  String _dots = '..';
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
    _pollTimer = Timer(const Duration(milliseconds: 2500), _finish);
  }

  Future<void> _finish() async {
    try {
      await AuthScope.of(context).refreshMe();
      if (!mounted) return;
      final tier = AuthScope.of(context).profileMeta?.tier;
      unawaited(track('verification_success', {'tier': tier ?? ''}));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const VerifiedScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      await AppDialog.show(
        context,
        title: 'Error',
        message: 'Failed to verify your payment',
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
                'Processing your verification',
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
