import 'dart:async';

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/screens/truth_serum/truth_serum_success_screen.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

const _loadingMessages = [
  'Verifying payment',
  'Verifying your profile',
  'Revealing your profile score',
];

/// Post-purchase processing (RN `truthserum-purchase-processing`).
class TruthSerumProcessingScreen extends StatefulWidget {
  const TruthSerumProcessingScreen({super.key});

  @override
  State<TruthSerumProcessingScreen> createState() =>
      _TruthSerumProcessingScreenState();
}

class _TruthSerumProcessingScreenState
    extends State<TruthSerumProcessingScreen> {
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
    _pollTimer = Timer(const Duration(milliseconds: 2500), _finish);
  }

  Future<void> _finish() async {
    try {
      final auth = AuthScope.of(context);
      await auth.refreshMe();
      if (!mounted) return;

      final user = auth.user;
      unawaited(
        AnalyticsService.instance.logEvent('purchased_truthserum', {
          'user_id': user?.id ?? '',
          'user_email': user?.email ?? '',
          'shortId': user?.shortId ?? '',
        }),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const TruthSerumSuccessScreen(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await AppDialog.show(
        context,
        title: 'Error',
        message:
            'Unable to verify your payment for the truth serum, please check your internet connection',
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
                'Processing your payment',
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
