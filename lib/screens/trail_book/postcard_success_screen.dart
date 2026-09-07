import 'package:confetti/confetti.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class PostcardSuccessScreen extends StatefulWidget {
  const PostcardSuccessScreen({super.key, this.path = 'explore'});

  final String path;

  @override
  State<PostcardSuccessScreen> createState() => _PostcardSuccessScreenState();
}

class _PostcardSuccessScreenState extends State<PostcardSuccessScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _continue() {
    HapticsService.selection();
    if (widget.path == 'viewProfile') {
      // Pop back past select + send.
      var count = 0;
      Navigator.of(context).popUntil((route) {
        count++;
        return count > 2 || route.isFirst;
      });
      return;
    }
    if (widget.path == 'chat' || widget.path == 'messages') {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          AppSafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Image.asset(
                    'assets/trailBook/postcard.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 28),
                  const AppText(
                    'Your postcard is on its way!',
                    variant: AppTextVariant.headline,
                    fontWeight: FontWeight.w800,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  AppText(
                    'Your kindness increased by one.',
                    variant: AppTextVariant.body,
                    fontSize: 17,
                    textAlign: TextAlign.center,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  const Spacer(flex: 3),
                  AppButton(label: 'Continue', onPressed: _continue),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 28,
              maxBlastForce: 20,
              minBlastForce: 8,
              emissionFrequency: 0.05,
            ),
          ),
        ],
      ),
    );
  }
}
